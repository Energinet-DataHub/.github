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

Describe "FindRelatedPullRequestNumber" {
    BeforeAll {
        . $PSScriptRoot/Find-RelatedPullRequestNumber.ps1

        $githubToken = "GITHUB_TOKEN"
        $sha = "COMMIT_SHA"
        $githubRepository = "OWNER/REPO_NAME"
    }

    Context "Valid input" {
        BeforeAll {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{
                        number = 123
                    },
                    [PSCustomObject]@{
                        number = 456
                    }
                )
            } -ModuleName 'Microsoft.PowerShell.Utility'
        }

        It "Returns the first associated pull request number" {
            $result = Find-RelatedPullRequestNumber -GithubToken $githubToken -Sha $sha -GithubRepository $githubRepository
            $result | Should -Be 123
        }
    }

    Context "No pull requests found" {
        BeforeAll {
            # Return an empty response
            Mock Invoke-RestMethod {
                return @()
            } -ModuleName 'Microsoft.PowerShell.Utility'
        }

        It "Throws an error and exits with code 1" {
            { Find-RelatedPullRequestNumber
                -GithubToken $githubToken
                -Sha $sha
                -GithubRepository $githubRepository
            } | Should -Throw
        }
    }

    Context "Invalid input" {
        It "Throws an error and exits with code 1" {
            { Find-RelatedPullRequestNumber
                -GithubToken $null
                -Sha $sha
                -GithubRepository $githubRepository
            } | Should -Throw
        }
    }
}
