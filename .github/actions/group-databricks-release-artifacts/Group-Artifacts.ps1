<#
    .SYNOPSIS
    Collect Databricks release artifacts

    .DESCRIPTION
    The script collects python wheel distribution files and Databricks assets in a
    common artifacts folder to be used for Databricks deployment.
#>
function Group-Artifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $DistPath,
        [Parameter(Mandatory = $true)]
        [string]
        $DashboardPath,
        [Parameter(Mandatory = $true)]
        [string]
        $Destination,
        [Parameter(Mandatory = $true)]
        [boolean]
        $ShouldIncludeAssets
    )

    if ((Test-Path -Path $Destination) -eq $false) {
        New-Item -Path $Destination -ItemType 'directory'
    }

    if ($ShouldIncludeAssets) {
        Move-Item -Path $DistPath -Destination $Destination
        Move-Item -Path $DashboardPath -Destination $Destination
    }
    else {
        # If assets (i.e. dashboards) should not be included, the dist folder content
        # should be directly under the destination folder
        Get-ChildItem -Path $DistPath -Recurse -File
        | Move-Item -Destination $Destination
    }
}
