const core = require('@actions/core');
const github = require('@actions/github');

// Args
const [, , pat_token, workflow_id, repo, owner, unique_run_id] = process.argv;

// Define the main function
const main = async () => {
  let octokit = null;

  try {
    // Initiate octokit
    octokit = new github.getOctokit(pat_token);

    let workflow_run_id = null;
    let workflow_run_tries = 0;
    // Since the run does not instantly start, it might take some seconds for it to be fetchable via the github api.
    // Therefor we keep trying until its found or 5 tries is unsuccessful
    while (!workflow_run_id && workflow_run_tries < 6) {
      workflow_run_id = await get_run_id(octokit, workflow_id, unique_run_id);
      if (workflow_run_id) {
        break;
      }

      console.log('Deployment not initiated. Delaying 20s, then retrying');
      workflow_run_tries++;
      await delay(20000);
    }

    if (!workflow_run_id) {
      throw new Error('workflow_run_id was not found');
    }

    await monitor_workflow_run_status(octokit, workflow_run_id);
  } catch (error) {
    core.setFailed(error.message);
  }
}

const monitor_workflow_run_status = async (octokit, workflow_run_id) => {
  let workflow_run_running = true;

  while(workflow_run_running) {
    const workflow_run = await octokit.rest.actions.getWorkflowRun({
      owner,
      repo,
      run_id: workflow_run_id,
    });

    if (workflow_run?.data?.status === 'in_progress'){
      console.log('Deployment in progress. Delaying 30s, then re-fetching status');
      await delay(30000);
    } else if (workflow_run?.data?.status === 'completed'){
      if (workflow_run?.data?.conclusion === 'failure') {
        console.log('Deployment failed');
        throw new Error('Deployment failed');
      }
      else if (workflow_run?.data?.conclusion === 'cancelled') {
        console.log('Deployment cancelled');
        throw new Error('Deployment cancelled');
      }
      else {
        console.log('Deployment succeeded');
        break;
      }
    }
  }
}

const get_run_id = async (octokit, workflow_id, unique_run_id) => {
  let workflow_run_id = null;

  const workflow_runs_response = await octokit.rest.actions.listWorkflowRuns({
    owner,
    repo,
    workflow_id,
    ref: 'renetnielsen/cd-status',
    per_page: 2,
  });

  if (!workflow_runs_response || workflow_runs_response?.data?.total_count <= 0) {
    throw new Error('No workflow runs found');
  } else {
    const workflow_run_tasks = workflow_runs_response?.data?.workflow_runs.map(async (workflow_run) => {
      if (workflow_run_id){
        return;
      }

      const workflow_jobs_response = await octokit.rest.actions.listJobsForWorkflowRun({
        owner,
        repo,
        run_id: workflow_run.id,
      });

      if (workflow_jobs_response?.data?.total_count > 0) {
        for (let workflow_run_job of workflow_jobs_response?.data?.jobs){
          if (workflow_run_id) {
            break;
          }

          for (let workflow_run_job_step of workflow_run_job?.steps){
            if (workflow_run_id) {
              break;
            }

            if (workflow_run_job_step.name === unique_run_id){
              workflow_run_id = workflow_run.id;
              break;
            }
          }
        }
      }
    });

    await Promise.all(workflow_run_tasks);
  }

  return workflow_run_id;
}

const delay = ms => new Promise(res => setTimeout(res, ms));

// Call the main function to run the action
main();