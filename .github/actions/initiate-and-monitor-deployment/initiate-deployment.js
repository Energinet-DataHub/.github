const core = require('@actions/core');
const github = require('@actions/github');

// Args
const [, , pat_token, release_name, workflow_id, repo, owner, unique_run_id] = process.argv;

// Define the main function
const main = async () => {
  let octokit = null;

  try {
    // Initiate octokit
    octokit = new github.getOctokit(pat_token);

    // Initiate deployment
    await octokit.rest.actions.createWorkflowDispatch({
      owner,
      repo,
      workflow_id,
      ref: 'renetnielsen/cd-status',
      inputs: {
        RELEASE_NAME: release_name,
        UNIQUE_RUN_ID: unique_run_id,
      }
    });
  } catch (error) {
    core.setFailed(error.message);
  }
}

// Call the main function to run the action
main();