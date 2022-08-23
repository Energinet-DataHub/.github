# .github

This repository contains shared github items such as actions, workflows and much more.

## Overview

- [Release procedure](#release-procedure)
- [Workflows](#workflows)
  - [Create Prerelease](#create-prerelease)
  - [Dispatch Deployment Request](#dispatch-deployment-request)
  - [Publish release](#publish-release)
  - [MD Check](#md-check)
  - [License Check](#license-check)

## Release procedure

After we have merged a Pull Request, and created or updated any artifact within current repository, we must follow the procedure below to create a new release.

### Specific version release

First we must always create a specific version release, so developers can choose to use a specific release should they choose to do so.

1. Navigate to [Releases](https://github.com/Energinet-DataHub/.github/releases)

2. Click `Draft a new release` then fill in the formular:

   - In `Choose a tag` specify the new semantic version (e.g. `7.5.2`) and select `Create new tag: <semantic version> on publish`.

   - In `Release title` specify the new semantic version (e.g. `7.5.2`).

   - Click `Generate release notes` and see the description beeing filled out automatically with information about commits since the previous release.

   - When everything looks good press `Publish release` to create the release.

### Major version tag

Secondly we must create or update a major version tag (e.g. `v7`). This allows developers to opt in on automatically using the latest minor or patch version within the choosen major version channel.

If a major version tag exists for the channel in which we just released a minor or patch version then we must delete it first:

1. Checkout the `main` branch and `pull` any changes to be fully up to date.

2. Execute the following in a shell:

```bash
git tag -d <tag name>
git push origin :<tag name>
```

Then we can create the new major version tag for a specific commit:

1. Execute the following in a shell:

```bash
git tag -f <tag name> <commit hash code>
git push origin :<tag name>
```

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
