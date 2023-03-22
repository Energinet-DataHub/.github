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
    It only asserts the definitions, not any usage of the fields.
#>
function Assert-GitHubActionsCasing {
    param (
        # The folder path in which to recursively search for relevant files to validate.
        [Parameter(Mandatory)]
        [string]
        $FolderPath
    )
    $isValid = $true

    [Object[]]$files = Get-ChildItem -Path $FolderPath -Recurse -File -Include ('*.yml', '*.yaml')
    Write-Host "Files found in $($FolderPath): $($files.Length)"

    [boolean] $isValid = $true
    foreach ($file in $files) {
        if ($false -eq (Test-GitHubFile -File $file)) {
            $isValid = $false
        }
    }

    if (-not $isValid) {
        throw 'One or more fields contain uppercase characters'
    }
}

<#
    .SYNOPSIS
    Test if all field definitions for given GitHub action or workflow file is lowercase.

    .DESCRIPTION
    For workflows the following definitions are tested:
     - workflow_dispatch.inputs
     - workflow_call.inputs
     - workflow_call.secrets
     - workflow_call.outputs

    For actions the following definitions are tested:
     - inputs
     - outputs
#>
function Test-GitHubFile {
    param (
        # The file object of the file to validate.
        [Parameter(Mandatory)]
        [Object]
        $File
    )
    Write-Host "Checking $($file.FullName)"

    [string]$yaml = Get-Content -Path $file.FullName | Out-String
    # Remove characters which hinders our YAML convertion
    $yaml = $yaml.Replace('{{', '').Replace('}}', '')

    [Object]$yamlObject = (ConvertFrom-Yaml -Yaml $yaml)

    $failures = @()
    if (Test-CompositeActionYaml -YamlObject $yamlObject) {
        foreach ($key in $yamlObject.inputs.Keys) {
            if (!($key -ceq $key.ToLower())) {
                $failures += “Action Input definition '$key' contains uppercase characters”
            }
        }

        foreach ($key in $yamlObject.outputs.Keys) {
            if (!($key -ceq $key.ToLower())) {
                $failures += “Action Output definition '$key' contains uppercase characters”
            }
        }

    }
    elseif (Test-WorkflowYaml -YamlObject $yamlObject) {
        foreach ($key in $yamlObject.on.workflow_call.inputs.Keys) {
            if (!($key -ceq $key.ToLower())) {
                $failures += “Workflow Input definition '$key' contains uppercase characters”
            }
        }

        foreach ($key in $yamlObject.on.workflow_call.outputs.Keys) {
            if (!($key -ceq $key.ToLower())) {
                $failures += “Workflow Output definition '$key' contains uppercase characters”
            }
        }

        foreach ($key in $yamlObject.on.workflow_call.secrets.Keys) {
            if (!($key -ceq $key.ToLower())) {
                $failures += “Workflow Secret definition '$key' contains uppercase characters”
            }
        }

        foreach ($key in $yamlObject.on.workflow_dispatch.inputs.Keys) {
            if (!($key -ceq $key.ToLower())) {
                $failures += “Workflow Dispatch Input definition '$key' contains uppercase characters”
            }
        }
    }

    foreach ($failure in $failures) {
        Write-Host $failure
    }

    [boolean]$isValid = ($failures.Count -eq 0)
    return $isValid
}

<#
    .SYNOPSIS
    Return '$true' if YAML is a composite action; otherwise '$false'.
#>
function Test-CompositeActionYaml {
    param (
        # YAML as object (hashtable)
        [Parameter(Mandatory)]
        [Object]
        $YamlObject
    )

    if ("composite" -eq $yamlObject.runs.using) {
        return $true
    }

    return $false
}

<#
    .SYNOPSIS
    Return '$true' if YAML is a workflow; otherwise '$false'.
#>
function Test-WorkflowYaml {
    param (
        # YAML as object (hashtable)
        [Parameter(Mandatory)]
        [Object]
        $YamlObject
    )

    if ($null -ne $yamlObject.jobs) {
        return $true
    }

    return $false
}
