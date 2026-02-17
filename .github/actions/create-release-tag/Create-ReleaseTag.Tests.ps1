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

Describe "Create-ReleaseTag" {
    BeforeAll {
        . $PSScriptRoot/Create-ReleaseTag.ps1

        $env:GH_TOKEN = "mock"
        Mock gh { }
        Mock Get-GithubReleases {
            return @"
                "title","type","tagname","published"
                "actions/v11.2.0","Latest","actions/v11.2.0","2023-05-10T12:57:40Z"
                "actions/v11","Draft","actions/v11","2023-05-10T12:56:36Z"
                "actions/v11.1.0","","actions/v11.1.0","2023-05-08T08:31:58Z"
                "actions/v11.0.2","","actions/v11.0.2","2023-05-01T07:05:42Z"
                "actions/v11.0.1","","actions/v11.0.1","2023-04-28T11:49:23Z"
                "actions/v11.0.0","","actions/v11.0.0","2023-04-27T07:39:41Z"
                "actions/v10.2.2","","actions/v10.2.2","2023-02-16T10:25:41Z"
                "actions/v10.2.1","","actions/v10.2.1","2023-02-16T09:54:53Z"
                "actions/v10.2.0","","actions/v10.2.0","2023-01-26T08:37:05Z"
                "actions/v10.1.2","","actions/v10.1.2","2023-01-23T09:49:15Z"
                "actions/v10.1.1","","actions/v10.1.1","2023-01-20T10:09:09Z"
                "actions/v10.1.0","","actions/v10.1.0","2023-01-19T10:37:38Z"
                "actions/v10.0.0","","actions/v10.0.0","2023-01-18T07:38:37Z"
"@ | ConvertFrom-Csv
        }
    }

    Context "When two version numbers are compared with Compare-Versions" {
        It "Returns 0 when version numbers are equivelent" {
            Compare-Versions "1" "1" | Should -Be 0
            Compare-Versions "10" "10" | Should -Be 0
            Compare-Versions "10.0" "10" | Should -Be 0
            Compare-Versions "10" "10.0.0" | Should -Be 0
            Compare-Versions "3.4.5" "3.4.5" | Should -Be 0
        }

        It "Returns -1 when version is smaller" {
            Compare-Versions "1" "2" | Should -Be -1
            Compare-Versions "1.2.3" "1.2.4" | Should -Be -1
            Compare-Versions "1" "1.2.3" | Should -Be -1
            Compare-Versions "1.2" "1.2.4" | Should -Be -1
        }

        It "Returns 1 when version is bigger" {
            Compare-Versions "2" "1" | Should -Be 1
            Compare-Versions "2.0" "1.9.9" | Should -Be 1
            Compare-Versions "1.3.2" "1.2.3" | Should -Be 1
            Compare-Versions "1.2.3.1" "1.2.3" | Should -Be 1
        }
    }

    Context "When a searching for conflicting version numbers" {
        It "It returns a collection of conflicting versions." {

            $releases = (Get-GithubReleases "mock" -Prefix "actions").title | ForEach-Object { $_ -replace "^actions/v", "" }

            (Find-ConflictingVersions "11" $releases).Count | Should -BeGreaterThan 0
            (Find-ConflictingVersions "10" $releases).Count | Should -BeGreaterThan 0
            (Find-ConflictingVersions "12" $releases).Count | Should -Be 0
            (Find-ConflictingVersions "11.2.0" $releases).Count | Should -Be 1
            (Find-ConflictingVersions "11.2.1" $releases).Count | Should -Be 0
            (Find-ConflictingVersions "11" $releases).Count | Should -Be 6
        }
    }
    Context "When updating major version" {
        It "Calls gh with correct version and completes successfully" {
            Update-VersionTags -Version "1" -GitHubRepository "mock" -GitHubBranch "mock" -Prefix "actions" |
            Should -Invoke -CommandName "gh" -Exactly -Times 3 -ParameterFilter { $args[0] -eq 'release' -and ($args[2] -eq 'actions/v1' -or $args[2] -eq 'actions/v1') }

            Update-VersionTags -Version "2.0.0" -GitHubRepository "mock" -GitHubBranch "mock" -Prefix "actions" |
            Should -Invoke -CommandName "gh" -Exactly -Times 3 -ParameterFilter { $args[0] -eq 'release' -and ($args[2] -eq 'actions/v2' -or $args[2] -eq 'actions/v2.0.0') }

            Update-VersionTags -Version "3.2.1" -GitHubRepository "mock" -GitHubBranch "mock" -Prefix "actions" |
            Should -Invoke -CommandName "gh" -Exactly -Times 3 -ParameterFilter { $args[0] -eq 'release' -and ($args[2] -eq 'actions/v3' -or $args[2] -eq 'actions/v3.2.1') }

        }

        It "Throws an exception if no version or invalid version is provided" {
            $EmptyVersion = ""
            { Update-VersionTags -Version $EmptyVersion -GitHubRepository "mock" -GitHubBranch "mock" -Prefix "actions" } | Should -Throw
            $InvalidVersion = "abc"
            { Update-VersionTags -Version $InvalidVersion -GitHubRepository "mock" -GitHubBranch "mock" -Prefix "actions" } | Should -Throw
        }

        It "Throws an exception if no prefix is provided" {
            { Update-VersionTags -Version "1.0.0" -GitHubRepository "mock" -GitHubBranch "mock" } | Should -Throw
        }
    }

    Context "When merging a new version" {
        It "Throws an exception when later version exists" {

            { Create-ReleaseTag -MajorVersion "11" `
                    -MinorVersion "1" `
                    -PatchVersion "2" `
                    -GitHubRepository "mock" `
                    -GitHubBranch "mock" `
                    -GitHubEvent "mock" `
                    -Prefix "actions" } | Should -Throw
        }
        It "Completes successfully when version is higher" {
            Create-ReleaseTag -MajorVersion "11" `
                -MinorVersion "2" `
                -PatchVersion "1" `
                -GitHubRepository "mock" `
                -GitHubBranch "mock" `
                -GitHubEvent "mock" `
                -Prefix "actions"

            Create-ReleaseTag -MajorVersion "12" `
                -MinorVersion "0" `
                -PatchVersion "0" `
                -GitHubRepository "mock" `
                -GitHubBranch "mock" `
                -GitHubEvent "mock" `
                -Prefix "actions"
        }
        It "Throws an exception if no prefix is provided" {
            { Create-ReleaseTag -MajorVersion "12" `
                    -MinorVersion "0" `
                    -PatchVersion "0" `
                    -GitHubRepository "mock" `
                    -GitHubBranch "mock" `
                    -GitHubEvent "mock" } | Should -Throw
        }
    }
}
