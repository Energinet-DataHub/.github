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

Describe "Assert-GithubVersionReferences" {

    BeforeAll {
        . $PSScriptRoot/Assert-GithubVersionReferences.ps1
    }

    Context "When a pull-request contains deprecated references" {
        BeforeEach {
            Mock Get-ChildItem {
                return @{"FullName" = "mock" }
            }
            Mock Get-Content {
                return @"
                mock
                    uses: Energinet-DataHub/.github/.github/actions/action@{0}
                Mock
"@ -f "v49"
            }
        }
        It "Throws an exception when major version is just too high" {
            Mock Get-LatestMajorVersion {
                return [int]51
            }

            { Assert-DotGithubVersionReferences -Path "mock" -RepositoryPath "mock" } | Should -Throw
        }
        It "Throws an exception when major version is way too high" {
            Mock Get-LatestMajorVersion {
                return [int]100
            }

            { Assert-DotGithubVersionReferences -Path "mock" -RepositoryPath "mock" } | Should -Throw
        }

        It "Doesn't throws when version is current latest" {
            Mock Get-LatestMajorVersion {
                return [int]49
            }

            { Assert-DotGithubVersionReferences -Path "mock" -RepositoryPath "mock" } | Should -Not -Throw
        }

        It "Doesn't throws when version is maintenance mode version" {
            Mock Get-LatestMajorVersion {
                return [int]48
            }
            { Assert-DotGithubVersionReferences -Path "mock" -RepositoryPath "mock" } | Should -Not -Throw
        }
    }
}
