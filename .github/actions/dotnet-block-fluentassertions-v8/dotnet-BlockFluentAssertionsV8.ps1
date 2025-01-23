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
    Check for the precense of FluentAssertions-v8 or higher

    .DESCRIPTION
    This function checks if the project(s) contains a reference to FluentAssertions-v8 or higher.
    If the project file contains a reference to FluentAssertions-v8 or higher, the function will terminate with an exit code of 1.
    If the project file does not contain a reference to FluentAssertions-v8 or higher, the function will terminate with an exit code of 0.
#>
function Block-FluentAssertionsV8 {
    param (
        [Parameter(Mandatory)]
        [string]
        $jsonFilePath
    )

    # Read and parse the JSON file
    $dependencies = Get-FluentAssertionsVersion $jsonFilePath
    if ($null -eq $dependencies) {
        exit 0
    }

    # Check if any version is greater than or equal to 8.0.0
    $forbidden_version = $fluentAssertionsVersions | Where-Object {
        $majorVersion = [int]($_ -split '\.')[0]
        $majorVersion -ge 8
    }

    if ($forbidden_version) {
        Write-Host "::error title='Forbidden FluentAssertions version detected'::Forbidden 'FluentAssertions' version $forbidden_version found"
        exit 1
    }

    Write-Host "::notice title='Check Passed'::No forbidden FluentAssertions versions detected."
    exit 0
}

function Get-FluentAssertionsVersion {
    param (
        [Parameter(Mandatory)]
        [string]
        $jsonFilePath
    )

    if (-Not (Test-Path $jsonFilePath)) {
        Write-Host "::error title='File not found'::The file $jsonFilePath does not exist."
        exit 1
    }

    # Read and parse the JSON file
    $dependencies = Get-Content $jsonFilePath | ConvertFrom-Json

    # Find all versions of FluentAssertions
    $fluentAssertionsVersions = $dependencies.projects
        | ForEach-Object { $_.frameworks }
        | ForEach-Object { $_.topLevelPackages }
        | Where-Object { $_.id -eq "FluentAssertions" }
        | Select-Object -ExpandProperty requestedVersion

    if ($fluentAssertionsVersions) {
        return $fluentAssertionsVersions -replace '^\[|\]$' # Remove brackets
    }

    return $null
}
