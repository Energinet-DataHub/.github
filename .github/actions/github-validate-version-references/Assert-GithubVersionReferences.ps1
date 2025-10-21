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

###############################################################################
# SCRIPT CONSTANTS
# Functions within the module can use these variables as constants.
###############################################################################

$RepositoryTestPatterns = @(
    @{
        "repository" = "Energinet-DataHub/.github"
        "pattern"    = "(.*?)uses:\s*Energinet-DataHub/\.github/\.github/actions/(.*?)@v?(?<version>\d+)(.*?)"
    },
    @{
        "repository" = "Energinet-DataHub/geh-terraform-modules"
        "pattern"    = "(.*?)Energinet-DataHub/geh-terraform-modules\.git//(.*?)ref=v?(?<version>\d+)(.*?)"
    }
)

###############################################################################
# FUNCTIONS
###############################################################################

#######################################
# Get-LatestMajorVersion
#######################################

<#
    .SYNOPSIS
    Uses github CLI (gh) to retrieve latest major version

    .DESCRIPTION
    Simple filtering applied to Invoke-GetGithubReleases to return the latest major version
#>
function Get-LatestMajorVersion {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $Repository
    )

    [int[]]$majorVersions = (Invoke-GetGithubReleases -Repository $Repository `
        | Where-Object { $_.title -like "v*" } `
        | Select-Object -ExpandProperty title).Trim("v")

    return $majorVersions `
    | Sort-Object -Descending `
    | Select-Object -First 1
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to retrieves a list of releases

    .DESCRIPTION
    Simple function wrapping a call with gh to retrieve the latest releases from github.
#>
function Invoke-GetGithubReleases {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $Repository
    )
    gh release list -L 10000 -R $Repository `
    | ConvertFrom-Csv -Delimiter "`t" -Header @('title', 'type', 'tagname', 'published')
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
#######################################
# Assert-GithubVersionReferences
#######################################

<#
    .SYNOPSIS
    Check every file in a directory for deprecated github references

    .DESCRIPTION
    Only $MajorVersionsToKeep are supported. This function ensures every file in a folder doesn't have references to deprecated versions.
#>
function Assert-GithubVersionReferences {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [int]$MajorVersionsToKeep = 2
    )

    if ([string]::IsNullOrEmpty($env:GH_TOKEN)) {
        throw "Error: GH_TOKEN environment variable is not set, see https://cli.github.com/manual/gh_auth_login for details"
    }

    $files = Get-ChildItem -Path $Path -File -Recurse -Force -Depth 15 -Include *.yml, *.yaml, *.tf, *.md

    $deprecatedReferenceFound = $false

    foreach ($testPattern in $RepositoryTestPatterns) {
        [int]$latestVersion = Get-LatestMajorVersion -Repository $testPattern.repository
        [int]$unsupportedVersion = $latestVersion - $MajorVersionsToKeep

        foreach ($file in $files) {
            $content = Get-Content $file
            foreach ($line in $content) {
                $match = [regex]::Match($line, $testPattern.pattern)

                if ($match.Success -and [int]$match.Groups["version"].Value -le $unsupportedVersion) {
                    Write-Host "File found with reference to deprecated version $($match.Groups["version"]). Please change to a supported version. (Current latest: v$latestVersion)"
                    Write-Host "File:"$file.FullName
                    Write-Host "Context: "$match.Groups[0].Value.Trim()
                    $deprecatedReferenceFound = $true
                }
            }
        }
    }

    if ($deprecatedReferenceFound) {
        throw "Files contains references to deprecated versions"
    }
}
