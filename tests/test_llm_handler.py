"""Unit tests for LLMHandler — openai and ChatOpenAI are mocked in conftest."""
import pytest
from unittest.mock import MagicMock, patch

from src.utils.LLMHandler import (
    LLMHandler,
    _MAX_CONTEXT_TOKENS,
    _SUMMARY_MAX_PREDICT,
    _SUPPORTED_MODELS,
)

_API_KEY = "sk-test-key"


def _capture_chatopenai_kwargs(handler, *args, **kwargs):
    """Run load_model with ChatOpenAI swapped for a recorder; return captured kwargs."""
    import src.utils.LLMHandler as llm_module
    calls = []
    original = llm_module.ChatOpenAI
    llm_module.ChatOpenAI = lambda **kw: calls.append(kw) or MagicMock()
    try:
        handler.load_model(*args, **kwargs)
    finally:
        llm_module.ChatOpenAI = original
    return calls


class TestGetAvailableModels:
    def test_returns_hardcoded_supported_models(self):
        handler = LLMHandler()
        assert handler.get_available_models() == ["gpt-5.4-nano", "gpt-5.4-mini", "gpt-5.4"]

    def test_cheapest_model_is_first(self):
        handler = LLMHandler()
        assert handler.get_available_models()[0] == "gpt-5.4-nano"

    def test_requires_no_api_key_and_no_network(self):
        # Constructing the handler and listing models must not touch openai at all.
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        assert not hasattr(llm_module, "ollama")
        assert handler.get_available_models()


class TestGetContextTokens:
    def test_returns_max_context_for_supported_model(self):
        handler = LLMHandler()
        assert handler.get_context_tokens("gpt-5.4-nano") == _MAX_CONTEXT_TOKENS

    def test_returns_max_context_for_every_supported_model(self):
        handler = LLMHandler()
        for name in _SUPPORTED_MODELS:
            assert handler.get_context_tokens(name) == 16384


class TestIsThinkingModel:
    def test_returns_true_for_supported_models(self):
        handler = LLMHandler()
        for name in _SUPPORTED_MODELS:
            assert handler.is_thinking_model(name) is True


class TestLoadModel:
    def test_raises_value_error_for_unknown_model(self):
        handler = LLMHandler()
        with pytest.raises(ValueError, match="not supported"):
            handler.load_model("llama3:latest", _API_KEY)

    def test_current_model_is_none_before_load(self):
        handler = LLMHandler()
        assert handler.currnet_model is None

    def test_loads_supported_model_successfully(self):
        handler = LLMHandler()
        handler.load_model("gpt-5.4-nano", _API_KEY)
        assert handler.currnet_model is not None

    def test_passes_model_name_and_api_key_to_chatopenai(self):
        handler = LLMHandler()
        calls = _capture_chatopenai_kwargs(handler, "gpt-5.4-mini", _API_KEY)
        assert calls[0]["model"] == "gpt-5.4-mini"
        assert calls[0]["api_key"] == _API_KEY

    def test_does_not_send_temperature(self):
        handler = LLMHandler()
        calls = _capture_chatopenai_kwargs(handler, "gpt-5.4", _API_KEY)
        assert "temperature" not in calls[0]

    def test_rejects_missing_api_key(self):
        handler = LLMHandler()
        with pytest.raises(ValueError, match="API key"):
            handler.load_model("gpt-5.4-nano", "")

    def test_disable_thinking_sets_minimal_reasoning_effort(self):
        handler = LLMHandler()
        calls = _capture_chatopenai_kwargs(handler, "gpt-5.4-nano", _API_KEY, disable_thinking=True)
        assert calls[0]["reasoning_effort"] == "minimal"

    def test_disable_thinking_caps_completion_tokens(self):
        handler = LLMHandler()
        calls = _capture_chatopenai_kwargs(handler, "gpt-5.4-nano", _API_KEY, disable_thinking=True)
        assert calls[0]["max_completion_tokens"] == _SUMMARY_MAX_PREDICT

    def test_disable_thinking_bound_is_positive_and_finite(self):
        # A -1 / unbounded budget is what caused reasoning models to hang.
        assert isinstance(_SUMMARY_MAX_PREDICT, int)
        assert _SUMMARY_MAX_PREDICT > 0

    def test_default_load_does_not_constrain_reasoning(self):
        handler = LLMHandler()
        calls = _capture_chatopenai_kwargs(handler, "gpt-5.4-nano", _API_KEY)
        assert "reasoning_effort" not in calls[0]
        assert "max_completion_tokens" not in calls[0]

    def test_disable_thinking_still_passes_model_and_key(self):
        handler = LLMHandler()
        calls = _capture_chatopenai_kwargs(handler, "gpt-5.4-mini", _API_KEY, disable_thinking=True)
        assert calls[0]["model"] == "gpt-5.4-mini"
        assert calls[0]["api_key"] == _API_KEY

    def test_disable_thinking_does_not_send_temperature(self):
        handler = LLMHandler()
        calls = _capture_chatopenai_kwargs(handler, "gpt-5.4", _API_KEY, disable_thinking=True)
        assert "temperature" not in calls[0]

    def test_unknown_model_leaves_current_model_unchanged(self):
        handler = LLMHandler()
        handler.load_model("gpt-5.4-nano", _API_KEY)
        loaded = handler.currnet_model
        with pytest.raises(ValueError):
            handler.load_model("bogus-model", _API_KEY)
        assert handler.currnet_model is loaded


class TestInvokeModel:
    def test_raises_when_no_model_loaded(self):
        handler = LLMHandler()
        mock_prompt = MagicMock()
        with pytest.raises(ValueError, match="No model loaded"):
            handler.invoke_model(mock_prompt, {})

    def test_invokes_chain_with_mappings(self):
        handler = LLMHandler()
        handler.load_model("gpt-5.4-nano", _API_KEY)

        mock_prompt = MagicMock()
        mock_chain = MagicMock()
        mock_chain.invoke.return_value = "The dragon appeared at dawn."

        mock_prompt.__or__ = MagicMock(return_value=mock_chain)
        mock_chain.__or__ = MagicMock(return_value=mock_chain)

        result = handler.invoke_model(mock_prompt, {"question": "Where is the dragon?"})
        assert result == "The dragon appeared at dawn."
        mock_chain.invoke.assert_called_once_with({"question": "Where is the dragon?"})
