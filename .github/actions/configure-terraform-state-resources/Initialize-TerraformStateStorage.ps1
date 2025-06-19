<#
.SYNOPSIS
This action ensures that the landing zone contains a resource group, storage account, container for storing Terraform State files.
It also assigns the required permissions to the storage account.
#>

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Initialize-ResourceGroupIsCreated {
    param(
        [string]$ResourceGroupName,
        [string]$Location
    )

    $exists = az group exists --name $ResourceGroupName | ConvertFrom-Json
    if (-not $exists) {
        az group create --name $ResourceGroupName --location $Location | Out-Null
    }
}

function Initialize-StorageAccountIsCreated {
    param(
        [string]$StorageAccountName,
        [string]$ResourceGroupName,
        [string]$Location
    )

    $exists = az storage account show --name $StorageAccountName --resource-group $ResourceGroupName --query "name" -o tsv 2>$null
    if (-not $exists) {
        az storage account create `
            --name $StorageAccountName `
            --resource-group $ResourceGroupName `
            --location $Location `
            --sku Standard_LRS `
            --kind StorageV2 `
            --enable-hierarchical-namespace true `
            | Out-Null
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
        [string]$StorageAccountName,
        [string]$PrincipalObjectId,
        [string]$PrincipalType,
        [string]$Role,
        [string]$Scope
    )

    $exists = az role assignment list --assignee-object-id $PrincipalObjectId --role $Role --scope $Scope --query "[].principalId" | ConvertFrom-Json
    if (-not $exists) {
        az role assignment create --assignee-object-id $PrincipalObjectId --role $Role --scope $Scope --assignee-principal-type $PrincipalType | Out-Null
    }
}

function Initialize-StorageAccountRetentionAndVersioning {
    param(
        [string]$StorageAccountName,
        [string]$ResourceGroupName,
        [string]$AzureSubscriptionId
    )

    az storage account blob-service-properties update `
        --account-name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --subscription $AzureSubscriptionId `
        --enable-versioning true `
        --delete-retention-days 30 `
        --enable-delete-retention true `
        | Out-Null
}

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

    $names = Get-TerraformNaming -DomainNameShort $DomainNameShort -EnvironmentShort $EnvironmentShort -EnvironmentInstance $EnvironmentInstance -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName
    $ResourceGroupName = $names.ResourceGroupName
    $StorageAccountName = $names.StorageAccountName

    $scope = Get-TerraformScope -SubscriptionId $AzureSubscriptionId -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName

    Initialize-ResourceGroupIsCreated -ResourceGroupName $ResourceGroupName -Location $location
    Initialize-StorageAccountIsCreated -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName -Location $location
    Initialize-ContainerIsCreated -ContainerName $DomainNameShort -StorageAccountName $storageAccountName

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

    Grant-CustomGroupRoles -GroupRoleAssignments $GroupRoleAssignments -Scope $scope
}

function Get-TerraformNaming {
    param(
        [string]$DomainNameShort,
        [string]$EnvironmentShort,
        [string]$EnvironmentInstance,
        [string]$ResourceGroupName,
        [string]$StorageAccountName
    )

    if (-not $ResourceGroupName -or -not $StorageAccountName) {
        if (-not $EnvironmentShort -or -not $EnvironmentInstance) {
            Write-Error "Either ResourceGroupName and StorageAccountName OR EnvironmentShort and EnvironmentInstance must be provided."
            exit 1
        }
        $parts = $DomainNameShort, $EnvironmentShort, "we", $EnvironmentInstance
        $ResourceGroupName = "rg-" + ($parts -join "-")
        $StorageAccountName = "st" + ($parts -join "")
    }

    return @{ ResourceGroupName = $ResourceGroupName; StorageAccountName = $StorageAccountName }
}

function Get-TerraformScope {
    param(
        [string]$SubscriptionId,
        [string]$ResourceGroupName,
        [string]$StorageAccountName
    )
    return "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"
}

function Grant-CustomGroupRoles {
    param(
        [string]$GroupRoleAssignments,
        [string]$Scope
    )

    if (-not $GroupRoleAssignments) { return }

    Write-Host "Raw GroupRoleAssignments input: $GroupRoleAssignments"

    try {
        $assignments = $GroupRoleAssignments | ConvertFrom-Json
        foreach ($a in $assignments) {
            if ($a.group_name) {
                $groupObjectId = az ad group show --group "$a.group_name" --query id -o tsv
                if (-not $groupObjectId) {
                    Write-Error "Failed to resolve group object ID for $($a.group_name)"
                    exit 1
                }
            } elseif ($a.object_id) {
                $groupObjectId = $a.object_id
            } else {
                Write-Error "Each assignment must include either 'group_name' or 'object_id'"
                exit 1
            }

            Grant-ADGroupRoles -GroupObjectId $groupObjectId -Role $a.role -Scope $Scope
        }
    } catch {
        Write-Error "Invalid JSON format for GroupRoleAssignments. Ensure it's a JSON array with object_id and role fields."
        throw $_
    }
}

function Grant-ADGroupRoles {
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
