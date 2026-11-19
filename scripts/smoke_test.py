import json
import os
import urllib.request
 
base = "https://agentengine.mongodb.com/api/v1"
url = (f"{base}/projects/{os.environ['PROJECT_ID']}"
       f"/workspaces/{os.environ['WORKSPACE_ID']}/invoke")
request = urllib.request.Request(
    url,
    data=json.dumps({"message": "Use lookup_movie to retrieve Dune from the database. Include the complete plot verbatim, including its test marker."}).encode(),
    headers={
        "Authorization": f"Bearer {os.environ['ACCESS_TOKEN']}",
        "Content-Type": "application/json",
        "Accept": "application/vnd.agent-engine-2026-09-20-preview+json",
    },
    method="POST",
)
with urllib.request.urlopen(request, timeout=120) as response:
    result = json.load(response)
 
if result.get("success") is not True or result.get("status") != "completed":
    raise SystemExit(f"Invocation did not complete successfully: {result.get('status')}")
answer = str(result.get("response", ""))
expected_nonce = os.environ["SMOKE_TEST_NONCE"]
if not expected_nonce or expected_nonce not in answer:
    raise SystemExit("Smoke test failed: expected unique seeded marker missing")
print("Smoke test passed: completed invocation returned seeded movie detail")
