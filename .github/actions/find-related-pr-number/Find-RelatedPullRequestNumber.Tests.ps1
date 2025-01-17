Describe "Find-RelatedPullRequestNumber" {
    BeforeAll {
        . $PSScriptRoot/Find-RelatedPullRequestNumber.ps1
        $script:GithubToken = 'foobar'
        $script:Repository = 'myrepo'
    }

    Context 'unknown event' {
        It 'should warn if event could not be recognized' {
            Mock Invoke-GithubGetPullRequestFromSha { return $null }
            Mock Write-Host { }
            # Looks up PR-number in Github API
            $obj = Find-RelatedPullRequestNumber `
                -GithubToken $script:GithubToken `
                -GithubEvent 'unknown_event' `
                -Sha 'ab34bed2' `
                -GithubRepository $script:Repository `
                -RefName '/my/refname' `
                -CommitMessage 'Fancy commit message'
            $obj | Should -Be $null
            Should -Invoke -CommandName Write-Host -ParameterFilter { $Object -eq '::warning::Unknown event: unknown_event, unable to look up PR' }
        }
    }

    Context 'scheduled event' {
        It 'should throw error when Sha return null' {
            Mock Invoke-GithubGetPullRequestFromSha { return $null }

            # Looks up PR-number in Github API
            { Find-RelatedPullRequestNumber `
                    -GithubToken $script:GithubToken `
                    -GithubEvent 'schedule' `
                    -Sha 'ab34bed2' `
                    -GithubRepository $script:Repository `
                    -RefName '/my/refname' `
                    -CommitMessage 'Fancy commit message'
            } | Should -Throw -ExpectedMessage "No pull requests found for sha: ab34bed2"
        }
    }


    Context 'pull_request event' {
        It 'should return PR number when SHA returns PR' {
            Mock Invoke-GithubGetPullRequestFromSha { return '{ "title": "some PR title", "number": "4711" }' | ConvertFrom-Json }

            # Looks up PR-number in Github API
            Find-RelatedPullRequestNumber `
                -GithubToken $script:GithubToken `
                -GithubEvent 'pull_request' `
                -Sha 'ab34bed2' `
                -GithubRepository $script:Repository `
                -RefName '/my/refname' `
                -CommitMessage 'Fancy commit message' `
            | Should -Be '4711'
        }


        It 'should throw error when SHA returns null' {
            Mock Invoke-GithubGetPullRequestFromSha { return $null }

            # Looks up PR-number in Github API
            { Find-RelatedPullRequestNumber `
                    -GithubToken $script:GithubToken `
                    -GithubEvent 'pull_request' `
                    -Sha 'ab34bed2' `
                    -GithubRepository $script:Repository `
                    -RefName '/my/refname' `
                    -CommitMessage 'Fancy commit message' } | Should -Throw -ExpectedMessage "No pull requests found for sha: ab34bed2"
        }
    }
    Context 'merge_group event' {
        It 'should return PR number from branch name when Github context does not contain PR number' {
            Mock Invoke-GithubGetPullRequestFromSha { return '{ "title": "some PR title"}' | ConvertFrom-Json }
            # Gets PR-number from refname
            Find-RelatedPullRequestNumber `
                -GithubToken $script:GithubToken `
                -GithubEvent 'merge_group' `
                -Sha 'ab34bed2' `
                -GithubRepository $script:Repository `
                -RefName 'refs/heads/gh-readonly-queue/main/pr-4711-ab34bed2' `
                -CommitMessage 'Fancy commit message' `
            | Should -Be '4711'
        }
    }
    Context 'push event' {
        It 'should return PR number when SHA returns PR' {
            Mock Invoke-GithubGetPullRequestFromSha { return '{ "title": "some PR title", "number": "4711" }' | ConvertFrom-Json }

            # Looks up PR-number in Github API
            Find-RelatedPullRequestNumber `
                -GithubToken $script:GithubToken `
                -GithubEvent 'push' `
                -Sha 'ab34bed2' `
                -GithubRepository $script:Repository `
                -RefName '/my/refname' `
                -CommitMessage 'Fancy commit message' `
            | Should -Be '4711'
        }

        It 'should return PR number on push event with valid commit message when SHA returns null' -ForEach @(
            @{ CommitMessage = "Merge PR to main (#4711)"; Expected = '4711' }
            @{ CommitMessage = "Merge PR to main"; Expected = $null }
            @{ CommitMessage = 'Revert "2453: remove deprecated instrumentation key from shared (#2759)" (#2763)'; Expected = '2763' }
            @{ CommitMessage = "Feat: Add new silver schema (#100) $([System.Environment]::NewLine) Co-authored-by: root <root@TEK-8130.localdomain>"; Expected = '100'
            }
        ) {
            Mock Invoke-GithubGetPullRequestFromSha { return $null }

            # Gets PR-number from commit message
            Find-RelatedPullRequestNumber `
                -GithubToken $script:GithubToken `
                -GithubEvent 'push' `
                -Sha '1a2b3df4' `
                -GithubRepository $script:Repository `
                -RefName 'main' `
                -CommitMessage $CommitMessage `
            | Should -Be $Expected
        }
    }
}
