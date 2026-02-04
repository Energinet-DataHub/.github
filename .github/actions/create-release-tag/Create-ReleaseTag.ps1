<#
    .SYNOPSIS
    Validate and Updates Release Tags

    .DESCRIPTION
    The function validates that the checked in version isn't a predecenting or identical version of targetted branch (eg. main)
#>
function Create-ReleaseTag {
    param (
        # Module name
        [Parameter(Mandatory)]
        [string]
        $ModuleName,

        # Major Version number
        [Parameter(Mandatory)]
        [string]
        $MajorVersion,

        # Minor Version number
        [Parameter(Mandatory)]
        [string]
        $MinorVersion,

        # Patch Version number
        [Parameter(Mandatory)]
        [string]
        $PatchVersion,

        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $GitHubRepository,

        # The value of the GitHub repository branch.
        [Parameter(Mandatory = $false)]
        [string]
        $GitHubBranch,

        # The value of the GitHub event
        [Parameter(Mandatory)]
        [string]
        $GitHubEvent
    )

    Write-Host "Github event name is: $GitHubEvent"
    $isPushToMain = $GitHubEvent -eq 'push' -and $GitHubBranch -eq 'main'
    Write-Host "Is push to main: $isPushToMain"

    $version = "${ModuleName}_${MajorVersion}.${MinorVersion}.${PatchVersion}"

    if ([string]::IsNullOrEmpty($env:GH_TOKEN)) {
        throw "Error: GH_TOKEN environment variable is not set, see https://cli.github.com/manual/gh_auth_login for details"
    }

    $existingReleases = Get-GithubReleases -GitHubRepository $GitHubRepository -ModuleName $ModuleName
    Write-Host "Existing releases: $existingReleases"

    $conflicts = Find-ConflictingVersions $version $existingReleases

    if ($conflicts.Count) {
        $latest = $conflicts | Select-Object -First 1
        throw "Error: Cannot create release $version in $GithubRepository because a later or identical version number exist. Latest release is: $latest"
    }

    Write-Host "Validated version tag: $version"

    # Create version tag
    if ($isPushToMain) {
        Write-Host "Creating $version"
        gh release create $version --generate-notes --latest --title $version --target $GithubBranch -R $GitHubRepository
    }
    else {
        Write-Host 'This was a dry-run, no changes have been made'
    }

    Write-Host "All done"
}

<#
    .SYNOPSIS
    Compares two version numbers

    .DESCRIPTION
    Compares two version numbers in dot-notation (eg. ModuleName_1.0.3) and returns (-1, 1, 0) if the first number is smaller, bigger or equivalent version
#>
function Compare-Versions {
    param(
        # Previous Version
        [Parameter(Mandatory)]
        [string]
        $Version,

        # New Version
        [Parameter(Mandatory)]
        [string]
        $Comparison
    )

    Write-Host "Comparing $Version with $Comparison"

    # Extract numeric part of the version string
    $v1 = ($Version -split "_")[1] -split "\."
    $v2 = ($Comparison -split "_")[1] -split "\."

    # Pad the shorter version number with zeros
    $diff = $v1.Count - $v2.Count
    if ($diff -gt 0) {
        $v2 += , @(0) * $diff
    }
    elseif ($diff -lt 0) {
        $v1 += , @(0) * (-$diff)
    }

    # Compare each segment of the version number
    foreach ($i in 0..($v1.Count - 1)) {
        $v1val = [int]::Parse($v1[$i])
        $v2val = [int]::Parse($v2[$i])

        if ($v1val -gt $v2val) {
            return 1
        }
        elseif ($v1val -lt $v2val) {
            return -1
        }
    }

    # The version numbers are equal
    return 0
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to retrieve a list of releases

    .DESCRIPTION
    Simple function wrapping a call with gh to retrieve the latest releases from github and filters by module name, returning an array of titles.
#>
function Get-GithubReleases {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $GitHubRepository,

        # The module name to filter releases.
        [Parameter(Mandatory)]
        [string]
        $ModuleName
    )

    # Retrieve the list of releases
    $allReleases = gh release list -L 10000 -R $GitHubRepository | ConvertFrom-Csv -Delimiter "`t" -Header @('title', 'type', 'tagname', 'published')

    # Filter the releases by module name and return their titles
    $filteredTitles = $allReleases | Where-Object { $_.title -like "$($ModuleName)_*" } | Select-Object -ExpandProperty title

    # Ensure the function returns an array and handle the case where there are no releases
    if ($null -eq $filteredTitles -or $filteredTitles.Count -eq 0) {
        $filteredTitles = @("${ModuleName}_0.0.0")
    }

    return $filteredTitles
}

<#
    .SYNOPSIS
    Identifies conflicting versions in a list

    .DESCRIPTION
    Given a version and a list of versions, a list of all versions succeedign
#>
function Find-ConflictingVersions {
    param(
        # Previous Version
        [Parameter(Mandatory)]
        [string]
        $Version,

        # Previous Version
        [Parameter(Mandatory)]
        [Object[]]
        $ReleaseList
    )

    $conflicts = $ReleaseList | Where-Object { (Compare-Versions $Version $_) -le 0 }
    return (, [array]$conflicts)
}
