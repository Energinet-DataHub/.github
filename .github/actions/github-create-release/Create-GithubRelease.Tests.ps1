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

    Context "Invoke-GithubReleaseList" {
        It "Returns a release when release exist" -ForEach @(
            @{ Releases = @("v1"); TagName = "v1"; Expected = "v1" },
            @{ Releases = @("v1", "v2"); TagName = "v1"; Expected = "v1" },
            @{ Releases = @("not_v1"); TagName = "v1"; Expected = $null }
        ) {
            ## Mock gh release list
            Mock gh {
                $Releases | ForEach-Object { [GithubRelease]@{ Name = $_ } } | ConvertTo-Json -AsArray
            }
            $previousRelease = Invoke-GithubReleaseList -TagName $TagName
            $previousRelease.Name | Should -Be $Expected
        }
    }

    Context "Invoke-GithubReleaseDelete" {
        It "Deletes a piped release" -ForEach @(
            @{ Release = @{ Name = "noop" }; Expected = 1 },
            @{ Release = $null; Expected = 0 }
        ) {
            Mock gh {}
            Mock Invoke-GithubReleaseList {
                [GithubRelease] $Release
            }

            Invoke-GithubReleaseList | Invoke-GithubReleaseDelete | Should -Invoke -CommandName gh -Exactly -Times $Expected
        }
    }

    Context "Invoke-GithubReleaseCreate" {
        It "Should have <expected> as parameter" -ForEach @(
            @{ Release = @{ name = "xyz" }; Expected = "xyz" }
            @{ Release = @{ name = "xyz" }; Expected = "-t" }
            @{ Release = @{ tagName = "tagxyz" }; Expected = "tagxyz" }
            @{ Release = @{ notes = "" }; Expected = "--generate-notes" }
            @{ Release = @{ isPrerelease = $true }; Expected = "--prerelease" }
            @{ Release = @{ isDraft = $true }; Expected = "--draft" }
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

