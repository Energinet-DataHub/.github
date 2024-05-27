BeforeAll {
    $env:GH_TOKEN = "test"
    $context = Get-Content $PSScriptRoot/blabla.json | Out-String
    . $PSScriptRoot/Create-GithubRelease.ps1 -GithubContext $context
}

Describe "Create-AutomaticGitHubRelease" -ForEach @(
    @{ Releases = @("v1"); TagName = "v1"; Expected = "v1" },
    @{ Releases = @("v1", "v2"); TagName = "v1"; Expected = "v1" },
    @{ Releases = @("not_v1"); TagName = "v1"; Expected = $null }
) {

    BeforeEach {
        ## Mock gh release list
        Mock -CommandName gh `
            -ParameterFilter { $args[0] -eq "release" -and $args[1] -eq "list" } `
            -MockWith {
            Write-Warning "Mocked gh release list ..."
            $Releases | ForEach-Object { [GithubRelease]@{ Name = $_ } } | ConvertTo-Json -AsArray
        }

        ## Mock gh release delete
        Mock -CommandName gh `
            -ParameterFilter { $args[0] -eq 'release' -and $args[1] -eq "delete" } `
            -MockWith {
            Write-Warning "Mocked gh release delete ..."
            $true
        }

        ## Mock gh release create
        Mock -CommandName gh `
            -ParameterFilter { $args[0] -eq 'release' -and $args[1] -eq "create" } `
            -MockWith {
            Write-Warning "Mocked gh release create ..."
            $true
        }
    }
    It "Returns <expected> when searching for <TagName>" {
        $previousRelease = Invoke-GithubReleaseList -TagName $TagName
        $previousRelease.Name | Should -Be $expected
    }

    It "Deletes <expected> when provided <TagName>" {
        $previousRelease = Invoke-GithubReleaseList -TagName $TagName
        $previousRelease | Invoke-GithubReleaseDelete
        if ($Expected) {
            Should -Invoke -CommandName "gh" -Exactly -Times 2
        }
        else {
            Should -Invoke -CommandName "gh" -Exactly -Times 1
        }
    }

    It "Creates <expected> when provided <tagname>" {
        Invoke-GithubReleaseCreate -TagName $TagName -Title "title" -PreRelease $true -Draft $false -Files $Files

        Should -Invoke -CommandName "gh" -Exactly -Times 1

    }
}

