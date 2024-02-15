# GitHub Actions Validate Casing

This folder contains test files for the action `github-actions-validate-casing`.

They must be placed somewhere outside the `.github` folder because the action searches for all YAML files and validates them, which means they would otherwise fail our `ci-orchestrator.yml` workflow.    
