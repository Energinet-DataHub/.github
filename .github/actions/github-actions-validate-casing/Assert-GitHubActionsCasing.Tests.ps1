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
        @{ FolderPath = "$PSScriptRoot/test-files/actions/action-valid"; ExpectedCount = 1 }
        @{ FolderPath = "$PSScriptRoot/test-files/actions"; ExpectedCount = 2 }
        @{ FolderPath = "$PSScriptRoot/test-files"; ExpectedCount = 4 }
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

    Context "Given Assert-GitHubActionsCasing is given valid action file" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/test-files/actions/action-valid"
        }

        It "Should not throw" {
            # Act
            Assert-GitHubActionsCasing -FolderPath $script:folderPath
        }
    }

    Context "Given Assert-GitHubActionsCasing is given invalid action file" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/test-files/actions/action-invalid"
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
                $Object -and $Object.StartsWith("Input definition")
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
                $Object -and $Object.StartsWith("Output definition")
            }
        }

        It "Should not find any secret definition" {
            # Act
            try {
                Assert-GitHubActionsCasing -FolderPath $script:folderPath
            }
            catch {
            }

            Should -Not -Invoke Write-Host -ParameterFilter {
                $Object -and $Object.StartsWith("Secret definition")
            }
        }
    }

    Context "Given Assert-GitHubActionsCasing is given valid workflow file" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/test-files/workflows/workflow-valid"
        }

        It "Should not throw" {
            # Act
            Assert-GitHubActionsCasing -FolderPath $script:folderPath
        }
    }

    Context "Given Assert-GitHubActionsCasing is given invalid workflow file" {
        BeforeAll {
            $script:folderPath = "$PSScriptRoot/test-files/workflows/workflow-invalid"
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
                $Object -and $Object.StartsWith("Input definition")
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
                $Object -and $Object.StartsWith("Output definition")
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
                $Object -and $Object.StartsWith("Secret definition")
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
                $Object -and $Object.StartsWith("Workflow dispatch input definition")
            }
        }
    }
}
