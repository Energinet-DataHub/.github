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
import { initializeAction } from './initialize-action';

/**
 * Function that finds the related pull request from SHA
 */
const main = async () => {
  try {
    const app = await initializeAction();

    const result = await app.octokit.rest.repos.listPullRequestsAssociatedWithCommit({
      owner: app.context.owner,
      repo: app.context.repo,
      commit_sha: app.args.sha,
    });

    if (result.data && result.data.length > 0) {
      const pullRequest = result.data[0];
      core.info(`setting output pull_request_number: ${pullRequest.number}`);
      core.setOutput('pull_request_number', pullRequest.number);
    } else {
      core.error('No pull request found');
      throw new Error('No pull request found');
    }
  } catch (error: any) {
    core.setFailed(error.message);
  }
};

main();
