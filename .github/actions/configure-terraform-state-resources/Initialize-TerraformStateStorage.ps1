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

    $names = Get-TerraformNaming -DomainNameShort $DomainNameShort -EnvironmentShort $EnvironmentShort -EnvironmentInstance $EnvironmentInstance -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName
    $ResourceGroupName = $names.ResourceGroupName
    $StorageAccountName = $names.StorageAccountName

    $scope = Get-TerraformScope -SubscriptionId $AzureSubscriptionId -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName

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

    Grant-EnvironmentBasedGroupRoles -EnvironmentShort $EnvironmentShort -Scope $scope
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

function Grant-EnvironmentBasedGroupRoles {
    param(
        [string]$EnvironmentShort,
        [string]$Scope
    )

    if (-not $EnvironmentShort) { return }

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

    Grant-ADGroupRoles -GroupObjectId $groupObjectId -Role "Storage Blob Data Contributor" -Scope $Scope
}

function Grant-CustomGroupRoles {
    param(
        [string]$GroupRoleAssignments,
        [string]$Scope
    )

    if (-not $GroupRoleAssignments) { return }

    try {
        $assignments = $GroupRoleAssignments | ConvertFrom-Json
        foreach ($a in $assignments) {
            Grant-ADGroupRoles -GroupObjectId $a.object_id -Role $a.role -Scope $Scope
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
