#!/bin/bash
set -euo pipefail

IDENTITY_NAME=velero
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_ROLE=Contributor
AZURE_STORAGE_ACCOUNT_ID=samcherfivelero
AZURE_RESOURCE_GROUP=mcherfiRG
CLUSTER_NAME=malik-aks-cluster-fr
BLOB_CONTAINER=velero

IDENTITY_CLIENT_ID="$(az identity show -g $AZURE_RESOURCE_GROUP -n $IDENTITY_NAME --subscription $AZURE_SUBSCRIPTION_ID --query clientId -otsv)"

if [ -z "$IDENTITY_CLIENT_ID" ]; then
    echo "Creating Azure Managed Identity: $IDENTITY_NAME"

az identity create \
    --subscription $AZURE_SUBSCRIPTION_ID \
    --resource-group $AZURE_RESOURCE_GROUP \
    --name $IDENTITY_NAME

IDENTITY_CLIENT_ID="$(az identity show -g $AZURE_RESOURCE_GROUP -n $IDENTITY_NAME --subscription $AZURE_SUBSCRIPTION_ID --query clientId -otsv)"

az role assignment create --role $AZURE_ROLE --assignee $IDENTITY_CLIENT_ID --scope /subscriptions/$AZURE_SUBSCRIPTION_ID

az role assignment create --assignee $IDENTITY_CLIENT_ID --role "Storage Blob Data Contributor" --scope /subscriptions/$AZURE_SUBSCRIPTION_ID
fi

# create namespace
kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

# create service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $IDENTITY_CLIENT_ID
  name: velero
  namespace: velero
EOF

# create clusterrolebinding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: velero
subjects:
- kind: ServiceAccount
  name: velero
  namespace: velero
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF



SERVICE_ACCOUNT_ISSUER=$(az aks show --resource-group $AZURE_RESOURCE_GROUP --name $CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
  --name "kubernetes-federated-credential" \
  --identity-name "${IDENTITY_NAME}" \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --issuer "${SERVICE_ACCOUNT_ISSUER}" \
  --subject "system:serviceaccount:velero:velero" \
  || true # Ignore l'erreur si elle existe déjà

cat << EOF  > ./credentials-velero
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

velero install \
    --provider azure \
    --service-account-name velero \
    --pod-labels azure.workload.identity/use=true \
    --plugins velero/velero-plugin-for-microsoft-azure:v1.13.0 \
    --bucket $BLOB_CONTAINER \
    --secret-file ./credentials-velero \
    --backup-location-config useAAD="true",resourceGroup=$AZURE_RESOURCE_GROUP,storageAccount=$AZURE_STORAGE_ACCOUNT_ID,subscriptionId=$AZURE_SUBSCRIPTION_ID \
    --snapshot-location-config apiTimeout=2m,resourceGroup=$AZURE_RESOURCE_GROUP,subscriptionId=$AZURE_SUBSCRIPTION_ID \
    --dry-run -o yaml | kubectl apply -f -