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
import { GithubClient } from '../types';

type CreateRefParams = {
  ref: string;
  owner: string;
  repo: string;
  sha: string;
};

/**
 * Create or update release ref
 *
 * @param client The Github Octokit Client
 * @param params Parameters with type CreateRefParams
 */
export const createReleaseRef = async (client: GithubClient, params: CreateRefParams): Promise<void> => {
  core.startGroup('Generating release tag');
  const tagName = params.ref.substring(10); // 'refs/tags/latest' => 'latest'
  core.info(`Attempting to create or update release tag "${tagName}"`);

  try {
    await client.rest.git.createRef(params);
  } catch (error: any) {
    const existingTag = params.ref.substring(5); // 'refs/tags/latest' => 'tags/latest'
    core.info(
      `Could not create new tag "${params.ref}" (${error.message}) therefore updating existing tag "${existingTag}"`
    );
    await client.rest.git.updateRef({
      ...params,
      ref: existingTag,
      force: true,
    });
  }

  core.info(`Successfully created or updated the release tag "${tagName}"`);
  core.endGroup();
};
