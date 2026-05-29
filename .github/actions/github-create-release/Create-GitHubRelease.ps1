<#
    .SYNOPSIS
    Github Action script creating automated releases

    .DESCRIPTION
    The functionality is executed as an action on a github runner and creates automated releases for pull requests.
#>

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ([string]::IsNullOrEmpty($env:GH_TOKEN)) {
    throw "Error: GH_TOKEN environment variable is not set, see https://cli.github.com/manual/gh_auth_login for details"
}

if ([string]::IsNullOrEmpty($env:GH_CONTEXT)) {
    throw "Error: GH_CONTEXT environment variable is not set. Functionality is depending on github actions context variables."
}

$context = $env:GH_CONTEXT | ConvertFrom-Json

$GithubRepository = $context.repository
$TargetSha = if ($context.event.after) { $context.event.after } else { $context.sha }
$PullRequestNumber = $context.event.number
if ($null -eq $PullRequestNumber) {
    $context.ref_name -match "queue/main/pr-(\d+)"  # Constructs a $Matches variable
    if ($Matches) {
        $PullRequestNumber = $Matches[1]
    }
}

Write-Host "PR number: $PullRequestNumber"
Write-Host "Sha: $TargetSha"
Write-Output "pull_request_number=$PullRequestNumber" >> $env:GITHUB_OUTPUT
Write-Output "sha=$TargetSha" >> $env:GITHUB_OUTPUT

<#
    .SYNOPSIS
    Class representing a Github Release using  github CLI (gh)

    .DESCRIPTION
    Simple class mapping the output from a gh release list json response to a typed object
#>
class GithubRelease {
    [string]$name
    [string]$tagName
    [string]$publishedAt
    [bool]$isPrerelease
    [bool]$isLatest
    [string]$notes
    [string[]]$files
}

<#
    .SYNOPSIS
    Creates a github release

    .DESCRIPTION
    Creates a github release. Makes sure to delete any prior releases with similar tag.
#>
function Create-GitHubRelease {
    param (
        [Parameter(Mandatory)]
        [string]$TagName,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string[]]$Files,
        [bool]$PreRelease
    )

    # Create new release object
    $newrelease = [GithubRelease]@{
        name         = $Title
        tagName      = $TagName
        isPrerelease = $PreRelease
        notes        = Get-ChangeNotes
        files        = $Files
    }

    # Try to create release, if it fails, delete any prior release with same tag and try again - aka do-catch pattern
    # We previously had a test-do pattern, but the test (gh release list) uses graphql and we were hitting rate limits
    # So we switched to do-catch and just try to create the release and if it fails we assume it's because a release with the same tag already exists and delete it before trying again
    try {
        $newrelease | Invoke-GithubReleaseCreate
    }
    catch {
        Invoke-GithubReleaseDelete -Name $TagName
        $newrelease | Invoke-GithubReleaseCreate
    }
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to delete a release

    .DESCRIPTION
    Wrapping a "gh release delete" call
#>
function Invoke-GithubReleaseDelete {
    param(
        [string]$Name
    )

    Write-Host "Deleting $Name"
    gh release delete $Name -y --cleanup-tag -R $GithubRepository
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to create a release

    .DESCRIPTION
    Wrapping a "gh release create" call
#>
function Invoke-GithubReleaseCreate {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [GithubRelease]$release
    )
    Write-Verbose "Creating release: $($release.tagName)"

    $ArgNotes = if ($release.notes) {
        $release.Notes  | Out-File "notes.md"
        "--notes-file notes.md"
    }
    else {
        "--generate-notes"
    }
    $ArgPreRelease = if ($release.isPrerelease) { "--prerelease" } else { "" }
    $cmd = "gh release create $($release.tagName) -t $($release.name) --target ${TargetSha} -R $GithubRepository ${ArgPreRelease} ${ArgNotes} $($release.Files)"
    Write-Host $cmd
    Invoke-Expression $cmd
}

<#
    .SYNOPSIS
    Construct a change note

    .DESCRIPTION
    Creates changes notes for github release
#>
function Get-ChangeNotes {
    $commits = Invoke-GithubPrCommitHistory
    $notes = @("## Commits")
    $commits | ForEach-Object { $notes += "- $($_.sha.Substring(0,8)): $($_.commit.message) ($($_.committer.login))" }

    return $notes -join "`n"
}

<#
    .SYNOPSIS
    Uses github CLI (gh api) to retrieve commit history

    .DESCRIPTION
    Wrapping a "gh api /repos/{repo}/pulls/{pr_number}/commits" call
#>
function Invoke-GithubPrCommitHistory {
    gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "/repos/$GithubRepository/pulls/$PullRequestNumber/commits" | ConvertFrom-Json
}
