# .github

This repository contains shared github items such as actions, workflows and much more.

## Overview

- [Versioning](#versioning)
- [Release procedure](#release-procedure)
    - [Preparing a new major version](#preparing-a-new-major-version)
    - [Release process](#release-process)
- [Workflows](#workflows)
    - [CI Base](#ci-base)
    - [.NET build and test](#net-build-and-test)
    - [Python CI Test and Coverage](#python-ci-test-and-coverage)
    - [Python build and push docker image](#python-build-and-push-docker-image)
    - [Notify Team](#notify-team)
    - [Structurizr Lite: Render diagrams](#structurizr-lite-render-diagrams)

## Versioning

1. We support up to two major versions at any given time.
1. The latest major version must contain all changes (new functionality, improvements, maintenance).
1. The previous major version should only contain **important maintenance** changes.

## Release Procedure

Every pull-request merged to main updates the workflow file [create-release-tag.yml](.github/workflows/create-release-tag.yml). The associated action ensures all merges are released and updates the latest major version tag (i.e. v46).

If a Pull-request implements any breaking changes we must create a new major version (i.e. v46 -> v47). Otherwise we keep updates as minor or patches.

### Preparing a new major version

If we have breaking changes and wish to push a new major version - a number of steps is needed that shifts the existing version into maintenance mode prior to merging.

***Example moving from 9.1.3 to 10.0.0:***

1. Delete the previous major version release and tag (v9) in GitHub - remember to delete the tag in your local git as well
1. Create a root branch based on the last commit for the latest version (i.e. 9.1.2) and name the branch identically to the old release tag v9 (see git commands below)
1. Create a branch policy for this new branch to ensure we use PR's for any changes on branch named (v9)

Git commands:
git tag d- <v-tag-to-delete>
git checkout <commit-sha>
git checkout -b <branch-name>
git push

---
> :warning: **Releases lower than two versions (i.e. v45 when v47 has been created) WILL BE DELETED !!**

This is handled by a scheduled workflow **(/Energinet-DataHub/dh3-automation/blob/main/.github/workflows/rat-update-scheduled.yml)** out of `dh3-automation` every night.

We **MUST** ensure that no references exists to releases of  `.github` and `geh-terraform-modules` about to be deleted.

---

## Release process

After we have merged a Pull Request, and created or updated any artifact within current repository, we must follow the procedure below:

---
> :information_source: **These are the steps handled by the ci-workflow [create-release-tag.yml](.github/workflows/create-release-tag.yml)**

---

1. Navigate to [Releases](https://github.com/Energinet-DataHub/.github/releases)
2. Find the major version release and click on its name (e.g. `v7`).

   - This will open the release.
   - Click the `Delete (icon)` and choose to delete the release.

3. Navigate to [Tags](https://github.com/Energinet-DataHub/.github/tags)

4. Find the major version tag and click on its name (e.g. `v7`).

   - This will open the tag.
   - Click `Delete` and choose to delete the tag.

Then we can create the new major version tag for a specific commit:

1. Navigate to [Releases](https://github.com/Energinet-DataHub/.github/releases)

2. Click `Draft a new release` then fill in the formular:

   - In `Choose a tag` specify the major version prefixed with `v` (e.g. `v7`) and select `Create new tag: <tag name> on publish`.

   - In `Target` select `Recent Commits` and choose the commit hash code of the just released minor or patch version.

   - In `Release title` specify the tag name (e.g. `v7`).

   - In `Description` write `Latest release`.

   - When everything looks good press `Publish release` to create the release.

## Workflows

### CI Base

File: [ci-base.yml](.github/workflows/ci-base.yml)

This workflow validates the files in a repository for a common set of basic rules, and should be used as part of the pull request verification on all repositories.

A given repository might be able to skip certain features but at least some of the features are relevant for all repositories.

Features:

- Check relevant files for a license header.
- Perform markdown linting.
- Validate links in markdown files.
- Perform YAML linting of GitHub actions/workflows.
- Perform casing validation of GitHub actions/workflows.
- Execute Pester tests for any GitHub actions.

Teams should ensure developers configure their local development environment to follow the same rules as what will be forced by the workflow. All rules can be configured using VS Code and extensions. Internal contributors can get more information on the subject by looking in the guidelines documented by The Outlaws.

### .NET build and test

Files:

- [dotnet-build-prerelease.yml](.github/workflows/dotnet-build-prerelease.yml)
- [dotnet-postbuild-test.yml](.github/workflows/dotnet-postbuild-test.yml)

These workflows are intended to run in parallel. While we build the .NET solution on one runner we can utilize this build time to setup other runners for the test execution.

#### *Build*

This workflow build the GitHub PR and SHA (last merge commit on PR) into the .NET assembly meta data property `InformationalVersion`. The final format of the valus is `<version>+PR_<pr number>+SHA_<sha>`.

As it is more time effecient to build on Linux, we default to use Ubuntu for building the .NET solution.

The caveat of this is:

- Developers must be observant of the casing of folders and files in the repository as Linux is case-sensitive and Windows is not. This difference can lead to successful builds locally (on Windows) while it could fail on the build runner.
- An exception stacktrace from a .NET assembly builded on Linux uses the Linux path (if a path is given in the trace).

#### *Test*

We default to use Windows when testing as we currently also use Windows as the hosting system in Azure.

For code coverage tools to work with the compiled tests we must use:

- `dotnet publish` on each test project. This is handled in the `dotnet-tests-prepare-outputs` action in each domain.
- `dotnet-coverage` to test and collect coverage of each test project. This is handled in the [dotnet-postbuild-test.yml](.github/workflows/dotnet-postbuild-test.yml) workflow.

Example from a `dotnet-tests-prepare-outputs`:

``` yml
    # To ensure code coverage tooling is available in bin folder, we use publish on test assemblies
    # See https://github.com/coverlet-coverage/coverlet/issues/521#issuecomment-522429394
    - name: Publish IntegrationTests
      shell: bash
      run: |
        dotnet publish \
          '.\source\GreenEnergyHub.Charges\source\GreenEnergyHub.Charges.IntegrationTests\GreenEnergyHub.Charges.IntegrationTests.csproj' \
          --no-build \
          --no-restore \
          --configuration Release \
          --output '.\source\GreenEnergyHub.Charges\source\GreenEnergyHub.Charges.IntegrationTests\bin\Release\net6.0'
```

Some test projects has a reference to more than one "hosting application" (e.g. a Function App or a Web API).
If that is the case it is necessary to add the following configuration to the project `*.csproj` file
to avoid an error when publishing:

``` xml
    <!--
      To ensure code coverage tooling is available on build agents we have to use publish in workflow.
      This can cause an error which we ignore using the follow setting.
      See https://stackoverflow.com/questions/69919664/publish-error-found-multiple-publish-output-files-with-the-same-relative-path/69919694#69919694
    -->
    <PropertyGroup>
      <ErrorOnDuplicatePublishOutputFiles>false</ErrorOnDuplicatePublishOutputFiles>
    </PropertyGroup>
```

If a compiled test project is using the Microsoft type `WebApplicationFactory<TEntryPoint>` it is necessary to use the workflow parameters:

- `ASPNETCORE_TEST_CONTENTROOT_VARIABLE_NAME`
- `ASPNETCORE_TEST_CONTENTROOT_VARIABLE_VALUE`

Set `ASPNETCORE_TEST_CONTENTROOT_VARIABLE_NAME` to an environment variable name following the format `ASPNETCORE_TEST_CONTENTROOT_<ASSEMBLY_NAME>`.
Where `<ASSEMBLY_NAME>` is the name of the assembly containing the type `TEntryPoint`, but using `_` instead of dot (.).

Set `ASPNETCORE_TEST_CONTENTROOT_VARIABLE_VALUE` to the content root of the Web API/Application. This is usually the folder of the `*.csproj` file.

Example from `opengeh-wholesale`:

``` yml
      ASPNETCORE_TEST_CONTENTROOT_VARIABLE_NAME: ASPNETCORE_TEST_CONTENTROOT_ENERGINET_DATAHUB_WHOLESALE_WEBAPI
      ASPNETCORE_TEST_CONTENTROOT_VARIABLE_VALUE: '\source\dotnet\Services\WebApi'
```

As a good practice also add a comment to the class inheriting from `WebApplicationFactory<TEntryPoint>` like in the following example from `opengeh-wholesale`:

``` csharp
    /// <summary>
    /// When we execute the tests on build agents we use the builded output (assemblies).
    /// To avoid an 'System.IO.DirectoryNotFoundException' exception from WebApplicationFactory
    /// during creation, we must set the path to the 'content root' using an environment variable
    /// named 'ASPNETCORE_TEST_CONTENTROOT_ENERGINET_DATAHUB_WHOLESALE_WEBAPI'.
    /// </summary>
    public class WebApiFactory : WebApplicationFactory<Startup>
```

### Python CI Test and Coverage

File: [python-ci.yml](.github/workflows/python-ci.yml)

This workflow can be used to validate python code and execute python tests.

**Requirements:**

A `docker-compose.yml` file should be placed here `.devcontainer/docker-compose.yml`.
The name of the service inside the `docker-compose.yml` file should be `python-unit-test`.

A `entrypoints.sh` file should be placed here `.docker/entrypoint.sh`.

**Features:**

- Perform static code analysis of python code (using flake8).
- Login to Azure using OIDC for accessing the integration test environment from python tests.
- Execute a custom action to run python tests.
- Upload test results to workflow summary.
- Upload test coverage report as workflow artifact

Optional `tests_filter_expression` can be set to add a filter to split the execution of python tests on multiple GitHub runners.

The filter expression should be used in the `entrypoint.sh` like this:

``` sh
# $1: (Optional) Can be set to specify a filter for running python tests by using 'keyword expressions'.
# See use of '-k' and 'keyword expressions' here: https://docs.pytest.org/en/7.4.x/how-to/usage.html#specifying-which-tests-to-run
echo "Filter (keyword expression): $1"

coverage run --branch -m pytest -k "$1" --junitxml=pytest-results.xml .
```

Optional `image_tag` can be set which the custom action `python-unit-test` is being called with. Default value is `latest`. If `python-unit-test` does not know the input `image_tag` it will throw a warning. It is possible to get the `image_tag` from [the python docker build](#python-build-and-push-docker-image).

### Python Build and Push Docker Image

File: [python-build-and-push-docker-image.yml](.github/workflows/python-build-and-push-docker-image.yml)

This workflow can be used to build and push docker image used for Python.

The workflow should be giving two input parameters:

- `docker_changed`: When Docker files changed in Pull Request. It determines what image tag to build and push the docker.
- `docker_changed_in_commit`: When Docker files changed in the commit that triggered the CI. If there was no changes in the Docker files it will skip the Docker build.

The workflow gives one output variable:

- `image_tag`: Gives the image tag that should be used when running the `python-ci.yml` workflow.

### Notify Team

File: [notify-team.yml](.github/workflows/notify-team.yml)

> Ideally we would not have to implement a workflow like this, but at the moment we do not feel GitHub allows us to configure notifications specific enough for us to get important notifications and avoid noisy notifications.

The purpose of this workflow is to notify a team through emails, if a workflow fails.

You may add a comma-delimited list of recipients. This means teams can configure the notification workflow to email them directly to their Office 365 account, as well as to their MS Teams channel using the channel's email-address.

#### *Details*

The workflow uses SendGrid to send emails.

When called with a known `TEAM_NAME` it looks up a corresponding GitHub secret to determine who should receive the email notification. This secret must contain either a single email address, or a comma-separated list of emails (no whitespaces allowed).

The secrets are created as organizational secrets in the Energinet organization, and can be managed by The Outlaws.

### Structurizr Lite: Render diagrams

File: [structurizr-render-diagrams.yml](.github/workflows/structurizr-render-diagrams.yml)

Read the documentation in the workflow file, including information about `inputs` and `secrets`.

The workflow renders all views in a Structurizr Lite workspace as `*.png` files (diagrams). The diagrams are placed in a folder defined by `DIAGRAM_FOLDER` combined with the name of the DSL file, and auto-committed to the current branch. E.g. the images generated from a file named `views.dsl` will be placed in `DIAGRAM_FOLDER\views\`.

The implementation uses a Structurizr Lite docker image available at [Docker Hub](https://hub.docker.com/r/structurizr/lite/tags) and a script available at [Structurizr / Puppeteer](https://github.com/structurizr/puppeteer).

**Notice:** In case the redering of diagrams fails, see if a newer docker image, or newer script, is available.
