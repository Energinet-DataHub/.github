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
        $owner = $prInfo.mergedBy.login
        $url = $prInfo.url
        $utcDate = [datetime]$prInfo.mergedAt
        $localDate = $utcDate.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")

        if ($owner) {
            $mergedByList += "<a href='$url'>PR #$($prInfo.number)</a>: Release name: <b>$releaseName</b><br>By: <b>$owner</b> on $localDate"
        } else {
            Write-Warning "PR #$prNumber in $repo is not merged or missing 'mergedBy'"
        }
    } catch {
        Write-Warning "Failed to fetch PR info for $repo/#$prNumber"
    }
}

if ($mergedByList.Count -eq 0) {
    $summary = "No merged PRs found"
} else {
    $summary = $mergedByList -join "<br><br>"
}

Write-Host "Merged PR summary:"
Write-Host $summary

"pr_owner=$summary" >> $env:GITHUB_OUTPUT
