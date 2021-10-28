# .github

This repository contains shared github items such as actions, workflows and much more.

- [Workflows](#workflows)
  - [Create Prerelease](#create-prerelease)
  - [Dispatch Deployment Request](#dispatch-deployment-request)
  - [Publish release](#publish-release)

## Workflows

### Create Prerelease

File: [create-prerelease.yml](.github/workflows/create-prerelease.yml)

This workflow will create a prerelease with the same number as the pull request it triggered on.

### Dispatch deployment request

File: [dispath-deployment-request.yml](.github/workflows/dispath-deployment-request.yml)

This workflow will find the associated pull request to a commit, if no pull request is found it will abort.
If it can find a pull request, it will dispatch an event containing the pull request number to the environment repository.

### Publish release

File: [publish-release.yml](.github/workflows/publish-release.yml)

This workflow will find the associated pull request to a commit, if no pull request is found it will abort.
It will use the pull request number to look for a tag with the same number, and mark that as published.
