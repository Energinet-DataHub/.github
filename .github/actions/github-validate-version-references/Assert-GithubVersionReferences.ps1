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
    Gets the latest major version from a repository folder

    .DESCRIPTION
    Looks up the create-release-tag file in a repository (i.e. .github or geh-terraform-modules) and extracts the verison number defined.
#>
function Get-LatestMajorVersion {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory)]
        [string]
        $Repository
    )
    [int] $major = Get-Content -Path (Join-Path $Repository ".github/workflows/create-release-tag.yml") `
    | Select-String -Pattern "major_version: (?<version>\d+)" `
    | Select-Object -First 1 -ExpandProperty Matches `
    | Select-Object -ExpandProperty Groups `
    | Where-Object { $_.Name -eq "version" }  `
    | Select-Object -ExpandProperty Value

    return $major
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
        "pattern"    = "(.*?)uses:\s*Energinet-DataHub/\.github/\.github/actions/(.*?)@v?(?<version>\d+)(.*?)"
    },
    @{
        "repository" = "Energinet-DataHub/geh-terraform-modules"
        "pattern"    = "(.*?)Energinet-DataHub/geh-terraform-modules\.git//(.*?)ref=v?(?<version>\d+)(.*?)"
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

    $files = Get-ChildItem -Path $Path -File -Recurse -Force -Depth 15

    $deprecatedReferenceFound = $false

    foreach ($test in $TestCases) {
        [int]$latestVersion = Get-LatestMajorVersion -Repository $test.repository
        [int]$UnsupportedVersion = $latestVersion - $MajorVersionsToKeep

        foreach ($file in $files) {
            $content = Get-Content $file
            foreach ($line in $content) {
                $match = [regex]::Match($line, $test.pattern)

                if ($match.Success -and [int]$match.Groups["version"].Value -le $UnsupportedVersion) {
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

function Find-DeprecatedRepositoryReferences {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [int]$UnsupportedVersion,
        [Parameter(Mandatory)]
        [string]$Pattern
    )
    $files = Get-ChildItem -Path $Path -File -Recurse -Force -Depth 15
    foreach ($file in $files) {
        $content = Get-Content $file
        foreach ($line in $content) {
            $match = [regex]::Match($line, $Pattern)

            if ($match.Success -and [int]$match.Groups["version"].Value -le $UnsupportedVersion) {
                Write-Host "File found with reference to deprecated version $($match.Groups["version"]). Please change to a supported version. (Current latest: v$latestVersion)"
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
function Assert-DotGithubVersionReferences {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$RepositoryPath,
        [Parameter(Mandatory = $false)]
        [int]$MajorVersionsToKeep = 2
    )

    [int]$UnsupportedVersion = (Get-LatestMajorVersion $RepositoryPath) - $MajorVersionsToKeep
    Find-DeprecatedRepositoryReferences `
        -Path $Path `
        -UnsupportedVersion $UnsupportedVersion `
        -Pattern "(.*?)uses:\s*Energinet-DataHub/\.github/\.github/actions/(.*?)@v?(?<version>\d+)(.*?)"

}
