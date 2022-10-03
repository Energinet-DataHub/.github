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
import axios from 'axios';
import * as core from '@actions/core';
import { GithubClient, ReleaseAsset } from '../types';

type GetReleaseAssetsParams = {
  owner: string;
  repo: string;
  tag: string;
  repoToken: string;
};

/**
 * Find the release assets
 *
 * @param client The Github Octokit Client
 * @param params Parameters with type GetReleaseAssetsParams
 */
export const getReleaseAssets = async (
  client: GithubClient,
  params: GetReleaseAssetsParams
): Promise<ReleaseAsset[]> => {
  core.startGroup(`Fetching assets for release with tag "${params.tag}"`);

  core.info(`Searching for a release with tag "${params.tag}"`);

  let release;

  try {
    release = await client.rest.repos.getReleaseByTag(params);
  } catch (error: any) {
    throw new Error(`Could not find release with tag "${params.tag}" (${error.message})`);
  }

  if (!release) {
    throw new Error(`Could not find release with tag "${params.tag}"`);
  } else if (!release.data.assets) {
    throw new Error(`Could not find any assets for release with tag "${params.tag}"`);
  }

  const releaseAssets = release.data.assets.map((asset) => {
    return {
      id: asset.id,
      name: asset.name,
      contentType: asset.content_type,
      size: asset.size,
    };
  });

  const assets: ReleaseAsset[] = [];

  for (const releaseAsset of releaseAssets) {
    core.info(`Searching for assets with the id "${releaseAsset.id}"`);

    const assetResponse = await axios.get(
      `https://api.github.com/repos/${params.owner}/${params.repo}/releases/assets/${releaseAsset.id}`,
      {
        headers: {
          Accept: 'application/octet-stream',
          Authorization: `token ${params.repoToken}`,
          'User-Agent': 'create-latest-release-action',
        },
        responseType: 'arraybuffer',
      }
    );

    if (assetResponse.status != 200) {
      core.info(`Asset with id "${releaseAsset.id}" not found`);
      continue;
    }

    core.info(`Asset with id "${releaseAsset.id}" found`);

    assets.push({
      ...releaseAsset,
      body: assetResponse.data,
    });
  }

  core.endGroup();

  return assets;
};
