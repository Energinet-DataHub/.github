<#
.SYNOPSIS
This action ensures that the landing zone contains a resource group, storage account, container for storing Terraform State files.
It also assigns the required permissions to the storage account.
#>

function Initialize-TerraformStateStorage {
    param(
        [Parameter(Mandatory)]
        [string]
        $EnvironmentShort,
        [Parameter(Mandatory)]
        [string]
        $EnvironmentInstance,
        [Parameter(Mandatory)]
        [string]
        $AzureSpnObjectId,
        [Parameter(Mandatory)]
        [string]
        $AzureSubscriptionId
    )
    $location = "westeurope"

    $DomainNameShort = "tfs"
    $TfStateNamingParts = $DomainNameShort, $EnvironmentShort, "we", $EnvironmentInstance
    $ResourceGroupName = (, "rg" + $TfStateNamingParts) -Join "-"
    $StorageAccountName = (, "st" + $TfStateNamingParts) -Join ""

    Initialize-ResourceGroupIsCreated -ResourceGroupName $ResourceGroupName -Location $location

    Initialize-StorageAccountIsCreated -StorageAccountName $storageAccountName -ResourceGroupName $ResourceGroupName -Location $location

    Initialize-ContainerIsCreated -ContainerName $DomainNameShort -StorageAccountName $storageAccountName

    Initialize-StorageAccountRoleContributorIsAssigned -StorageAccountName $storageAccountName `
        -PrincipalObjectId $AzureSpnObjectId `
        -PrincipalType "ServicePrincipal" `
        -Role "Storage Blob Data Contributor" `
        -Scope "/subscriptions/$AzureSubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

    Initialize-StorageAccountRetentionAndVersioning -StorageAccountName $storageAccountName -ResourceGroupName $ResourceGroupName -AzureSubscriptionId $AzureSubscriptionId
}

function Initialize-ResourceGroupIsCreated {
    param(
        [Parameter(Mandatory)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory)]
        [string]
        $Location
    )

    $groupExists = az group exists --name $ResourceGroupName
    if ($groupExists -eq "false") {
        Write-Host "Resource group $ResourceGroupName for storing Terraform state will be created"
        $response = az group create --name "$ResourceGroupName" `
            --location "$Location" `
            --query "properties.provisioningState" | ConvertFrom-Json

        Write-Host "Resource group creation response is: $response"

        if ($response -ne "Succeeded") {
            Write-Error "Failed to create resource group for storing Terraform state"
            exit 1
        }
    }
    else {
        Write-Host "Resource group $ResourceGroupName for storing Terraform state already exists"
    }
}

function Initialize-StorageAccountIsCreated {
    param(
        [Parameter(Mandatory)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory)]
        [string]
        $Location
    )

    $storageAccountNameAvailable = az storage account check-name --name $StorageAccountName --query 'nameAvailable' | ConvertFrom-Json
    if ($storageAccountNameAvailable -eq $true) {
        Write-Host "Storage account $StorageAccountName for storing Terraform state will be created"
        $response = az storage account create --name "$StorageAccountName" `
            --resource-group "$ResourceGroupName" `
            --location "$Location" `
            --min-tls-version "TLS1_2" `
            --sku "Standard_LRS" `
            --allow-shared-key-access false `
            --allow-blob-public-access false `
            --query "provisioningState" | ConvertFrom-Json

        Write-Host "Storage account creation response is: $response"

        if ($response -ne "Succeeded") {
            Write-Error "Failed to create storage account for storing Terraform state"
            exit 1
        }
    }
    else {
        Write-Host "Storage account $StorageAccountName for storing Terraform state already exists"
    }
}

function Initialize-ContainerIsCreated {
    param(
        [Parameter(Mandatory)]
        [string]
        $ContainerName,
        [Parameter(Mandatory)]
        [string]
        $StorageAccountName
    )

    $containerExists = az storage container exists --name "$ContainerName" `
        --account-name "$StorageAccountName" `
        --query "exists" --auth-mode login | ConvertFrom-Json

    if ($containerExists -eq $false) {
        Write-Host "Container $ContainerName for storing Terraform state will be created"
        $response = az storage container create --name "$ContainerName" `
            --account-name "$StorageAccountName" `
            --auth-mode "login" `
            --query "created" | ConvertFrom-Json

        Write-Host "Container creation response is: $response"

        if ($response -ne "true") {
            Write-Error "Failed to create container for storing Terraform state"
            exit 1
        }
    }
    else {
        Write-Host "Container $ContainerName for storing Terraform state already exists"
    }
}

function Initialize-StorageAccountRoleContributorIsAssigned {
    param(
        [Parameter(Mandatory)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory)]
        [string]
        $PrincipalObjectId,
        [Parameter(Mandatory)]
        [string]
        $PrincipalType,
        [Parameter(Mandatory)]
        [string]
        $Role,
        [Parameter(Mandatory)]
        [string]
        $Scope
    )

    $roleAssignmentExists = az role assignment list --assignee "$PrincipalObjectId" `
        --role "$Role" `
        --scope "$Scope" `
        --query "[].principalId" | ConvertFrom-Json

    if ($null -eq $roleAssignmentExists) {
        Write-Host "Role $Role will be assigned to $PrincipalObjectId on scope $Scope"
        $response = az role assignment create --assignee-object-id "$PrincipalObjectId" `
            --assignee-principal-type "$PrincipalType" `
            --role "$Role" `
            --scope "$Scope" `
            --query "principalId" | ConvertFrom-Json

        if ($response -ne $PrincipalObjectId) {
            Write-Error "Failed to assign role $Role to $PrincipalObjectId on scope $Scope"
            exit 1
        }
    }
    else {
        Write-Host "Role $Role is already assigned to $PrincipalObjectId on scope $Scope"
    }
}

function Initialize-StorageAccountRetentionAndVersioning {
    param(
        [Parameter(Mandatory)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory)]
        [string]
        $AzureSubscriptionId
    )

    $currentPolicy = az storage account blob-service-properties show --account-name "$StorageAccountName" --resource-group "$ResourceGroupName" --subscription "$AzureSubscriptionId" | ConvertFrom-Json

    if ($null -eq $currentPolicy.isVersioningEnabled || $null -eq $currentPolicy.deleteRetentionPolicy || $false -eq $currentPolicy.deleteRetentionPolicy.enabled) {
        Write-Host "Versioning and retention will be enabled for storage account $StorageAccountName"
        # Retention must be larger than restore days, otherwise the restore policy will not be applied
        # 22 is the default datahub retention period
        az storage account blob-service-properties update --enable-delete-retention true --enable-versioning true --enable-change-feed true `
            --enable-container-delete-retention true --container-delete-retention-days 23 --delete-retention-days 23 --restore-days 22 --change-feed-days 23 `
            --enable-restore-policy true -n "$StorageAccountName" -g "$ResourceGroupName" --subscription "$AzureSubscriptionId"
    }
    else {
        Write-Host "Versioning and retention are already enabled for storage account $StorageAccountName"
    }
}
