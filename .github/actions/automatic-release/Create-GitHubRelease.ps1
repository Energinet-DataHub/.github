<#
    .SYNOPSIS
    Github Action script creating automated releases

    .DESCRIPTION
    The functionality is executed as an action on a github runner and creates automated releases for pull requests.
#>

if ([string]::IsNullOrEmpty($env:GH_TOKEN)) {
    throw "Error: GH_TOKEN environment variable is not set, see https://cli.github.com/manual/gh_auth_login for details"
}

if ([string]::IsNullOrEmpty($env:GH_CONTEXT)) {
    throw "Error: GH_CONTEXT environment variable is not set. Functionality is depending on github actions context variables."
}

$GithubRepository = $env:GH_CONTEXT | ConvertFrom-Json | Select-Object -ExpandProperty repository
$PullRequstNumber = $env:GH_CONTEXT | ConvertFrom-Json | Select-Object -ExpandProperty event | Select-Object -ExpandProperty number

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
    [string]$isPrerelease
    [string]$isLatest
    [string]$isDraft
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
        [bool]$PreRelease = $false,
        [bool]$Draft = $false
    )
    # Get Previous Release
    [GithubRelease]$release = Invoke-GithubReleaseList -TagName $TagName

    # Delete Previous Release
    $release | Invoke-GithubReleaseDelete

    # Setup
    $newrelease = [GithubRelease]@{
        name         = $Title
        tagName      = $TagName
        isPrerelease = $PreRelease
        isDraft      = $Draft
        notes        = Get-ChangeNotes
        files        = $Files
    }
    # Create release
    $newrelease | Invoke-GithubReleaseCreate
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to retrieves a list of releases

    .DESCRIPTION
    Wrapping a "gh release list" call
#>
function Invoke-GithubReleaseList {
    param (
        [string]$TagName
    )
    gh release list -L 10000 -R $GithubRepository --json "name,tagName,publishedAt,isPrerelease,isLatest,isDraft" `
    | ConvertFrom-Json
    | Where-Object { $_.name -eq $TagName }
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to delete a release

    .DESCRIPTION
    Wrapping a "gh release delete" call
#>
function Invoke-GithubReleaseDelete {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [GithubRelease]$release
    )

    if ($null -eq $release) {
        Write-Warning "No release to delete."
        return $release
    }

    Write-Host "Deleting $($release.Name)"
    gh release delete $release.Name -y --cleanup-tag -R $GithubRepository
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
        Write-Warning "No release to delete."
        return $release
    }

    $ArgNotes = if ($release.notes) { "-n `"$($release.notes)`"" } else { "--generate-notes" }
    $ArgPreRelease = if ($release.isPrerelease) { "--prerelease" } else { "" }
    $ArgDraft = if ($release.isDraft) { "--draft" } else { "" }

    $cmd = "gh release create $($release.tagName) -t $($release.name) -R $GithubRepository ${ArgPreRelease} ${ArgDraft} ${ArgNotes} ${release.Files}"
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
    gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "/repos/$GithubRepository/pulls/$PullRequstNumber/commits" | ConvertFrom-Json
}
