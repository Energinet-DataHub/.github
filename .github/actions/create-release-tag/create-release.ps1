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

param(
    $Major,
    $Minor,
    $Patch,
    $Repository,
    $Targetbranch,
    $IsDryrun
)
Write-Host "IsDryrun: $IsDryrun"

$semver = "$major.$minor.$patch"
Write-Host "New version tag: $semver"
Write-Host "Major version tag is: v$major"

$currentReleases = gh release list -L 10000 -R $repo | ConvertFrom-Csv -Delimiter "`t" -Header @('title','type','tagname','published')

foreach($release in $currentReleases)
{
    if ($release.title -eq $semver) {
        throw "Error: Cannot create release $semver in $repo as it already exists !"
    }
}

Write-Host 'Tag does not exist, all clear'

if (!$dryrun) {

    Write-Host "Deleting major version tag v$major"
    gh release delete "v$major" -y --cleanup-tag  -R $repo

    Write-Host "Creating new major version tag v$major"
    gh release create "v$major" --title "v$major" --notes "Latest release"  --target $targetBranch -R $repo

    Write-Host "Creating $semver"
    gh release create $semver --generate-notes --latest --title $semver --target $targetBranch -R $repo
}      

Write-Host "All done"