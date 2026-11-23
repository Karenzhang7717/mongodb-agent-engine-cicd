# MongoDB Atlas Agent Engine: Movie Agent CI/CD

Companion code for the article *From Git Push to a Deployed Agent: A CI/CD Pipeline for AI Agents*.

**Status:** End-to-end Atlas Agent Engine **Build → Deploy → Invoke verified** on November 23, 2026, with the Gemini 3.5 Flash-Lite model. [Successful GitHub Actions Run #45232170070](https://github.com/Karenzhang7717/mongodb-agent-engine-cicd/actions/runs/45232170070). Agent Engine is in Public Preview and MongoDB does not recommend production deployments during preview.

## Structure
- `agents/movie-agent`: LangGraph agent based on MongoDB's official `hello-world-agent` template, renamed to `agent_movie_agent`.
- `scripts/seed_movies.py`: create sample movie records in a selected MongoDB database.
- `tests/test_movie_query.py`: database-free tests using real `mongomock`.
- `.github/workflows/deploy.yml`: offline CI on PRs and main; deployment stays disabled until explicitly enabled through `ENABLE_ATLAS_DEPLOY` or manual dispatch.
- `scripts/ci_deploy.sh`: archive-build/deploy/health/invoke pipeline (verified end-to-end on November 23, 2026).

## Run offline tests
```bash
python3.11 -m pip install pytest==9.2.0 mongomock==4.3.0 pymongo==4.20.0
PYTHONPATH=agents/movie-agent/src MONGODB_URI=mongodb://unused python3.11 -m pytest -q tests/
```

## Prepare an Atlas workspace
Run `agentengine create --template hello-world-agent --name movie-agent --llm gemini` to generate a local project and its `project-config.yaml`, and `agentengine init` to register it to your own Atlas project. The private local `.env` and account-specific `project-config.yaml` must not be copied from someone else's workspace. Use `gitops.provider=archive` for this API workflow. Set your Google Gemini API key as `LLM_API_KEY` in platform secrets, and `MONGODB_URI` via Atlas setup; provision only when you accept billing.

**Important:** Deployment is disabled by default. After configuring project/workspace variables, CI service account secrets, Atlas, database seeding and `SMOKE_TEST_NONCE`, set the repository variable `ENABLE_ATLAS_DEPLOY` to `true` to enable deployment on merges to main, or explicitly run the GitHub workflow on main with `confirm_deploy=true`. These operations can incur Atlas costs. A `production` GitHub environment name does not imply that Agent Engine is production-ready.

## Credential names
Repository variables: `AGENTENGINE_PROJECT_ID`, `AGENTENGINE_WORKSPACE_ID`, and opt-in deployment toggle `ENABLE_ATLAS_DEPLOY` (default unset).
GitHub environment secrets: `AE_SA_CLIENT_ID`, `AE_SA_CLIENT_SECRET`, `SMOKE_TEST_NONCE`.
Never commit `.env`, MongoDB connection strings with passwords, API keys or OAuth tokens.

Source template: https://github.com/mongodb/agent-engine-examples/tree/main/templates/hello-world-agent

## Gemini provider
The agent uses `ChatGoogleGenerativeAI(model="gemini-3.5-flash-lite")`, with the Google AI Studio key supplied through `LLM_API_KEY`. The code previously used Anthropic; do not use an Anthropic-only local scaffold unchanged. Existing local users should update `agents/movie-agent/src/agent_movie_agent/llm.py` to match this repository, then refresh dependencies with `uv lock` from the agent directory. Gemini API and Atlas hosting have separate billing policies.

## Verified cloud run

The November 23, 2026 workflow completed the entire pipeline successfully, including a real seeded Dune lookup against MongoDB:

- [GitHub Actions Run #45232170070](https://github.com/Karenzhang7717/mongodb-agent-engine-cicd/actions/runs/45232170070) — source commit `4a452b412133d95a63cc3fa4596868c34d16257c`
- Build: `bld_01M84RJ1CD8DKG38S8BSKVFFEG`, approximately 2 minutes 48 seconds from archive/build start to successful build
- Deployment: `deploy-5195ea0e`, approximately 1 minute 12 seconds from request to healthy
- Smoke invoke: Dune lookup returned the seeded MongoDB verification marker approximately 23 seconds after deployment health
- Total remote archive/build to verified invoke: approximately 4 minutes 24 seconds, excluding initial project and Atlas provisioning

The deployment used a Gemini Free Tier API key; actual availability and quotas depend on the Google AI Studio project. Atlas hosting can still incur charges. Ordinary merges do not deploy unless explicitly enabled; the verification used a one-time workflow.
