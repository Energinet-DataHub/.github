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
    }
}
