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

Import-Module PowerShell-Yaml -Force

<#
    .SYNOPSIS
    Assert all inputs, outputs and secrets used in DH3 GitHub action and workflow files are valid.

    .DESCRIPTION
    Assert all inputs, outputs and secrets used in DH3 GitHub action and workflow files are lowercase.
    It asserts the definitions as well as any usage of the parameters, but only for DH3 custom actions and workflows.
#>
function Assert-GitHubActionsCasing {
    param (
        # The folder path in which to recursively search for relevant files to validate.
        [Parameter(Mandatory)]
        [string]
        $FolderPath
    )
    $isValid = $true

    $files = Get-ChildItem -Path $folder -Recurse -File -Include ('*.yml', '*.yaml')
    Write-Host "Files found in $($folder): $($files.Length)"

    foreach ($file in $files) {
        Write-Host "Checking $($file.FullName)"

        $yaml = Get-Content -Path $file.FullName | Out-String

        $yaml = $yaml.Replace('{{', '').Replace('}}', '')
        $jsonObj = (ConvertFrom-Yaml -Yaml $yaml)
        $inputKeys = $jsonObj.on.workflow_call.inputs.Keys ?? $jsonObj.inputs.Keys

        foreach ($inputKey in $inputKeys) {
            if (!($inputKey -ceq $inputKey.ToLower())) {
                Write-Host “Input variable '$inputKey' contains uppercase characters”

                $isValid = $false
            }
        }
    }

    if (-not $isValid) {
        throw 'One or more parameters contain uppercase characters'
    }
}
