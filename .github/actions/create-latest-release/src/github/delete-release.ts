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

type DeleteReleaseParams = {
  owner: string;
  repo: string;
  tag: string;
};

/**
 * Deletes a previous release
 *
 * @param client The Github Octokit Client
 * @param params Parameters with type DeleteReleaseParams
 */
export const deleteRelease = async (client: GithubClient, params: DeleteReleaseParams): Promise<void> => {
  core.startGroup(`Deleting GitHub releases associated with the tag "${params.tag}"`);

  try {
    core.info(`Searching for releases corresponding to the "${params.tag}" tag`);
    const resp = await client.rest.repos.getReleaseByTag(params);

    core.info(`Deleting release: ${resp.data.id}`);
    await client.rest.repos.deleteRelease({
      owner: params.owner,
      repo: params.repo,
      release_id: resp.data.id,
    });
  } catch (error: any) {
    core.info(`Could not find release associated with tag "${params.tag}" (${error.message})`);
  }

  core.endGroup();
};
