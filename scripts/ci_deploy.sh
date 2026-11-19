#!/usr/bin/env bash
set -euo pipefail
 
: "${PROJECT_ID:?Missing PROJECT_ID}"
: "${WORKSPACE_ID:?Missing WORKSPACE_ID}"
: "${CLIENT_ID:?Missing CLIENT_ID}"
: "${CLIENT_SECRET:?Missing CLIENT_SECRET}"
: "${COMMIT_SHA:?Missing COMMIT_SHA}"
 
BASE="https://agentengine.mongodb.com/api/v1/projects/$PROJECT_ID/workspaces/$WORKSPACE_ID"
TOKEN_ENDPOINT="https://agentengine.mongodb.com/api/v1/oauth/token"
ACCEPT='Accept: application/vnd.agent-engine-2026-09-20-preview+json'
 
# Access tokens last one hour, so get_token runs again before the deploy and the smoke test.
get_token() {
  curl --fail-with-body -sS --retry 3 -X POST \
    -u "$CLIENT_ID:$CLIENT_SECRET" \
    -H "$ACCEPT" \
    -d 'grant_type=client_credentials' "$TOKEN_ENDPOINT" | jq -er '.access_token'
}
 
# Get a short-lived bearer token; never print or persist it.
ACCESS_TOKEN=$(get_token)
 
# Archive only the agent workspace, not the entire GitHub repository.
tar --exclude='.venv' --exclude='__pycache__' \
    --exclude='.agentengine' --exclude='.env' \
    -czf "$RUNNER_TEMP/agent.tar.gz" -C agents/movie-agent .
 
BODY=$(jq -n --arg sha "$COMMIT_SHA" '{
  label: ("github-" + ($sha[:12])),
  git_info: {commit_sha: $sha, branch: "main", dirty: false},
  build_target: {subdirectory: ""},
  auto_deploy: false
}')
 
INIT=$(curl --fail-with-body -sS -X POST "$BASE/builds/archive-init" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "$ACCEPT" \
  -H 'Content-Type: application/json' -d "$BODY")
BUILD_ID=$(jq -er '.build_id' <<< "$INIT")
UPLOAD_URL=$(jq -er '.upload_url' <<< "$INIT")
 
echo "Building source commit $COMMIT_SHA as $BUILD_ID"
# The presigned URL itself is the upload credential. Do NOT add a bearer header.
curl --fail-with-body -sS -X PUT --upload-file "$RUNNER_TEMP/agent.tar.gz" \
  -H 'Content-Type: application/gzip' "$UPLOAD_URL" >/dev/null
unset UPLOAD_URL
 
# A simultaneous build of the same commit may yield 409 BUILD_ALREADY_ACTIVE.
# GitHub concurrency reduces overlap. The start handler below recovers
# using details.existing_build_id or looks up the active build for this commit.
# Capture HTTP status and error body so 409 can be recovered.
# Here we intentionally omit --fail-with-body: 409 is handled below.
START_RESPONSE_FILE=$(mktemp)
if ! START_HTTP_STATUS=$(curl -sS -X POST "$BASE/builds/$BUILD_ID/start" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "$ACCEPT" -o "$START_RESPONSE_FILE" -w '%{http_code}'); then
  rm -f "$START_RESPONSE_FILE"
  echo 'Build start request failed (network or TLS error)' >&2
  exit 1
fi
START_RESPONSE=$(cat "$START_RESPONSE_FILE")
rm -f "$START_RESPONSE_FILE"

case "$START_HTTP_STATUS" in
  202)
    echo "Build accepted: $BUILD_ID" ;;
  409)
    if [[ $(jq -r '.code // empty' <<< "$START_RESPONSE") != 'BUILD_ALREADY_ACTIVE' ]]; then
      echo 'Build start returned HTTP 409 for a different reason' >&2
      exit 1
    fi
    EXISTING_BUILD_ID=$(jq -r '.details.existing_build_id // empty' <<< "$START_RESPONSE")
    if [[ -z "$EXISTING_BUILD_ID" ]]; then
      # If the response omits its ID, find an active build for this commit.
      BUILDS_JSON=$(curl --fail-with-body -sS \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "$ACCEPT" "$BASE/builds?limit=100")
      EXISTING_BUILD_ID=$(jq -r --arg commit "$COMMIT_SHA" '
        [.builds[]? | select(.commit_sha == $commit) |
         select(.status == "queued" or .status == "in_progress" or .status == "waiting") |
         .build_id][0] // empty' <<< "$BUILDS_JSON")
    fi
    if [[ -z "$EXISTING_BUILD_ID" ]]; then
      echo 'BUILD_ALREADY_ACTIVE but no active build for this commit was found' >&2
      exit 1
    fi
    BUILD_ID="$EXISTING_BUILD_ID"
    echo "Reusing active build for commit $COMMIT_SHA: $BUILD_ID" ;;
  *)
    echo "Build start failed: HTTP $START_HTTP_STATUS" >&2
    jq -r '.code // .message // "No error detail"' <<< "$START_RESPONSE" >&2 || true
    exit 1 ;;
esac
 
for attempt in $(seq 1 360); do
  BUILD_JSON=$(curl --fail-with-body -sS \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "$ACCEPT" "$BASE/builds/$BUILD_ID")
  STATUS=$(jq -er '.status' <<< "$BUILD_JSON")
  case "$STATUS" in
    succeeded)
      echo "Build succeeded: $BUILD_ID"
      jq -r '"Executor: \(.executor_type // "unknown"); lockfile mode: \(.lockfile_mode // "not reported")"' <<< "$BUILD_JSON"
      break ;;
    failed|cancelled)
      jq -r '"Executor: \(.executor_type // "unknown"); lockfile mode: \(.lockfile_mode // "not reported")"' <<< "$BUILD_JSON" >&2
      echo "Build $BUILD_ID: $STATUS" >&2
      jq -r '.error_message // "No error detail"' <<< "$BUILD_JSON" >&2
      exit 1 ;;
    queued|waiting|in_progress) ;;
    *) echo "Unexpected build status: $STATUS" >&2; exit 1 ;;
  esac
  if (( attempt == 360 )); then echo 'Build timed out' >&2; exit 1; fi
  sleep 5
done
 
ACCESS_TOKEN=$(get_token)
DEPLOY_JSON=$(curl --fail-with-body -sS -X POST "$BASE/deployments" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "$ACCEPT" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg id "$BUILD_ID" '{build_id:$id}')")
DEPLOY_ID=$(jq -er '.deployment_id' <<< "$DEPLOY_JSON")
echo "Requested deployment $DEPLOY_ID for build $BUILD_ID"
 
for attempt in $(seq 1 180); do
  CURRENT=$(curl --fail-with-body -sS \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "$ACCEPT" \
    "https://agentengine.mongodb.com/api/v1/projects/$PROJECT_ID/deployments/$DEPLOY_ID")
  CURRENT_ID=$(jq -r '.deployment_id // empty' <<< "$CURRENT")
  STATE=$(jq -r '.status // "pending"' <<< "$CURRENT")
  if [[ "$CURRENT_ID" == "$DEPLOY_ID" && ( "$STATE" == 'successful' || "$STATE" == 'succeeded' ) ]] && \
     jq -e '(.health.available == true) and
       ([.components[]? | (.available == true and .ready_replicas == .replicas)] | all)' \
       <<< "$CURRENT" >/dev/null; then
    echo "Deployment healthy: $DEPLOY_ID"; break
  fi
  if [[ "$CURRENT_ID" == "$DEPLOY_ID" && ( "$STATE" == 'failed' || "$STATE" == 'cancelled' || "$STATE" == 'rolled_back' ) ]]; then
    echo "Deployment failed: $STATE" >&2
    jq '{error_message, missing_secrets, components: [.components[]? | {name, failure_reason, failure_message}]}' <<< "$CURRENT" >&2
    exit 1
  fi
  if (( attempt == 180 )); then echo 'Deployment health timed out' >&2; exit 1; fi
  sleep 10
done
 
ACCESS_TOKEN=$(get_token)
export ACCESS_TOKEN PROJECT_ID WORKSPACE_ID
python3 scripts/smoke_test.py
printf 'Verified build %s, deployment %s, commit %s\n' "$BUILD_ID" "$DEPLOY_ID" "$COMMIT_SHA"
