# .github

This repository contains shared github items such as actions, workflows and much more.

- [Workflows](#workflows)
  - [Create Prerelease](#create-prerelease)
  - [Dispatch Deployment Request](#dispatch-deployment-request)
  - [Publish release](#publish-release)
  - [MD Check](#md-check)
  - [License Check](#license-check)

## Workflows

### Create Prerelease

File: [create-prerelease.yml](.github/workflows/create-prerelease.yml)

This workflow will create a prerelease with the same number as the pull request it triggered on.

### Dispatch deployment request

File: [dispath-deployment-request.yml](.github/workflows/dispath-deployment-request.yml)

This workflow will find the associated pull request to a commit, if no pull request is found it will abort.
If a pull request is found, it will use this to find an associated release. Using that release as a referer, it will dispatch an event to the environment repository.

### Publish release

File: [publish-release.yml](.github/workflows/publish-release.yml)

This workflow will find the associated pull request to a commit, if no pull request is found it will abort.
It will use the pull request number to look for a tag with the same number, and mark that as published.

### Markdown Check

File: [md-check.yml](.github/workflows/md-check.yml)

This workflow will perform a link, spelling and formatting check of all *.md files in the repository.

### License Check

File: [license-check.yml](.github/workflows/license-check.yml)

This workflow will perform a check if all files containing application code, contains the correct license header.
