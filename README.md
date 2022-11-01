# .github

This repository contains shared github items such as actions, workflows and much more.

## Overview

- [Release procedure](#release-procedure)
- [Workflows](#workflows)
  - [Create Prerelease](#create-prerelease)
  - [Dispatch Deployment Request](#dispatch-deployment-request)
  - [Publish release](#publish-release)
  - [Markdown Check](#markdown-check)
  - [License Check](#license-check)
  - [.NET build and test](#net-build-and-test)

## Release procedure

After we have merged a Pull Request, and created or updated any artifact within current repository, we must follow the procedure below to create a new release.

### Specific version release

First we must always create a specific version release, so developers can use a specific release should they choose to do so.

1. Navigate to [Releases](https://github.com/Energinet-DataHub/.github/releases)

2. Click `Draft a new release` then fill in the formular:

   - In `Choose a tag` specify the new semantic version (e.g. `7.5.2`) and select `Create new tag: <tag name> on publish`.

   - In `Release title` specify the tag name (e.g. `7.5.2`).

   - Click `Generate release notes` and see the description beeing filled out automatically with information about commits since the previous release.

   - When everything looks good press `Publish release` to create the release.

### Major version tag

Secondly we must create or update a major version tag (e.g. `v7`). This allows developers to opt in on automatically using the latest minor or patch version within the choosen major version channel.

If a major version tag exists for the channel in which we just released a minor or patch version then we must delete it first:

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

### .NET build and test

Files:

- [dotnet-build-prerelease.yml](.github/workflows/dotnet-build-prerelease.yml)
- [dotnet-postbuild-test.yml](.github/workflows/dotnet-postbuild-test.yml)

These workflows are intended to run in parallel. While we build the .NET solution on one runner we can utilize this build time to setup other runners for the test execution.

As it is more time effecient to build on Linux, we default to use Ubuntu for building the
.NET solution. The caveat of this is that developers must be observant of the casing of folders and files in the repository as Linux is case-sensitive and Windows is not. This difference can lead to successful builds locally (on Windows) while it could fail on the build runner.

We default to use Windows when testing as we currently also use Windows as the hosting system in Azure.

For code coverage tools to work with the compiled tests we have to use `dotnet publish`. This is handled in the `dotnet-tests-prepare-outputs` action in each domain.

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
