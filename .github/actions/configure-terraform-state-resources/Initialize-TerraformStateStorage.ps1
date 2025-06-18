<#
.SYNOPSIS
This action ensures that the landing zone contains a resource group, storage account, container for storing Terraform State files.
It also assigns the required permissions to the storage account.
#>

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Initialize-TerraformStateStorage {
    param(
        [Parameter(Mandatory)][string]$AzureSpnObjectId,
        [Parameter(Mandatory)][string]$AzureSubscriptionId,
        [Parameter()][string]$EnvironmentShort,
        [Parameter()][string]$EnvironmentInstance,
        [Parameter()][string]$ResourceGroupName,
        [Parameter()][string]$StorageAccountName,
        [Parameter()][string]$GroupRoleAssignments
    )

    $location = "westeurope"
    $DomainNameShort = "tfs"

    # Derive names if not provided
    if (-not $ResourceGroupName -or -not $StorageAccountName) {
        if (-not $EnvironmentShort -or -not $EnvironmentInstance) {
            Write-Error "Either ResourceGroupName and StorageAccountName OR EnvironmentShort and EnvironmentInstance must be provided."
            exit 1
        }
        $TfStateNamingParts = $DomainNameShort, $EnvironmentShort, "we", $EnvironmentInstance
        $ResourceGroupName = "rg-" + ($TfStateNamingParts -join "-")
        $StorageAccountName = "st" + ($TfStateNamingParts -join "")
    }

    $scope = "/subscriptions/$AzureSubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"

    Initialize-ResourceGroupIsCreated -ResourceGroupName $ResourceGroupName -Location $location
    Initialize-StorageAccountIsCreated -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName -Location $location
    Initialize-ContainerIsCreated -StorageAccountName $StorageAccountName

    Initialize-StorageAccountRoleContributorIsAssigned `
        -StorageAccountName $StorageAccountName `
        -PrincipalObjectId $AzureSpnObjectId `
        -PrincipalType "ServicePrincipal" `
        -Role "Storage Blob Data Contributor" `
        -Scope $scope

    Initialize-StorageAccountRetentionAndVersioning `
        -StorageAccountName $StorageAccountName `
        -ResourceGroupName $ResourceGroupName `
        -AzureSubscriptionId $AzureSubscriptionId

    # Built-in environment-based group assignments
    if ($EnvironmentShort) {
        switch ($EnvironmentShort) {
            "u" { $group = "SEC-G-Datahub-PlatformDevelopersAzure" }
            "d" { $group = "SEC-A-Datahub-Test-001-Contributor-Controlplane" }
            "t" { $group = "SEC-A-Datahub-PreProd-001-Contributor-Controlplane" }
            "p" { $group = "SEC-A-Datahub-Prod-001-Contributor-Controlplane" }
            default {
                Write-Error "Unsupported environment short: $EnvironmentShort"
                exit 1
            }
        }

        $groupObjectId = az ad group show --group "$group" --query id -o tsv
        if (-not $groupObjectId) {
            Write-Error "Failed to resolve group object ID for $group"
            exit 1
        }

        Assign-ADGroupRoles -GroupObjectId $groupObjectId -Role "Storage Blob Data Contributor" -Scope $scope
    }

    # Optional custom group assignments
    if ($GroupRoleAssignments) {
        try {
            $assignments = $GroupRoleAssignments | ConvertFrom-Json
            foreach ($a in $assignments) {
                Assign-ADGroupRoles -GroupObjectId $a.object_id -Role $a.role -Scope $scope
            }
        } catch {
            Write-Error "Invalid JSON format for GroupRoleAssignments. Ensure it's a JSON array with object_id and role fields."
            throw $_
        }
    }
}

function Initialize-ResourceGroupIsCreated {
    param(
        [string]$ResourceGroupName,
        [string]$Location
    )

    if ((az group exists --name $ResourceGroupName) -eq "false") {
        Write-Host "Creating resource group $ResourceGroupName"
        $response = az group create --name $ResourceGroupName --location $Location --query "properties.provisioningState" | ConvertFrom-Json
        if ($response -ne "Succeeded") {
            Write-Error "Failed to create resource group"
            exit 1
        }
    } else {
        Write-Host "Resource group $ResourceGroupName already exists"
    }
}

function Initialize-StorageAccountIsCreated {
    param(
        [string]$StorageAccountName,
        [string]$ResourceGroupName,
        [string]$Location
    )

    $available = az storage account check-name --name $StorageAccountName --query 'nameAvailable' | ConvertFrom-Json
    if ($available) {
        Write-Host "Creating storage account $StorageAccountName"
        $response = az storage account create `
            --name $StorageAccountName `
            --resource-group $ResourceGroupName `
            --location $Location `
            --min-tls-version TLS1_2 `
            --sku Standard_LRS `
            --allow-shared-key-access false `
            --allow-blob-public-access false `
            --query "provisioningState" | ConvertFrom-Json

        if ($response -ne "Succeeded") {
            Write-Error "Failed to create storage account"
            exit 1
        }
    } else {
        Write-Host "Storage account $StorageAccountName already exists"
    }
}

function Initialize-ContainerIsCreated {
    param(
        [string]$StorageAccountName
    )

    $exists = az storage container exists --name "tfs" --account-name $StorageAccountName --auth-mode login --query "exists" | ConvertFrom-Json
    if (-not $exists) {
        Write-Host "Creating container 'tfs'"
        $created = az storage container create --name "tfs" --account-name $StorageAccountName --auth-mode login --query "created" | ConvertFrom-Json
        if (-not $created) {
            Write-Error "Failed to create blob container"
            exit 1
        }
    } else {
        Write-Host "Container 'tfs' already exists"
    }
}

function Initialize-StorageAccountRoleContributorIsAssigned {
    param(
        [string]$StorageAccountName,
        [string]$PrincipalObjectId,
        [string]$PrincipalType,
        [string]$Role,
        [string]$Scope
    )

    $exists = az role assignment list --assignee "$PrincipalObjectId" --role "$Role" --scope "$Scope" --query "[].principalId" | ConvertFrom-Json
    if (-not $exists) {
        Write-Host "Assigning $Role to $PrincipalObjectId"
        $assigned = az role assignment create --assignee-object-id $PrincipalObjectId --assignee-principal-type $PrincipalType --role $Role --scope $Scope --query "principalId" | ConvertFrom-Json
        if ($assigned -ne $PrincipalObjectId) {
            Write-Error "Failed to assign role"
            exit 1
        }
    } else {
        Write-Host "$Role already assigned to $PrincipalObjectId"
    }
}

function Initialize-StorageAccountRetentionAndVersioning {
    param(
        [string]$StorageAccountName,
        [string]$ResourceGroupName,
        [string]$AzureSubscriptionId
    )

    $policy = az storage account blob-service-properties show `
        --account-name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --subscription $AzureSubscriptionId | ConvertFrom-Json

    if (-not $policy.isVersioningEnabled -or -not $policy.deleteRetentionPolicy -or -not $policy.deleteRetentionPolicy.enabled) {
        Write-Host "Enabling retention + versioning for $StorageAccountName"
        az storage account blob-service-properties update `
            --enable-delete-retention true `
            --enable-versioning true `
            --enable-change-feed true `
            --enable-container-delete-retention true `
            --container-delete-retention-days 23 `
            --delete-retention-days 23 `
            --restore-days 22 `
            --enable-restore-policy true `
            --account-name $StorageAccountName `
            --resource-group $ResourceGroupName `
            --subscription $AzureSubscriptionId | Out-Null
    } else {
        Write-Host "Retention + versioning already enabled"
    }
}

function Assign-ADGroupRoles {
    param(
        [string]$GroupObjectId,
        [string]$Role,
        [string]$Scope
    )

    $exists = az role assignment list --assignee $GroupObjectId --role $Role --scope $Scope --query "[].principalId" | ConvertFrom-Json
    if (-not $exists) {
        Write-Host "Assigning $Role to group $GroupObjectId"
        az role assignment create --assignee-object-id $GroupObjectId --role $Role --scope $Scope | Out-Null
    } else {
        Write-Host "$Role already assigned to group $GroupObjectId"
    }
}
