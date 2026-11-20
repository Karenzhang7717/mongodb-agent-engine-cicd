"""Pre-deployment structural checks for the Agent Engine manifest."""
from pathlib import Path

import yaml


def test_agent_manifest_declares_sandbox_egress_modes():
    path = Path(__file__).resolve().parents[1] / "agents/movie-agent/agent.yaml"
    config = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert config["entrypoint"] == "agent_movie_agent.main:app"
    assert config["framework"] == "langgraph"

    # The first Atlas deployment requires an explicit egress policy. Keep the
    # tutorial sandbox network closed except for the platform base policy.
    for sandbox in ("agent", "tool"):
        network = config["sandboxes"][sandbox]["network"]
        assert network["egress_mode"] == "deny_all"
        assert not network.get("egress")
