"""Unit tests for LLMHandler — ChatOpenAI is mocked in conftest."""
import httpx
import openai
import pytest
from unittest.mock import MagicMock

from src.utils.LLMHandler import (
    LLMHandler,
    _AUTH_ERROR_MESSAGE,
    _CONNECTION_ERROR_MESSAGE,
    _MAX_CONTEXT_TOKENS,
    _RATE_LIMIT_ERROR_MESSAGE,
    _SUMMARY_MAX_PREDICT,
    _SUPPORTED_MODELS,
    missing_key_message,
)

_API_KEY = "sk-test-key"
_REQUEST = httpx.Request("POST", "https://api.openai.com/v1/chat/completions")


def _status_error(cls, status_code):
    return cls("boom", response=httpx.Response(status_code, request=_REQUEST), body=None)


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

    def test_fetch_available_models_returns_curated_list(self):
        handler = LLMHandler()
        assert handler.fetch_available_models("") == list(_SUPPORTED_MODELS)

    def test_fetch_available_models_needs_no_key(self):
        handler = LLMHandler()
        assert handler.fetch_available_models(None) == list(_SUPPORTED_MODELS)

    def test_fetch_available_models_returns_a_fresh_list(self):
        handler = LLMHandler()
        handler.fetch_available_models("").append("gpt-bogus")
        assert "gpt-bogus" not in handler.fetch_available_models("")


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


class TestInvokeModelErrorTranslation:
    """Raw OpenAI failures must become ValueErrors carrying readable text."""

    def _handler_raising(self, error):
        handler = LLMHandler()
        handler.load_model("gpt-5.4-nano", _API_KEY)

        mock_prompt = MagicMock()
        mock_chain = MagicMock()
        mock_chain.invoke.side_effect = error
        mock_prompt.__or__ = MagicMock(return_value=mock_chain)
        mock_chain.__or__ = MagicMock(return_value=mock_chain)
        return handler, mock_prompt

    def _invoke_expecting_value_error(self, error):
        handler, mock_prompt = self._handler_raising(error)
        with pytest.raises(ValueError) as excinfo:
            handler.invoke_model(mock_prompt, {"question": "Where is the dragon?"})
        return excinfo.value

    def test_authentication_error_becomes_value_error(self):
        err = self._invoke_expecting_value_error(
            _status_error(openai.AuthenticationError, 401)
        )
        assert str(err) == _AUTH_ERROR_MESSAGE

    def test_authentication_message_points_at_model_options(self):
        err = self._invoke_expecting_value_error(
            _status_error(openai.AuthenticationError, 401)
        )
        assert "Model Options" in str(err)

    def test_permission_denied_is_treated_as_a_key_problem(self):
        err = self._invoke_expecting_value_error(
            _status_error(openai.PermissionDeniedError, 403)
        )
        assert str(err) == _AUTH_ERROR_MESSAGE

    def test_rate_limit_error_becomes_value_error(self):
        err = self._invoke_expecting_value_error(
            _status_error(openai.RateLimitError, 429)
        )
        assert str(err) == _RATE_LIMIT_ERROR_MESSAGE

    def test_rate_limit_message_invites_a_retry(self):
        err = self._invoke_expecting_value_error(
            _status_error(openai.RateLimitError, 429)
        )
        assert "try again" in str(err).lower()

    def test_connection_error_becomes_value_error(self):
        err = self._invoke_expecting_value_error(
            openai.APIConnectionError(request=_REQUEST)
        )
        assert str(err) == _CONNECTION_ERROR_MESSAGE

    def test_timeout_is_treated_as_a_connection_problem(self):
        err = self._invoke_expecting_value_error(
            openai.APITimeoutError(request=_REQUEST)
        )
        assert str(err) == _CONNECTION_ERROR_MESSAGE

    def test_connection_message_mentions_connectivity(self):
        err = self._invoke_expecting_value_error(
            openai.APIConnectionError(request=_REQUEST)
        )
        assert "connection" in str(err).lower()

    def test_each_error_class_has_distinct_text(self):
        messages = {_AUTH_ERROR_MESSAGE, _RATE_LIMIT_ERROR_MESSAGE, _CONNECTION_ERROR_MESSAGE}
        assert len(messages) == 3

    def test_friendly_messages_carry_no_stack_trace_noise(self):
        for error in (
            _status_error(openai.AuthenticationError, 401),
            _status_error(openai.RateLimitError, 429),
            openai.APIConnectionError(request=_REQUEST),
        ):
            err = self._invoke_expecting_value_error(error)
            assert "Traceback" not in str(err)
            assert "openai." not in str(err)

    def test_original_error_is_kept_as_the_cause(self):
        original = _status_error(openai.AuthenticationError, 401)
        err = self._invoke_expecting_value_error(original)
        assert err.__cause__ is original

    def test_unrelated_errors_are_not_swallowed(self):
        handler, mock_prompt = self._handler_raising(RuntimeError("something else"))
        with pytest.raises(RuntimeError, match="something else"):
            handler.invoke_model(mock_prompt, {})


class TestMissingKeyMessage:
    def test_names_openai_and_model_options(self):
        assert "OpenAI" in missing_key_message()
        assert "Model Options" in missing_key_message()
