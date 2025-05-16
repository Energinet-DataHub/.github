# Safety check: PR_LIST must not be empty or null
if (-not $env:PR_LIST) {
    Write-Warning "No PR_LIST provided. Skipping PR owner check."
    "pr_owner=" >> $env:GITHUB_OUTPUT
    exit 0
}

# Debug: Log raw PR_LIST to help with diagnostics
Write-Host "Raw PR_LIST value:"
Write-Host $env:PR_LIST

$prList = $env:PR_LIST | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $env:GH_TOKEN"
    Accept        = "application/vnd.github+json"
}

$mergedByList = @()

foreach ($pr in $prList) {
    $repo = $pr.repo
    $prNumber = $pr.pr_number
    $releaseName = $pr.release_name

    Write-Host "Checking PR #$prNumber in $repo..."

    try {
        $prInfo = gh pr view $prNumber --repo $repo --json number,mergedBy,url,mergedAt | ConvertFrom-Json

        if ($prInfo.mergedBy -and $prInfo.mergedAt) {
            $mergedByList += [PSCustomObject]@{
                Number       = $prInfo.number
                Owner        = $prInfo.mergedBy.login
                Url          = $prInfo.url
                MergedAt     = [datetime]$prInfo.mergedAt
                ReleaseName  = $releaseName
            }
        } else {
            Write-Warning "PR #$prNumber in $repo is not merged or missing fields"
        }
    } catch {
        Write-Warning "Failed to fetch PR info for $repo/#$prNumber"
    }
}

if ($mergedByList.Count -eq 0) {
    $summary = "No merged PRs found"
} else {
    $sorted = $mergedByList | Sort-Object MergedAt -Descending
    $summary = ($sorted | ForEach-Object {
        "<a href='$($_.Url)'>PR #$($_.Number)</a>: Release name: <b>$($_.ReleaseName)</b><br>By: <b>$($_.Owner)</b> on $($_.MergedAt.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
    }) -join "<br><br>"
}

Write-Host "Merged PR summary:"
Write-Host $summary

"pr_owner=$summary" >> $env:GITHUB_OUTPUT
