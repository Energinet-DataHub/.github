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

Describe "When dot-sourcing the script" {
    BeforeAll {
        Install-Module -Name PowerShell-Yaml -Force
        . $PSScriptRoot/Assert-GitHubActionsCasing.ps1

        Mock Write-Host {}
    }

    Context "Given Assert-GitHubActionsCasing is called with '<folderPath>'" -ForEach @(
        @{ FolderPath = "$PSScriptRoot/../../../source/github-actions-validate-casing/test-files/actions/action-valid"; ExpectedCount = 1 }
        @{ FolderPath = "$PSScriptRoot/../../../source/github-actions-validate-casing/test-files/actions"; ExpectedCount = 3 }
        @{ FolderPath = "$PSScriptRoot/../../../source/github-actions-validate-casing/test-files"; ExpectedCount = 5 }
    ) {
        BeforeAll {
            Mock Test-GitHubFile {}
        }

        It "Should find <expectedCount> file(s)" {
            # Act
            Assert-GitHubActionsCasing -FolderPath $folderPath

            Should -Invoke Test-GitHubFile -Times $expectedCount -Exactly
        }
    }

    Context "Given Assert-GitHubActionsCasing is given valid action file with invalid 3rd party action" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/../../../source/github-actions-validate-casing/test-files/actions/action-valid-with-invalid-3rd-party"
        }

        It "Should not throw" {
            # Act
            Assert-GitHubActionsCasing -FolderPath $script:folderPath
        }
    }

    Context "Given Assert-GitHubActionsCasing is given valid action file" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/../../../source/github-actions-validate-casing/test-files/actions/action-valid"
        }

        It "Should not throw" {
            # Act
            Assert-GitHubActionsCasing -FolderPath $script:folderPath
        }
    }

    Context "Given Assert-GitHubActionsCasing is given invalid action file" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/../../../source/github-actions-validate-casing/test-files/actions/action-invalid"
        }

        It "Should throw" {
            # Act
            {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            } | Should -Throw 'One or more fields contain uppercase characters'
        }

        It "Should find 2 invalid input definitions" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Action Input definition")
            }
        }

        It "Should find 1 invalid output definition" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Action Output definition")
            }
        }

        It "Should find 2 invalid step with definitions" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Action Step With definition")
            }
        }
    }

    Context "Given Assert-GitHubActionsCasing is given valid workflow file" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/../../../source/github-actions-validate-casing/test-files/workflows/workflow-valid"
        }

        It "Should not throw" {
            # Act
            Assert-GitHubActionsCasing -FolderPath $script:folderPath
        }
    }

    Context "Given Assert-GitHubActionsCasing is given invalid workflow file" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/../../../source/github-actions-validate-casing/test-files/workflows/workflow-invalid"
        }

        It "Should throw" {
            # Act
            {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            } | Should -Throw 'One or more fields contain uppercase characters'
        }

        It "Should find 2 invalid input definitions" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Workflow Input definition")
            }
        }

        It "Should find 1 invalid output definition" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Workflow Output definition")
            }
        }

        It "Should find 1 invalid secret definition" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Workflow Secret definition")
            }
        }

        It "Should find 1 invalid workflow dispatch input definition" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Workflow Dispatch Input definition")
            }
        }

        It "Should find 2 invalid job with definitions" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Job With definition")
            }
        }

        It "Should find 1 invalid job output definition" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Job Output definition")
            }
        }

        It "Should find 2 invalid job secret definitions" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Job Secret definition")
            }
        }

        It "Should find 1 invalid job step with definition" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -and $Object.StartsWith("Job Step With definition")
            }
        }
    }
}
