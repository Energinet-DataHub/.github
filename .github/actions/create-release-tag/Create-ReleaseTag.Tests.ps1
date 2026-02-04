Describe "Create-ReleaseTag" {
    BeforeAll {
        . $PSScriptRoot/Create-ReleaseTag.ps1

        $env:GH_TOKEN = "mock"
        Mock gh { }
        Mock Get-GithubReleases {
            return @(
                "ModuleName_11.2.0",
                "ModuleName_11.1.0",
                "ModuleName_11.0.2",
                "ModuleName_11.0.1",
                "ModuleName_11.0.0",
                "ModuleName_10.2.2",
                "ModuleName_10.2.1",
                "ModuleName_10.2.0",
                "ModuleName_10.1.2",
                "ModuleName_10.1.1",
                "ModuleName_10.1.0",
                "ModuleName_10.0.0"
            )
        }
    }

    Context "When two version numbers are compared with Compare-Versions" {
        It "Returns 0 when version numbers are equivalent" {
            Compare-Versions "ModuleName_3.4.5" "ModuleName_3.4.5" | Should -Be 0
        }

        It "Returns -1 when version is smaller" {
            Compare-Versions "ModuleName_1.2.3" "ModuleName_1.2.4" | Should -Be -1
        }

        It "Returns 1 when version is bigger" {
            Compare-Versions "ModuleName_1.3.2" "ModuleName_1.2.3" | Should -Be 1
        }
    }

    Context "When searching for conflicting version numbers" {
        It "Returns a collection of conflicting versions." {
            $releases = Get-GithubReleases "mock" "ModuleName"

            (Find-ConflictingVersions "ModuleName_11.2.0" $releases).Count | Should -Be 1
            (Find-ConflictingVersions "ModuleName_11.2.1" $releases).Count | Should -Be 0
        }
    }

    Context "When merging a new version" {
        It "Throws an exception when later version exists" {
            { Create-ReleaseTag -ModuleName "ModuleName" `
                    -MajorVersion "11" `
                    -MinorVersion "1" `
                    -PatchVersion "2" `
                    -GitHubRepository "mock" `
                    -GitHubBranch "mock" `
                    -GitHubEvent "mock" } | Should -Throw
        }

        It "Completes successfully when version is higher" {
            Create-ReleaseTag -ModuleName "ModuleName" `
                -MajorVersion "11" `
                -MinorVersion "2" `
                -PatchVersion "1" `
                -GitHubRepository "mock" `
                -GitHubBranch "mock" `
                -GitHubEvent "mock"

            Create-ReleaseTag -ModuleName "ModuleName" `
                -MajorVersion "12" `
                -MinorVersion "0" `
                -PatchVersion "0" `
                -GitHubRepository "mock" `
                -GitHubBranch "mock" `
                -GitHubEvent "mock"
        }
    }

    Context "Regular expressions" {
        It "Correctly finds version for geh-terraform-modules" {
            $pattern = "Energinet-DataHub/geh-terraform-modules\.git//(.*?)\?ref=v?(?<version>\d+)"

            $tests = @(
                @{"input" = "source = `"git::http://github.com/Energinet-DataHub/geh-terraform-modules.git//azure/module.tf?ref=v{0}`""; "expected" = "1" },
                @{"input" = "source = `"git::http://github.com/Energinet-DataHub/geh-terraform-modules.git//azure/module.tf?ref=v{0}`""; "expected" = "2" },
                @{"input" = "source = `"git::http://github.com/Energinet-DataHub/geh-terraform-modules.git//azure/module.tf?ref=v{0}`"  "; "expected" = "1" },
                @{"input" = "source = `"git::http://github.com/Energinet-DataHub/geh-terraform-modules.git//azure/module.tf?ref=v{0}`""; "expected" = "20" },
                @{"input" = "source = `"git::http://github.com/Energinet-DataHub/geh-terraform-modules.git//azure/module.tf?ref={0}.2.3`""; "expected" = "1" },
                @{"input" = "source = `"git::http://github.com/Energinet-DataHub/geh-terraform-modules.git//azure/module.tf?ref={0}.2.1`""; "expected" = "3" }
            )
            $tests | ForEach-Object {
                $testString = $_.input -f $_.expected
                $match = [regex]::Match($testString, $pattern)
                $match.Success | Should -Be $true
                $match.Groups["version"] | Should -Be $_.expected
            }
        }
    }
}
