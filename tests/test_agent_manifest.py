"""Pre-deployment structural checks for the Agent Engine manifest."""
from pathlib import Path
import tomllib

import yaml


def test_agent_manifest_declares_sandbox_egress_modes():
    path = Path(__file__).resolve().parents[1] / "agents/movie-agent/agent.yaml"
    config = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert config["entrypoint"] == "agent_movie_agent.main:app"
    assert config["framework"] == "langgraph"

    # The first Atlas deployment requires an explicit egress policy. Keep the
    # tutorial sandbox network closed except for the platform base policy.
    # The agent does not need direct internet access. The tool sandbox,
    # which dispatches wrapped LLM calls, reaches only the Gemini API.
    agent_network = config["sandboxes"]["agent"]["network"]
    assert agent_network["egress_mode"] == "deny_all"
    assert not agent_network.get("egress")

    tool_network = config["sandboxes"]["tool"]["network"]
    assert tool_network["egress_mode"] == "allow_list"
    assert tool_network["egress"] == [
        {"fqdn": "generativelanguage.googleapis.com", "ports": [443]}
    ]


def test_platform_runtime_protobuf_bound():
    """Pin only the protobuf compatibility range, not the platform SDK wheels."""
    project_file = Path(__file__).resolve().parents[1] / "agents/movie-agent/pyproject.toml"
    project = tomllib.loads(project_file.read_text(encoding="utf-8"))
    dependencies = project["project"]["dependencies"]
    assert "protobuf>=6.33.6,<7" in dependencies
    assert not any(
        dep.startswith(("agent-engine-runner-shared", "agent-engine-sdk-langgraph"))
        for dep in dependencies
    )


def test_gemini_model_supports_new_free_tier_keys():
    """Avoid retired Gemini model IDs that fail for newly created API keys."""
    import ast
    source = Path(__file__).resolve().parents[1] / "agents/movie-agent/src/agent_movie_agent/llm.py"
    module = ast.parse(source.read_text(encoding="utf-8"))
    model_values = [
        ast.literal_eval(target.value)
        for target in module.body
        if isinstance(target, ast.Assign)
        and any(isinstance(name, ast.Name) and name.id == "MODEL" for name in target.targets)
    ]
    assert model_values == ["gemini-3.5-flash-lite"]
