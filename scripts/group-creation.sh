#!/usr/bin/env bash

GROUP_NAME="mcherfi_employes"

MY_USER_ID=$(az ad signed-in-user show --query id --output tsv)

az ad group create \
  --display-name "$GROUP_NAME" \
  --mail-nickname "$GROUP_NAME"

az ad group owner add \
  --group "$GROUP_NAME" \
  --owner-object-id "$MY_USER_ID"

az ad group owner list \
  --group "$GROUP_NAME" \
  --query "[].{Name:displayName, UserPrincipalName:userPrincipalName}" \
  --output table