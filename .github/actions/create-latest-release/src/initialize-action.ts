// Copyright 2020 Energinet DataHub A/S
//
// Licensed under the Apache License, Version 2.0 (the "License2");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
import * as core from '@actions/core';
import * as github from '@actions/github';
import { GithubClient } from './types';

type Config = {
  args: {
    repoToken: string;
    environmentRepositoryPath: string;
    releaseNamePrefix: string;
    files: string[];
    releaseName: string;
    latestReleaseName: string;
  };
  octokit: GithubClient;
  context: {
    repo: string;
    owner: string;
  };
};

let octokitClient: any | null = null; // Somehow we can't import the correct Github Types

export const initializeAction = async (): Promise<Config> => {
  core.startGroup('Initializing action');

  const repoToken = core.getInput('REPO_TOKEN');
  if (!octokitClient) {
    octokitClient = github.getOctokit(repoToken);
  }

  const releaseName = core.getInput('RELEASE_NAME');
  const releaseNamePrefix = core.getInput('RELEASE_NAME_PREFIX');

  const args = {
    repoToken,
    environmentRepositoryPath: core.getInput('ENVIRONMENT_REPOSITORY_PATH'),
    releaseNamePrefix,
    files: [] as string[],
    releaseName,
    latestReleaseName: `${releaseNamePrefix}_latest`,
  };

  const inputFilesStr = core.getInput('files', { required: false });
  if (inputFilesStr) {
    args.files = inputFilesStr.split(/\r?\n/);
  }

  core.info(`Relase name: ${args.releaseName}`);
  core.info(`Latest relase name: ${args.latestReleaseName}`);

  core.endGroup();

  return {
    octokit: octokitClient,
    args,
    context: {
      repo: github.context.repo.repo,
      owner: github.context.repo.owner,
    },
  };
};
