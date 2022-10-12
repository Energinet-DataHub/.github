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
    githubToken: string;
    sha: string;
  };
  octokit: GithubClient;
  context: {
    repo: string;
    owner: string;
  };
};

export const initializeAction = async (): Promise<Config> => {
  core.startGroup('Initializing action');

  const args = {
    githubToken: core.getInput('github_token', { required: true }),
    sha: core.getInput('sha', { required: true }),
  };

  core.endGroup();

  return {
    octokit: github.getOctokit(args.githubToken),
    args,
    context: {
      repo: github.context.repo.repo,
      owner: github.context.repo.owner,
    },
  };
};
