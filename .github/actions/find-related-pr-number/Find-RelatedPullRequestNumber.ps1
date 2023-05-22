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
        $Sha,

        [Parameter(Mandatory)]
        [string]
        $GithubRepository
    )

    # Set Headers
    $headers = @{
        "Authorization" = "Bearer $GithubToken"
        "Content-Type"  = "application/json"
        "User-Agent"    = "powershell/find-related-pr-number"
    }

    # Get Pull Requests
    $prUrl = "https://api.github.com/repos/$GithubRepository/commits/$Sha/pulls"
    $prData = Invoke-RestMethod -Uri $prUrl -Headers $headers -Method Get -Body ConvertTo-Json

    # Extract Pull Request Numbers
    $prNumbers = $prData.number

    if ($prNumbers) {
        return $prNumbers[0]
    }
    else {
        throw "No pull requests found for sha: $Sha."
    }

    return $prNumbers
}
