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
$CommitSha = $env:GH_CONTEXT | ConvertFrom-Json | Select-Object -ExpandProperty sha

<#
    .SYNOPSIS
    Class representing a Github Release output using  github CLI (gh)

    .DESCRIPTION
    Simple class modelling the output from a gh release list command into typed.
#>
class GithubRelease {
    [string]$name
    [string]$tagName
    [string]$publishedAt
    [string]$isPrerelease
    [string]$isLatest
    [string]$isDraft
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to retrieves a list of releases

    .DESCRIPTION
    Simple function wrapping a call with gh to retrieve the latest releases from github.
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

    # Create release
    Invoke-GithubReleaseCreate -TagName $TagName -Title $Title -PreRelease $PreRelease -Draft $Draft -Files $Files
}

<#
    .SYNOPSIS
    Uses github CLI (gh) to retrieves a list of releases

    .DESCRIPTION
    Simple function wrapping a call with gh to retrieve the latest releases from github.
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
    Simple function wrapping a call with gh to delete a release from github.
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
    Uses github CLI (gh) to delete a release

    .DESCRIPTION
    Simple function wrapping a call with gh to delete a release from github.
#>
function Invoke-GithubReleaseCreate {
    param(
        [Parameter(Mandatory)]
        [string]$TagName,
        [string]$Title,
        [string[]]$Files,
        [bool]$PreRelease = $false,
        [bool]$Draft = $false
    )

    $cmdbuilder = @(
        "gh release create"
        $TagName,
        "--title $Title"
        "-R $GithubRepository"
        "--generate-notes"
    )

    # gh release create "v$MajorVersion" --title "v$MajorVersion" --notes "Latest release" --target $GitHubBranch -R $GitHubRepository
    if ($PreRelease) {
        $cmdbuilder += "--prerelease"
    }

    $cmdbuilder += $Files

    $cmd = $cmdbuilder -join " "

    Write-Host $cmd
    Invoke-Expression $cmd
}
