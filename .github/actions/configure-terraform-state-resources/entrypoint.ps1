. "${PSScriptRoot}/Initialize-TerraformStateStorage.ps1"

Initialize-TerraformStateStorage `
    -AzureSpnObjectId "${env:AZURE_SPN_OBJECT_ID}" `
    -AzureSubscriptionId "${env:AZURE_SUBSCRIPTION_ID}" `
    -EnvironmentShort "${env:ENVIRONMENT_SHORT}" `
    -EnvironmentInstance "${env:ENVIRONMENT_INSTANCE}" `
    -ResourceGroupName "${env:RESOURCE_GROUP_NAME}" `
    -StorageAccountName "${env:STORAGE_ACCOUNT_NAME}" `
    -GroupRoleAssignments "${env:GROUP_ROLE_ASSIGNMENTS}"