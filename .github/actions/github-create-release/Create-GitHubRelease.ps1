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
    Class representing a Github Release

    .DESCRIPTION
    Simple typed object describing a release we want to create via the gh CLI.
#>
class GithubRelease {
    [string]$name
    [string]$tagName
    [bool]$isPrerelease
    [string]$notes
    [string]$files
}

<#
    .SYNOPSIS
    Creates a github release

    .DESCRIPTION
    Creates a github release. If a release already owns the tag, the existing
    release (and its tag) is deleted and creation is retried once.
#>
function Create-GitHubRelease {
    param (
        [Parameter(Mandatory)]
        [string]$TagName,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Files,
        [string]$PreRelease = "false"
    )

    # Input parsing
    $isPrerelease = [bool]::Parse($PreRelease)

    $newrelease = [GithubRelease]@{
        name         = $Title
        tagName      = $TagName
        isPrerelease = $isPrerelease
        notes        = Get-ChangeNotes
        files        = $Files
    }

    try {
        $newrelease | Invoke-GithubReleaseCreate
    }
    catch {
        Write-Host "Release create failed for tag '$TagName' ($_). Deleting existing release and retrying."
        Invoke-GithubReleaseDelete -TagName $TagName
        $newrelease | Invoke-GithubReleaseCreate
    }
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to delete a release by tag

    .DESCRIPTION
    Wrapping a "gh release delete <tag> --cleanup-tag" call
#>
function Invoke-GithubReleaseDelete {
    param(
        [Parameter(Mandatory)]
        [string]$TagName
    )

    Write-Host "Deleting release for tag '$TagName'"
    gh release delete $TagName -y --cleanup-tag -R $GithubRepository
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

    if ($null -eq $release) {
        Write-Warning "No release to create."
        return $release
    }

    Write-Verbose "Creating release: $($release.tagName)"

    $ghArgs = @(
        "release", "create",
        $release.tagName,
        "-t", $release.name,
        "--target", $TargetSha,
        "-R", $GithubRepository
    )

    if ($release.isPrerelease) {
        $ghArgs += "--prerelease"
    }

    if ($release.notes) {
        $release.Notes | Out-File "notes.md"
        $ghArgs += @("--notes-file", "notes.md")
    }
    else {
        $ghArgs += "--generate-notes"
    }

    # Split newline/comma-separated file list into individual file arguments
    foreach ($file in ($release.Files -split '[,\r\n]+')) {
        $trimmed = $file.Trim()
        if ($trimmed) {
            $ghArgs += $trimmed
        }
    }

    Write-Host "gh $($ghArgs -join ' ')"
    & gh @ghArgs
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
