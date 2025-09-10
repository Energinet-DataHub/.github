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

Describe "Get-LatestMajorVersion" {

    BeforeAll {
        . $PSScriptRoot/Assert-GithubVersionReferences.ps1

        Mock Invoke-GetGithubReleases {
            return @"
            "title","type","tagname","published"
            "v8","","v8","2023-05-10T12:56:36Z"
            "v1","","v1","2023-05-10T12:56:36Z"
            "v-10","","v-10","2023-05-10T12:56:36Z"
            "50.2.0","Latest","50.2.0","2023-05-10T12:57:40Z"
            "v50","","v50","2023-05-10T12:56:36Z"
            "50.1.0","","50.1.0","2023-05-08T08:31:58Z"
            "50.0.2","","50.0.2","2023-05-01T07:05:42Z"
            "50.0.1","","50.0.1","2023-04-28T11:49:23Z"
            "50.0.0","","50.0.0","2023-04-27T07:39:41Z"
            "v49","Draft","v49","2023-02-16T10:25:41Z"
            "49.2.2","","49.2.2","2023-02-16T10:25:41Z"
            "49.2.1","","49.2.1","2023-02-16T09:54:53Z"
            "49.2.0","","49.2.0","2023-01-26T08:37:05Z"
            "49.1.2","","49.1.2","2023-01-23T09:49:15Z"
            "49.1.1","","49.1.1","2023-01-20T10:09:09Z"
            "49.1.0","","49.1.0","2023-01-19T10:37:38Z"
            "49.0.0","","49.0.0","2023-01-18T07:38:37Z"
"@ | ConvertFrom-Csv
        }
        if ([string]::IsNullOrEmpty($env:GH_TOKEN)) {
            $env:GH_TOKEN = $(gh auth token)
        }
    }

    Context "Given list of releases returned by API" {
        It "It should return the highest major version" {
            Get-LatestMajorVersion -Repository "mock" | Should -Be 50
        }
    }
}

Describe "Assert-GithubVersionReferences" {
    BeforeAll {
        . $PSScriptRoot/Assert-GithubVersionReferences.ps1

        Mock Invoke-GetGithubReleases {
            return @"
            "title","type","tagname","published"
            "50.2.0","Latest","50.2.0","2023-05-10T12:57:40Z"
            "v50","Draft","v50","2023-05-10T12:56:36Z"
            "50.1.0","","50.1.0","2023-05-08T08:31:58Z"
            "50.0.2","","50.0.2","2023-05-01T07:05:42Z"
            "50.0.1","","50.0.1","2023-04-28T11:49:23Z"
            "50.0.0","","50.0.0","2023-04-27T07:39:41Z"
            "49.2.2","","49.2.2","2023-02-16T10:25:41Z"
            "49.2.1","","49.2.1","2023-02-16T09:54:53Z"
            "49.2.0","","49.2.0","2023-01-26T08:37:05Z"
            "49.1.2","","49.1.2","2023-01-23T09:49:15Z"
            "49.1.1","","49.1.1","2023-01-20T10:09:09Z"
            "49.1.0","","49.1.0","2023-01-19T10:37:38Z"
            "49.0.0","","49.0.0","2023-01-18T07:38:37Z"
"@ | ConvertFrom-Csv
        }
        if ([string]::IsNullOrEmpty($env:GH_TOKEN)) {
            $env:GH_TOKEN = $(gh auth token)
        }
    }
    Context "When testing text containing a usage pattern for .github repo" {
        BeforeEach {
            Mock Get-ChildItem {
                return @{"FullName" = "mock" }
            }
            Mock Get-Content {
                return @"
                mock
                    uses: Energinet-DataHub/.github/actions/action@{0}
                Mock
"@ -f "v49"
            }
        }
        It "Throws an exception when version is not supported" {
            { Assert-GithubVersionReferences -Path "Path" -MajorVersionsToKeep 1 } | Should -Throw
            { Assert-GithubVersionReferences -Path "Path" -MajorVersionsToKeep 0 } | Should -Throw
        }
        It "Doesn't throw when version is supported" {
            { Assert-GithubVersionReferences -Path "Path" -MajorVersionsToKeep 2 } | Should -Not -Throw
            { Assert-GithubVersionReferences -Path "Path" -MajorVersionsToKeep 49 } | Should -Not -Throw
        }
    }

    Context "When testing text containing a usage pattern for geh-terraform-modules repo" {
        BeforeEach {
            Mock Get-ChildItem {
                return @("mock")
            }
            Mock Get-Content {
                # Note: In order not to have this test-file introduce false possitives string formatting is used to avoid the regex pattern.
                return @"
                mock
                    source = `"https://github.com/Energinet-DataHub/geh-terraform-modules.git//azure/subpath/module?ref={0}`"
                mock
"@ -f "v49"
            }
        }
        It "Throws an exception when version is not supported" {
            { Assert-GithubVersionReferences -Path "Path" -MajorVersionsToKeep 1 } | Should -Throw
            { Assert-GithubVersionReferences -Path "Path" -MajorVersionsToKeep 0 } | Should -Throw
        }
        It "Doesn't throw when version is supported" {
            { Assert-GithubVersionReferences -Path "Path" -MajorVersionsToKeep 2 } | Should -Not -Throw
            { Assert-GithubVersionReferences -Path "Path" -MajorVersionsToKeep 49 } | Should -Not -Throw
        }
    }
}
