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
    Uses github CLI (gh) to retrieves a list of releases

    .DESCRIPTION
    Simple function wrapping a call with gh to retrieve the latest releases from github.
#>
function Get-GithubReleases {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $Repository
    )
    gh release list -L 10000 -R $GitHubRepository | ConvertFrom-Csv -Delimiter "`t" -Header @('title', 'type', 'tagname', 'published')
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to retrieve latest major version

    .DESCRIPTION
    Simple filtering applied to Get-GithubReleases to return the latest major version
#>
function Get-LatestMajorVersion {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $Repository
    )
    [int]$latestMajor = (Get-GithubReleases -Repository $Repository | Where-Object { $_.title -like "v*" } | Select-Object -First 1 -ExpandProperty title).Trim("v")
    return $latestMajor
}

<#
    .SYNOPSIS
    A collection of patterns used to identify github references and their associated version.

    .DESCRIPTION
    Each pattern must include a (?<version>\d+) group used to identify the major version.
#>
$TestCases = @(
    @{
        "repository" = "Energinet-DataHub/.github"
        "pattern"    = "\s*uses:\s*Energinet-DataHub/\.github(.*)@v?(?<version>\d+)"
    },
    @{
        "repository" = "Energinet-DataHub/geh-terraform-modules"
        "pattern"    = "Energinet-DataHub/geh-terraform-modules\.git//(.*?)\?ref=v?(?<version>\d+)"
    }
)

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

    $files = Get-ChildItem -Path $Path -File -Recurse

    $deprecatedReferenceFound = $false

    foreach ($test in $TestCases) {

        [int]$latestVersion = Get-LatestMajorVersion -Repository $test.repository
        [int]$UnsupportedVersion = $latestVersion - $MajorVersionsToKeep

        foreach ($file in $files) {
            $content = Get-Content $file
            $match = [regex]::Match($Content, $test.pattern)

            if ($match.Success -and [int]$match.Groups["version"].Value -le $UnsupportedVersion) {
                Write-Host "File found with reference to deprecated version $UnsupportedVersion or lower. Please change to a supported version. (Current latest: v$latestVersion)"
                Write-Host "File:"$file.FullName
                Write-Host "Context: "$match.Groups[0].Value.Trim()
                $deprecatedReferenceFound = $true
            }
        }
    }

    if ($deprecatedReferenceFound) {
        throw "Files contains references to deprecated versions"
    }
}
