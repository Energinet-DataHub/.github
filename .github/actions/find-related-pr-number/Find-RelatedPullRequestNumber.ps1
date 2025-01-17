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

<#
    .SYNOPSIS
    Find the related pull request numbers for a given base branch and related branch.

    .DESCRIPTION
    This function uses the GitHub API to find the open pull request numbers for a given base branch.
    If merge queues is enabled on repository, we will attempt to deduct the PR-number from other sources of information
    such as branch name or commit message
#>
function Find-RelatedPullRequestNumber {
    param (
        [Parameter(Mandatory)]
        [string]
        $GithubToken,

        [Parameter(Mandatory)]
        [string]
        $GithubEvent,

        [Parameter(Mandatory)]
        [string]
        $Sha,

        [Parameter(Mandatory)]
        [string]
        $GithubRepository,

        [Parameter(Mandatory)]
        [string]
        $RefName,

        # Empty when creating PR. It's relevant on push to main only
        [string]
        $CommitMessage
    )

    $prNumber = $null
    switch ($GithubEvent) {
        "schedule" {
            # To be implemented in https://app.zenhub.com/workspaces/the-outlaws-6193fe815d79fc0011e741b1/issues/gh/energinet-datahub/team-the-outlaws/2770

            # If $refname is main, look up PR number using SHA
            # If PR-number is not found, throw error
            # This will fail scheduled workflows with merge queues enabled.
            # And that is OK, product team must refactor workflows in CI to
            # avoid looking up PR numbers in a merge-queue-enabled context
        }
        "pull_request" {
            $prData = Invoke-GithubGetPullRequestFromSha -GithubRepository $GithubRepository -Sha $Sha -GithubToken $GithubToken
            if ($prData.number) {
                $prNumber = $prData.number
            }

            if ($null -eq $prNumber) {
                throw "No pull requests found for sha: $Sha"
            }
        }

        "merge_group" {
            # Get PR from branch name as the SHA is a merge commit from the temporary merge queue branch
            $hasMatch = $RefName -match "queue/main/pr-(\d+)"  # Constructs a $Matches variable
            if ($hasMatch) {
                Write-Host $Matches
                $prNumber = $Matches[1]
            }

            if ($null -eq $prNumber) {
                throw "No pull request number found for ref_name: $RefName"
            }
        }

        "push" {
            # After push to main
            $prData = Invoke-GithubGetPullRequestFromSha -GithubRepository $GithubRepository -Sha $Sha -GithubToken $GithubToken
            if ($prData.number) {
                $prNumber = $prData.number
            }
            else {
                # Latest commit on push does not refer to a PR. We will attempt to deduct the PR using the commit message.
                # At this point, this is a best effort exercise. You should as a developer in general not rely on looking up PR number
                # when working on main as you cannot be 100% sure you can always backtrack your commit to a PR when working on main

                # See examples of commit messages in Pester tests'
                $hasMatch = $CommitMessage -match "\(#(\d+)\)(?!.*\(#\d+\))"
                if ($hasMatch) {
                    Write-Host $Matches
                    $prNumber = $Matches[1]
                }

                if ($null -eq $prNumber) {
                    # If no PR was found, we don't want to fail your workflow, as this will cause i.e. CD dispatch events to fail hard
                    # i.e. when merge queue is enabled on your repository
                    Write-Host "::warning::No pull request number found for commit message '$CommitMessage'"
                }
            }
        }
        default {
            Write-Host "::warning::Unknown event: $GithubEvent, unable to look up PR"
        }
    }
    return $prNumber
}




function Invoke-GithubGetPullRequestFromSha {
    param(
        [Parameter(Mandatory)]
        [string]
        $GithubRepository,

        [Parameter(Mandatory)]
        [string]
        $Sha,

        [Parameter(Mandatory)]
        [string]
        $GithubToken
    )

    $headers = @{
        "Authorization" = "Bearer $GithubToken"
        "Content-Type"  = "application/json"
        "User-Agent"    = "powershell/find-related-pr-number"
    }

    $prUrl = "https://api.github.com/repos/$GithubRepository/commits/$Sha/pulls"

    $prData = Invoke-WebRequest -Uri $prUrl -Headers $headers
    return ($prData.Content | ConvertFrom-Json -Depth 10)
}
