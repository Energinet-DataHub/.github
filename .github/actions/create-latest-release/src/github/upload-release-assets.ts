import * as core from '@actions/core';
import { GithubClient, ReleaseAsset } from '../types';

type UploadReleaseAssetsParams = {
  owner: string;
  repo: string;
  uploadUrl: string;
  assets: ReleaseAsset[];
  releaseId: number;
};

/**
 * Uploads the assets supplied to the releaseId
 *
 * @param client The Github Octokit Client
 * @param params Parameters for uploading files to the release
 */
export const uploadReleaseAssets = async (client: GithubClient, params: UploadReleaseAssetsParams) => {
  core.startGroup('Uploading release artifacts');
  for (const asset of params.assets) {
    core.info(`Uploading ${asset.name}`);

    const uploadArgs = {
      owner: params.owner,
      repo: params.repo,
      release_id: params.releaseId,
      url: params.uploadUrl,
      name: asset.name,
      data: asset.body as unknown as string,
      headers: {
        'content-length': asset.size,
        'content-type': asset.contentType,
      },
    };

    try {
      await client.rest.repos.uploadReleaseAsset(uploadArgs);
    } catch (error: any) {
      throw new Error(`Problem uploading ${asset.name} as a release asset`);
    }
  }
  core.endGroup();
};
