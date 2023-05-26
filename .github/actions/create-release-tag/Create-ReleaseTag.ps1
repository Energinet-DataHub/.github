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

        # Major Version number
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
        $GitHubEvent,

        # Regex Patterns used to identify references in other projects
        [Parameter(Mandatory = $false)]
        [string[]]
        $UsagePatterns = @()
    )

    Write-Host "Github event name is: $GitHubEvent"
    $isPullRequest = $GitHubEvent -eq 'pull_request'
    Write-Host "Is PR: $isPullRequest"

    $version = "$MajorVersion.$MinorVersion.$PatchVersion"

    if ($null -eq $env:GH_TOKEN) {
        throw "Error: GH_TOKEN environment variable is not set, see https://cli.github.com/manual/gh_auth_login for details"
    }

    # Validate Version
    if ($UsagePatterns) {
        # Check that other projects arent referencing older versions
        Assert-MajorVersionDeprecations -MajorVersion $MajorVersion -Repository $GitHubRepository -Patterns $UsagePatterns
    }
    $existingReleases = Get-GithubReleases -GitHubRepository $GitHubRepository
    $existingVersions = $existingReleases.title.Trim("v")
    $conflicts = Find-ConflictingVersions $version $existingVersions

    if ($conflicts.Count) {
        $latest = $conflicts | Select-Object -First 1
        throw "Error: Cannot create release $version in $GithubRepository because a later or identical version number exist. Latest release is: $latest"
    }

    Write-Host "Validated version tag: $version"

    # Updating major version tag
    if (!$isPullRequest) {
        Update-MajorVersion -Version $version -GitHubRepository $GitHubRepository -GitHubBranch $GitHubBranch
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
    Uses github CLI (gh) to retrieves a list of releases

    .DESCRIPTION
    Simple function wrapping a call with gh to retrieve the latest releases from github.
#>
function Get-GithubReleases {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $GitHubRepository
    )
    gh release list -L 10000 -R $repo | ConvertFrom-Csv -Delimiter "`t" -Header @('title', 'type', 'tagname', 'published')
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
function Update-MajorVersion {
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

<#
    .SYNOPSIS
    Helper function to perform a Github code search

    .DESCRIPTION
    Searches github code api for references to a specific repository. Returns GithubCodeSearchResult
#>
class GithubCodeSearchResult {
    [string]$Url
    [string]$Repository
    [string]$Path
    [string[]]$TextMatches

    [string]ToString() {
        return ("Link: {0}`nRepository: {1}`nPath: {2}`nContext:`n{3}" -f $this.Url, $this.Repository, $this.Path, ($this.TextMatches -join "`n-`n"))
    }
}
function Invoke-GithubCodeSearch {
    param(
        #The Sub-path in the repository for relevant files. By default only files in .github/ are relevant
        [Parameter(Mandatory)]
        [string]$Search,

        #Limit search to a specific github organization. By default this is always Energinet-DataHub
        [Parameter(Mandatory = $false)]
        [string]$Organization
    )
    [string]$json = gh api -H "Accept: application/vnd.github.text-match+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        "/search/code?q=org:$Organization%20$Search"

    [GithubCodeSearchResult[]]$searchResults = @()

    foreach ($item in ($json | ConvertFrom-Json).Items) {
        $result = [GithubCodeSearchResult]::new()
        $result.Path = $item.path
        $result.Repository = $item.repository.full_name
        $result.Url = $item.html_url
        $result.TextMatches = $item.text_matches.fragment
        $searchResults += $result
    }

    return $searchResults
}
<#
    .SYNOPSIS
    Identifies and prevents further execution if deprecated major version are found

    .DESCRIPTION
    Runs through a github code api search with specific patterns and throws an exception in case specific references to deprecated versions are found
#>
function Assert-MajorVersionDeprecations {
    param(
        #Major Version
        [Parameter(Mandatory)]
        [string]$MajorVersion,

        #The Repository being referenced
        [Parameter(Mandatory)]
        [string]$Repository,

        #Patterns to identify version references. Must contain a named (?<version>) group to identify version number.
        [Parameter(Mandatory)]
        [string[]]$Patterns,

        #Patterns to identify version references. Must contain a named (?<version>) group to identify version number.
        # Note: This value needs to be kept in sync with the automated cleanup script in dh3-automation
        # https://github.com/Energinet-DataHub/dh3-automation/blob/main/source/github-repository/Remove-DeprecatedReleases.ps1
        [Parameter(Mandatory = $false)]
        [int]$MajorVersionsToKeep = 2
    )

    [string]$Organization = $Repository -split "/" | Select-Object -First 1
    [GithubCodeSearchResult[]] $searchResults = Invoke-GithubCodeSearch -Organization $Organization -Search $Repository

    if ($searchResults.Count -eq 0) {
        return $true
    }

    [int]$UnsupportedVersion = $MajorVersion - $MajorVersionsToKeep

    # Filter all search results and find lines referencing deprecated version tags
    [GithubCodeSearchResult[]]$filteredResults = $searchResults | Where-Object {
        $searchResult = $_
        $matchFound = $false
        $Patterns | ForEach-Object {
            $match = [regex]::Match($searchResult.TextMatches, $_)
            $matchFound = $matchFound -or ($match.Success -and [int]$match.Groups["version"].Value -le $UnsupportedVersion)
        }
        return $matchFound
    }

    if ($filteredResults.Count -gt 0) {
        $filteredResults | % { Write-Host "--- Version deprecation:`n$($_.ToString())" }

        throw "Cannot Update Major Version to $MajorVersion. Found deprecated references. Need to update depending projects first."
    }
}

