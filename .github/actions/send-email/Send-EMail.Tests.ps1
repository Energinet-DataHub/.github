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
        . $PSScriptRoot/Send-EMail.ps1

        Mock Invoke-WebRequest {}
    }

    Context "Given Build-ToEMail is called with a single 'to' email address" {
        It "Should build a minified JSON array with one email address" {
            $teamName = "TheOutlaws"
            $to = "to@test.com"

            $expected = @"
            [
                {
                    "email": "$to",
                    "name": "$teamName"
                }
            ]
"@
            # Minify JSON (must use '-AsArray' when we have only one item)
            $expected = $expected |
                ConvertFrom-Json |
                ConvertTo-Json -Depth 5 -Compress -AsArray

            # Act
            $actual = Build-ToEMail -TeamName $teamName -To $to

            $actual | Should -Be $expected
        }
    }

    Context "Given Build-ToEMail is called with a list of comma-separated 'to' email addresses" {
        It "Should build a minified JSON array with multiple email addresses sharing the team name value" {
            $teamName = "TheOutlaws"
            $to = "one@test.com, two@test.com, three@test.com"

            $expected = @"
            [
                {
                    "email": "one@test.com",
                    "name": "$teamName"
                },
                {
                    "email": "two@test.com",
                    "name": "$teamName"
                },
                {
                    "email": "three@test.com",
                    "name": "$teamName"
                }
            ]
"@
            # Minify JSON
            $expected = $expected |
                ConvertFrom-Json |
                ConvertTo-Json -Depth 5 -Compress

            # Act
            $actual = Build-ToEMail -TeamName $teamName -To $to

            $actual | Should -Be $expected
        }
    }
}
