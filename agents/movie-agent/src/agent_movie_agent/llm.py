"""Claude LLM for the movie-lookup agent (requires LLM_API_KEY)."""
import os
from langchain_anthropic import ChatAnthropic
from langchain_core.language_models import BaseChatModel
from pydantic import SecretStr

MODEL = "claude-sonnet-4-5"

def build_llm(temperature: float = 0) -> BaseChatModel:
    key = os.environ.get("LLM_API_KEY", "")
    if not key or key == "replace-me":
        raise RuntimeError("LLM_API_KEY must be configured in local .env or Agent Engine secrets")
    return ChatAnthropic(model=MODEL, api_key=SecretStr(key), temperature=temperature)
