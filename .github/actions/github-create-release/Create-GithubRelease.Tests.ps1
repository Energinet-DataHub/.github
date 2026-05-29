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

    Context "Create release" {
        It "Handles preexisting = <PreExists> release" -ForEach @(
            #@{ PreExists = $false; TagName = "v1" },
            @{ PreExists = $true; TagName = "v1" }
        ) {

            Mock gh {
            }

            Mock Get-ChangeNotes {
                return ""
            }

            $script:deleted = $false

            Mock Invoke-GithubReleaseCreate {
                [GithubRelease] $Release

                if ($PreExists -and -not $script:deleted) {
                    throw "Release with tag $($Release.tagName) already exists"
                }

                return $Release
            }

            Mock Invoke-GithubReleaseDelete {
                [string] $Name

                $script:deleted = $true
            }

            Create-GitHubRelease -TagName $TagName -Title "title" -Files @("file1") -PreRelease $false

            Should -Invoke -CommandName Invoke-GithubReleaseCreate -Exactly ($PreExists ? 2 : 1)

            Should -Invoke -CommandName Invoke-GithubReleaseDelete -Exactly ($PreExists ? 1 : 0)

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
