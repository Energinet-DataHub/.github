# BeforeAll {


#     ## Mock gh release delete
#     Mock -CommandName gh `
#         -ParameterFilter { $args[0] -eq 'release' -and $args[1] -eq "delete" } `
#         -MockWith {
#         Write-Warning "Mocked gh release delete ..."
#         $true
#     }

#     ## Mock gh release create
#     Mock -CommandName gh `
#         -ParameterFilter { $args[0] -eq 'release' -and $args[1] -eq "create" } `
#         -MockWith {
#         Write-Warning "Mocked gh release create ..."
#         $true
#     }
# }

Describe "Create-GithubRelease" {

    BeforeEach {
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
        . $PSScriptRoot/Create-GithubRelease.ps1
    }

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

    }
}
# Describe "Create-AutomaticGitHubRelease" {

#     BeforeEach {

#     }
#     It "Returns <expected> when searching for <TagName>" {
#         $previousRelease = Invoke-GithubReleaseList -TagName $TagName
#         $previousRelease.Name | Should -Be $expected
#     }

#     It "Deletes <expected> when provided <TagName>" {
#         $previousRelease = Invoke-GithubReleaseList -TagName $TagName
#         $previousRelease | Invoke-GithubReleaseDelete
#         if ($Expected) {
#             Should -Invoke -CommandName "gh" -Exactly -Times 2
#         }
#         else {
#             Should -Invoke -CommandName "gh" -Exactly -Times 1
#         }
#     }

#     It "Creates <expected> when provided <tagname>" {
#         Invoke-GithubReleaseCreate -TagName $TagName -Title "title" -PreRelease $true -Draft $false -Files $Files

#         Should -Invoke -CommandName "gh" -Exactly -Times 1

#     }
# }

