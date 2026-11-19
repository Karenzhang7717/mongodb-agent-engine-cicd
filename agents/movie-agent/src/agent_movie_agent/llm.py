"""Gemini LLM for the movie-lookup agent (requires LLM_API_KEY)."""

import os

from langchain_core.language_models import BaseChatModel
from langchain_google_genai import ChatGoogleGenerativeAI

MODEL = "gemini-2.5-flash-lite"


def build_llm(temperature: float = 0) -> BaseChatModel:
    key = os.environ.get("LLM_API_KEY", "")
    if not key or key == "replace-me":
        raise RuntimeError("LLM_API_KEY must be configured in local .env or Agent Engine secrets")
    return ChatGoogleGenerativeAI(model=MODEL, google_api_key=key, temperature=temperature)
