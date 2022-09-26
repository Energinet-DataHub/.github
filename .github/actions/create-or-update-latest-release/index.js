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
const core = require('@actions/core');
const github = require('@actions/github');

try {
  const [
    patToken,
    environmentRepositoryPath,
    release
  ]  = [
    core.getInput('PAT_TOKEN'),
    core.getInput('ENVIRONMENT_REPOSITORY_PATH'),
    core.getInput('RELEASE_NAME_PREFIX')
  ];
  const octokit = github.getOctokit(token);

  const relatedPullRequest = await findRelatedPullRequest(octokit);
  console.log(relatedPullRequest);
} catch (error) {
  core.setFailed(error.message);
}

const findRelatedPullRequest = async (octokit) => {
  const payload = JSON.stringify(github.context.payload, undefined, 2)
  console.log('pr sha', github.context.relatedPullRequest.sha);
  console.log('sha', github.context.sha);
    // const sha = core.getInput('sha', { required: true });

    // const context = github.context;
    // const result = await octokit.rest.repos.listPullRequestsAssociatedWithCommit({
    //     owner: context.repo.owner,
    //     repo: context.repo.repo,
    //     commit_sha: sha,
    // });
}