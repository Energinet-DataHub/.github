# Copyright 2020 Energinet DataHub A/S
#
# Licensed under the Apache License, Version 2.0 (the "License2");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

<#
    .SYNOPSIS
    Validate and Updates Release Tags

    .DESCRIPTION
    The function validates that the checked in version isn't a predecenting or identical version of targetted branch (eg. main)
#>
function Create-ReleaseTag {
    param (
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

    $version = "$MajorVersion.$MinorVersion.$PatchVersion"

    if ([string]::IsNullOrEmpty($env:GH_TOKEN)) {
        throw "Error: GH_TOKEN environment variable is not set, see https://cli.github.com/manual/gh_auth_login for details"
    }

    $existingReleases = Get-GithubReleases -GitHubRepository $GitHubRepository
    if ($null -eq $existingReleases) {
        $existingVersions = '0.0.0'
    }
    else {
        $existingVersions = $existingReleases.title.Trim("v")
    }

    $conflicts = Find-ConflictingVersions $version $existingVersions

    if ($conflicts.Count) {
        $latest = $conflicts | Select-Object -First 1
        throw "Error: Cannot create release $version in $GithubRepository because a later or identical version number exist. Latest release is: $latest"
    }

    Write-Host "Validated version tag: $version"

    # Updating major version tag
    if ($isPushToMain) {
        Update-VersionTags -Version $version -GitHubRepository $GitHubRepository -GitHubBranch $GitHubBranch
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
    Compares two version numbers in dot-notation (eg. 1.0.3) and return (-1,1,0) if the first number is smaller, bigger og equivelant version
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
    # Split the version numbers into segments
    $v1 = $Version -Split "\."
    $v2 = $Comparison -Split "\."

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
    Simple function wrapping a call with gh to retrieve the latest releases from github and filter out those containing any text followed by an underscore before the version.
#>
function Get-GithubReleases {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $GitHubRepository
    )

    # Retrieve the list of releases
    $allReleases = gh release list -L 10000 -R $GitHubRepository | ConvertFrom-Csv -Delimiter "`t" -Header @('title', 'type', 'tagname', 'published')

    # Filter out releases containing any text followed by an underscore before the version
    $filteredReleases = $allReleases | Where-Object { $_.title -notmatch "_\d+(\.\d+)*$" }

    return $filteredReleases
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

<#
    .SYNOPSIS
    Removes previous version tag and replacing with new

    .DESCRIPTION
    When merging new release number, update the major release tag eg. v11 with the latest version number
#>
function Update-VersionTags {
    param(
        # Version number
        [Parameter(Mandatory)]
        [ValidatePattern("^(0|[1-9]\d*)((\.(0|[1-9]\d*)\.(0|[1-9]\d*))?)?$")]
        [string]
        $Version,

        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $GitHubRepository,

        # The value of the GitHub repository branch.
        [Parameter(Mandatory = $false)]
        [string]
        $GitHubBranch
    )
    $MajorVersion = $Version -Split "\." | Select-Object -First 1

    Write-Host "Deleting major version tag v$MajorVersion"
    gh release delete "v$MajorVersion" -y --cleanup-tag -R $GitHubRepository

    Write-Host "Creating new major version tag v$MajorVersion"
    gh release create "v$MajorVersion" --title "v$MajorVersion" --notes "Latest release" --target $GitHubBranch -R $GitHubRepository

    Write-Host "Creating $Version"
    gh release create $Version --generate-notes --latest --title $Version --target $GithubBranch -R $GitHubRepository
}
