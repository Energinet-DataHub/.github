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

type CreateReleaseByTagParams = {
  owner: string;
  repo: string;
  tag: string;
  body: string;
};

/**
 * Create a new release
 *
 * @param client The Github Octokit Client
 * @param params Parameters with type CreateReleaseByTagParams
 */
export const createRelease = async (
  client: GithubClient,
  params: CreateReleaseByTagParams
): Promise<{ uploadUrl: string; id: number }> => {
  core.startGroup(`Generating new GitHub release for the "${params.tag}" tag`);

  core.info('Creating new release');

  const createReleaseResponse = await client.rest.repos.createRelease({
    tag_name: params.tag,
    owner: params.owner,
    repo: params.repo,
    name: params.tag,
    draft: false,
    prerelease: false,
    body: params.body,
  });

  core.endGroup();

  return {
    uploadUrl: createReleaseResponse.data.upload_url,
    id: createReleaseResponse.data.id,
  };
};
