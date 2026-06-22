BeforeAll {
    $env:GH_TOKEN = "test"
    $env:GH_CONTEXT = @"
        {
            "sha": "7fc6c8ad63a35313621bade00ddd2e91f756e093",
            "repository": "owner/reponame",
            "event": {
                "number": "1234"
            }
        }
"@
    . $PSScriptRoot/Create-GitHubRelease.ps1
}

Describe "Create-GithubRelease" {

    Context "Invoke-GithubReleaseDelete" {
        It "Calls gh release delete with tag '<TagName>'" -ForEach @(
            @{ TagName = "v1"; Expected = 1 },
            @{ TagName = "subsystem_1234"; Expected = 1 }
        ) {
            Mock gh {}
            Invoke-GithubReleaseDelete -TagName $TagName
            Should -Invoke -CommandName gh -Exactly -Times $Expected -ParameterFilter {
                ($args -contains "delete") -and ($args -contains $TagName) -and ($args -contains "--cleanup-tag")
            }
        }
    }

    Context "Create-GitHubRelease" {
        It "Calls gh create <ExpectedCreate>x and delete <ExpectedDelete>x when first create <Scenario>" -ForEach @(
            @{ Scenario = "succeeds"; FirstCreateFails = $false; ExpectedCreate = 1; ExpectedDelete = 0 },
            @{ Scenario = "fails"; FirstCreateFails = $true; ExpectedCreate = 2; ExpectedDelete = 1 }
        ) {
            $script:createCalls = 0
            $script:failFirstCreate = $FirstCreateFails
            Mock gh {
                if ($args -contains "create") {
                    $script:createCalls++
                    if ($script:failFirstCreate -and $script:createCalls -eq 1) { throw "tag already exists" }
                }
            }

            Create-GitHubRelease -TagName "v1" -Title "v1" -Files "asset.zip"

            Should -Invoke -CommandName gh -Exactly -Times $ExpectedCreate -ParameterFilter { $args -contains "create" }
            Should -Invoke -CommandName gh -Exactly -Times $ExpectedDelete -ParameterFilter { $args -contains "delete" }
        }
    }

    Context "Invoke-GithubReleaseCreate" {
        It "Should have <expected> as parameter" -ForEach @(
            @{ Release = @{ name = "xyz" }; Expected = "xyz" }
            @{ Release = @{ name = "xyz" }; Expected = "-t" }
            @{ Release = @{ tagName = "tagxyz" }; Expected = "tagxyz" }
            @{ Release = @{ notes = "" }; Expected = "--generate-notes" }
            @{ Release = @{ isPrerelease = $true }; Expected = "--prerelease" }
            @{ Release = @{ notes = "notes" }; Expected = "--notes-file" }
        ) {
            Mock gh {}
            $rel = [GithubRelease]$Release
            $rel | Invoke-GithubReleaseCreate
            Should -Invoke -CommandName gh -Exactly 1 -ParameterFilter {
                $args -contains $Expected
            }
        }
    }
}

