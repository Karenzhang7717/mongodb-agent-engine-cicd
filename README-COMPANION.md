# MongoDB Atlas Agent Engine: Movie Agent CI/CD

Companion code for the article *From Git Push to a Deployed Agent: A CI/CD Pipeline for AI Agents*.

**Status:** Example source and offline tests; full remote Atlas deployment has **not yet been verified**. Agent Engine is in Public Preview and MongoDB does not recommend production deployments during preview.

## Structure
- `agents/movie-agent`: LangGraph agent based on MongoDB's official `hello-world-agent` template, renamed to `agent_movie_agent`.
- `scripts/seed_movies.py`: create sample movie records in a selected MongoDB database.
- `tests/test_movie_query.py`: database-free tests using real `mongomock`.
- `.github/workflows/deploy.yml`: offline CI on PRs and push to main; *deployment is manual and opt-in* until credentials and costs are approved.
- `scripts/ci_deploy.sh`: archive-build/deploy/health/invoke pipeline (not yet verified end-to-end).

## Run offline tests
```bash
python3.11 -m pip install pytest==9.2.0 mongomock==4.3.0 pymongo==4.20.0
PYTHONPATH=agents/movie-agent/src MONGODB_URI=mongodb://unused python3.11 -m pytest -q tests/
```

## Prepare an Atlas workspace
Run `agentengine create --template hello-world-agent --name movie-agent --llm anthropic` to generate a local project and its `project-config.yaml`, and `agentengine init` to register it to your own Atlas project. The private local `.env` and account-specific `project-config.yaml` must not be copied from someone else's workspace. Use `gitops.provider=archive` for this API workflow. Set `LLM_API_KEY` in platform secrets, and `MONGODB_URI` via Atlas setup; provision only when you accept billing.

**Important:** Deployment is intentionally not triggered automatically on push: manually run the GitHub workflow on main with `confirm_deploy=true` after configuring project/workspace variables, CI service account secrets, Atlas, database seeding and `SMOKE_TEST_NONCE`. A `production` GitHub environment name does not imply that Agent Engine is production-ready.

## Credential names
Repository variables: `AGENTENGINE_PROJECT_ID`, `AGENTENGINE_WORKSPACE_ID`.
GitHub environment secrets: `AE_SA_CLIENT_ID`, `AE_SA_CLIENT_SECRET`, `SMOKE_TEST_NONCE`.
Never commit `.env`, MongoDB connection strings with passwords, API keys or OAuth tokens.

Source template: https://github.com/mongodb/agent-engine-examples/tree/main/templates/hello-world-agent
