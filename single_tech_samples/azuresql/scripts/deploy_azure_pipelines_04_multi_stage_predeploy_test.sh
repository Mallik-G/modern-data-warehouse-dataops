#!/bin/bash

. ./scripts/common.sh


###############
# Deploy Pipelines: multi-stage predeploy

# Deploy AzureSQL
echo "Deploying resources for multi-stage with predeployment test pipeline into $RG_NAME"
sqlsrvr_name=sqlsrvr04$(random_str 5)
arm_output=$(az group deployment create \
    --resource-group "$RG_NAME" \
    --template-file "./infrastructure/azuredeploy.json" \
    --parameters azuresql_srvr_password=${AZURESQL_SRVR_PASSWORD} azuresql_srvr_name=${sqlsrvr_name} azuresql_srvr_display_name="SQL Server - Multi-Stage Pipeline with pre-deployment test" \
    --output json)

# Create pipeline
pipeline_name=azuresql-04-multi-stage-w-predeploy-test
echo "Creating Pipeline: $pipeline_name in Azure DevOps"
pipeline_id=$(az pipelines create \
    --name "$pipeline_name" \
    --description 'This pipelines is a simpe two stage pipeline which builds the DACPAC and deploy to a target AzureSQLDB instance' \
    --repository "$GITHUB_REPO_URL" \
    --branch master \
    --yaml-path 'single_tech_samples/azuresql/pipelines/azure-pipelines-04-multi-stage-predeploy-test.yml' \
    --service-connection "$GITHUB_SERVICE_CONNECTION_ID" \
    --skip-first-run true \
    --output json | jq -r '.id')

# Create Variables
az pipelines variable create \
    --name AZURESQL_SERVER_NAME \
    --pipeline-id $pipeline_id \
    --value "$sqlsrvr_name.database.windows.net"

azuresql_db_name=$(echo $arm_output | jq -r '.properties.outputs.azuresql_db_name.value')
az pipelines variable create \
    --name AZURESQL_DB_NAME \
    --pipeline-id $pipeline_id \
    --value $azuresql_db_name

azuresql_srvr_admin=$(echo $arm_output | jq -r '.properties.outputs.azuresql_srvr_admin.value')
az pipelines variable create \
    --name AZURESQL_SERVER_USERNAME \
    --pipeline-id $pipeline_id \
    --value $azuresql_srvr_admin

az pipelines variable create \
    --name AZURESQL_SERVER_PASSWORD \
    --pipeline-id $pipeline_id \
    --secret true \
    --value $AZURESQL_SRVR_PASSWORD

az pipelines run --name $pipeline_name