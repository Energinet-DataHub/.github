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

        [Parameter(Mandatory)]
        [string]
        $CommitMessage
    )

    # Set Headers
    $headers = @{
        "Authorization" = "Bearer $GithubToken"
        "Content-Type"  = "application/json"
        "User-Agent"    = "powershell/find-related-pr-number"
    }

    $prNumber = $null
    switch ($GithubEvent) {
        "pull_request" {
            # Get PR from API as this is prior to merge
            $prUrl = "https://api.github.com/repos/$GithubRepository/commits/$Sha/pulls"
            $prData = Invoke-RestMethod -Uri $prUrl -Headers $headers -Method Get -Body ConvertTo-Json

            if ($prData.number) {
                # Extract Pull Request Numbers
                $prNumber = $prData.number[0]
            }
        }

        "merge_group" {
            # Get PR from branch name as the SHA is a merge commit from the temporary merge queue branch
            $hasMatch = $RefName -match "queue/main/pr-(\d+)"  # Constructs a $Matches variable
            if ($hasMatch) {
                Write-Host $Matches
                $prNumber = $Matches[1]
            }
        }

        "push" {
            # After push to main
            $hasMatch = $CommitMessage -match "#\s*(\d+)"  # Example commit message: 'Create .gitignore in repository (#15)'
            if ($hasMatch) {
                Write-Host $Matches
                $prNumber = $Matches[1]
            }
        }
    }

    if ($null -eq $prNumber) {
        throw "No pull requests found for sha: $Sha"
    }

    return $prNumber
}
