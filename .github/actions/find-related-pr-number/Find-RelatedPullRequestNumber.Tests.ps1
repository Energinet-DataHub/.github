Describe "Find-RelatedPullRequestNumber" {
    BeforeAll {
        . $PSScriptRoot/Find-RelatedPullRequestNumber.ps1
        $script:GithubToken = 'foobar'
        $script:Repository = 'myrepo'
    }

    Context 'on pull_request event' {
        It 'should return PR number' {
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
    }

    Context 'on merge_group event' {
        Mock Invoke-GithubGetPullRequestFromSha { return '{ "title": "some PR title"}' | ConvertFrom-Json }

        It 'should return PR number' {

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

    Context 'on push event with valid commit message' {
        It 'should return PR number' {
            Mock Invoke-GithubGetPullRequestFromSha { return '{ "title": "some PR title"}' | ConvertFrom-Json }

            # Gets PR-number from commit message
            Find-RelatedPullRequestNumber `
                -GithubToken $script:GithubToken `
                -GithubEvent 'push' `
                -Sha '1a2b3df4' `
                -GithubRepository $script:Repository `
                -RefName 'main' `
                -CommitMessage 'Merge PR to main (#4711)' `
            | Should -Be '4711'

        }
    }

    Context 'on push event with invalid commit message' {
        It 'should not throw error' {
            Mock Invoke-GithubGetPullRequestFromSha { return '{ "title": "some PR title"}' | ConvertFrom-Json }

            Find-RelatedPullRequestNumber `
                -GithubToken $script:GithubToken `
                -GithubEvent 'push' `
                -Sha '1a2b3df4' `
                -GithubRepository $script:Repository `
                -RefName 'main' `
                -CommitMessage 'Merge PR to main' `
            | Should -Be $null
        }
    }

    Context 'on push event with commit message containing hyphens' {
        It 'should not throw error' {
            Mock Invoke-GithubGetPullRequestFromSha { return '{ "title": "some PR title"}' | ConvertFrom-Json }

            Find-RelatedPullRequestNumber `
                -GithubToken $script:GithubToken `
                -GithubEvent 'push' `
                -Sha '1a2b3df4' `
                -GithubRepository $script:Repository `
                -RefName 'main' `
                -CommitMessage 'Revert "2453: remove deprecated instrumentation key from shared (#2759)" (#2763)' `
            | Should -Be 2763
        }
    }
}
