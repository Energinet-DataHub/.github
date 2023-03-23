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

using namespace System.Collections.Generic

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
    [Object[]]$files = Get-ChildItem -Path $FolderPath -Recurse -File -Include ('*.yml', '*.yaml')
    Write-Host "Searched path '$($FolderPath)' for YAML files. Found '$($files.Count)' file(s)."

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
#>
function Test-GitHubFile {
    param (
        # The file object of the file to validate.
        [Parameter(Mandatory)]
        [Object]
        $File
    )
    Write-Host "----- Checking '$($file.FullName)'"

    [string]$yaml = Get-Content -Path $file.FullName | Out-String
    # Remove characters which hinders our YAML convertion
    $yaml = $yaml.Replace('{{', '').Replace('}}', '')

    [Object]$yamlObject = (ConvertFrom-Yaml -Yaml $yaml)

    [List[string]]$failures = [List[string]]::new()
    if (Test-CompositeActionYaml -YamlObject $yamlObject) {
        Add-CompositeActionFailures -YamlObject $yamlObject -Failures $failures
    }
    elseif (Test-WorkflowYaml -YamlObject $yamlObject) {
        Add-WorkflowOnFailures -YamlObject $yamlObject -Failures $failures
        Add-WorkflowJobsFailures -YamlObject $yamlObject -Failures $failures
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
        # YAML as object (hashtables)
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
        # YAML as object (hashtables)
        [Parameter(Mandatory)]
        [Object]
        $YamlObject
    )

    if ($null -ne $yamlObject.jobs) {
        return $true
    }

    return $false
}

<#
    .SYNOPSIS
    Validate composite action YAML and add any failures found to the current list of failures.

    .DESCRIPTION
    The following definitions are validated:
     - inputs
     - outputs

    The following 'runs.steps' definitions are validated:
     - with
#>
function Add-CompositeActionFailures {
    param (
        # YAML as object (hashtables)
        [Parameter(Mandatory)]
        [Object]
        $YamlObject,
        # List of failures, to which we should add any additionally failures found
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[string]]
        $Failures
    )

    foreach ($key in $YamlObject.inputs.Keys) {
        Add-IfCasingFailure `
            -Value $key `
            -DefinitionKind “Action Input” `
            -Failures $Failures
    }

    foreach ($key in $YamlObject.outputs.Keys) {
        Add-IfCasingFailure `
            -Value $key `
            -DefinitionKind “Action Output” `
            -Failures $Failures
    }

    foreach ($key in $YamlObject.runs.steps.with.Keys) {
        Add-IfCasingFailure `
            -Value $key `
            -DefinitionKind “Action Step With” `
            -Failures $Failures
    }
}

<#
    .SYNOPSIS
    Validate workflow 'on.*' YAML and add any failures found to the current list of failures.

    .DESCRIPTION
    The following definitions are validated:
     - workflow_dispatch.inputs
     - workflow_call.inputs
     - workflow_call.secrets
     - workflow_call.outputs
#>
function Add-WorkflowOnFailures {
    param (
        # YAML as object (hashtables)
        [Parameter(Mandatory)]
        [Object]
        $YamlObject,
        # List of failures, to which we should add any additionally failures found
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[string]]
        $Failures
    )

    foreach ($key in $yamlObject.on.workflow_call.inputs.Keys) {
        Add-IfCasingFailure `
            -Value $key `
            -DefinitionKind “Workflow Input” `
            -Failures $Failures
    }

    foreach ($key in $yamlObject.on.workflow_call.outputs.Keys) {
        Add-IfCasingFailure `
            -Value $key `
            -DefinitionKind “Workflow Output" `
            -Failures $Failures
    }

    foreach ($key in $yamlObject.on.workflow_call.secrets.Keys) {
        Add-IfCasingFailure `
            -Value $key `
            -DefinitionKind “Workflow Secret" `
            -Failures $Failures
    }

    foreach ($key in $yamlObject.on.workflow_dispatch.inputs.Keys) {
        Add-IfCasingFailure `
            -Value $key `
            -DefinitionKind “Workflow Dispatch Input” `
            -Failures $Failures
    }
}

<#
    .SYNOPSIS
    Validate workflow 'jobs.*' YAML and add any failures found to the current list of failures.

    .DESCRIPTION
    The following 'jobs' definitions are validated:
     - with
     - secrets (list of keys or 'inherit')
     - outputs
     - steps.with (inline jobs calling actions)
#>
function Add-WorkflowJobsFailures {
    param (
        # YAML as object (hashtables)
        [Parameter(Mandatory)]
        [Object]
        $YamlObject,
        # List of failures, to which we should add any additionally failures found
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[string]]
        $Failures
    )

    foreach ($job in $YamlObject.jobs.Values) {
        foreach ($key in $job.with.Keys) {
            Add-IfCasingFailure `
                -Value $key `
                -DefinitionKind “Job With" `
                -Failures $Failures
        }

        foreach ($key in $job.outputs.Keys) {
            Add-IfCasingFailure `
                -Value $key `
                -DefinitionKind “Job Output" `
                -Failures $Failures
        }

        if ($null -ne $job.secrets) {
            if ($job.secrets.GetType().Name -eq "Hashtable") {
                foreach ($key in $job.secrets.Keys) {
                    Add-IfCasingFailure `
                        -Value $key `
                        -DefinitionKind “Job Secret" `
                        -Failures $Failures
                }
            }
            else {
                $value = $job.secrets
                Add-IfCasingFailure `
                    -Value $value `
                    -DefinitionKind “Job Secret" `
                    -Failures $Failures
            }
        }

        # Inline job
        foreach ($key in $job.steps.with.Keys) {
            Add-IfCasingFailure `
                -Value $key `
                -DefinitionKind “Job Step With" `
                -Failures $Failures
        }
    }
}

<#
    .SYNOPSIS
    Add failure message to list of failures, if value contains uppercase characters.
#>
function Add-IfCasingFailure {
    param (
        # Value we want to validate.
        [Parameter(Mandatory)]
        [string]
        $Value,
        # The the YAML definition kind of the value. Used to build any failure message added to the list of failures.
        [Parameter(Mandatory)]
        [string]
        $DefinitionKind,
        # List of failures, to which we should add a failure message if the value is invalid.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[string]]
        $Failures
    )

    if (!($Value -ceq $Value.ToLower())) {
        [void]$Failures.Add(“$DefinitionKind definition '$Value' contains uppercase characters.”)
    }
}
