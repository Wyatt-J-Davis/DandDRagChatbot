"""Unit tests for LLMHandler — ChatOpenAI/ChatAnthropic are mocked in conftest."""
import types
import httpx
import anthropic
import openai
import pytest
from unittest.mock import MagicMock, patch

from src.utils.LLMHandler import (
    LLMHandler,
    PROVIDER_OPENAI,
    PROVIDER_ANTHROPIC,
    _AUTH_ERROR_MESSAGE,
    _CONNECTION_ERROR_MESSAGE,
    _MAX_CONTEXT_TOKENS,
    _RATE_LIMIT_ERROR_MESSAGE,
    _SUMMARY_MAX_PREDICT,
    _SUPPORTED_MODELS,
    _ANTHROPIC_AUTH_ERROR_MESSAGE,
    _ANTHROPIC_CONNECTION_ERROR_MESSAGE,
    _ANTHROPIC_RATE_LIMIT_ERROR_MESSAGE,
    missing_key_message,
)

_API_KEY = "sk-test-key"
_ANTHROPIC_KEY = "sk-ant-test-key"
_REQUEST = httpx.Request("POST", "https://api.openai.com/v1/chat/completions")
_ANTHROPIC_REQUEST = httpx.Request("POST", "https://api.anthropic.com/v1/messages")


def _status_error(cls, status_code):
    return cls("boom", response=httpx.Response(status_code, request=_REQUEST), body=None)


def _anthropic_status_error(cls, status_code):
    return cls("boom", response=httpx.Response(status_code, request=_ANTHROPIC_REQUEST), body=None)


def _fake_models_list(*ids):
    """A stand-in for anthropic.Anthropic().models.list() — an iterable of model
    objects each carrying an ``id``, in the API's returned order."""
    return [types.SimpleNamespace(id=i) for i in ids]


def _capture_chatanthropic_kwargs(handler, *args, **kwargs):
    """Run load_model with ChatAnthropic swapped for a recorder; return captured kwargs."""
    import src.utils.LLMHandler as llm_module
    calls = []
    original = llm_module.ChatAnthropic
    llm_module.ChatAnthropic = lambda **kw: calls.append(kw) or MagicMock()
    try:
        handler.load_model(*args, **kwargs)
    finally:
        llm_module.ChatAnthropic = original
    return calls


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


class TestProviderAwareModelListing:
    """The provider dimension: OpenAI returns its curated list through both the
    provider-aware getter and the stateless fetch, with no network call."""

    def test_get_available_models_accepts_provider(self):
        handler = LLMHandler()
        assert handler.get_available_models(PROVIDER_OPENAI) == list(_SUPPORTED_MODELS)

    def test_fetch_available_models_returns_curated_openai_list(self):
        handler = LLMHandler()
        assert handler.fetch_available_models(PROVIDER_OPENAI, "") == list(_SUPPORTED_MODELS)

    def test_fetch_available_models_needs_no_key_for_openai(self):
        handler = LLMHandler()
        # No key, and constructing/listing must not touch openai.
        assert handler.fetch_available_models(PROVIDER_OPENAI, None) == list(_SUPPORTED_MODELS)

    def test_fetch_available_models_returns_a_fresh_list(self):
        handler = LLMHandler()
        handler.fetch_available_models(PROVIDER_OPENAI, "").append("gpt-bogus")
        assert "gpt-bogus" not in handler.fetch_available_models(PROVIDER_OPENAI, "")

    def test_fetch_rejects_unknown_provider(self):
        handler = LLMHandler()
        with pytest.raises(ValueError):
            handler.fetch_available_models("Gemini", "key")


class TestLoadModelProvider:
    def test_load_model_accepts_openai_provider(self):
        handler = LLMHandler()
        handler.load_model("gpt-5.4-nano", _API_KEY, provider=PROVIDER_OPENAI)
        assert handler.provider == PROVIDER_OPENAI

    def test_load_model_still_builds_chatopenai_for_openai(self):
        handler = LLMHandler()
        calls = _capture_chatopenai_kwargs(handler, "gpt-5.4-mini", _API_KEY, provider=PROVIDER_OPENAI)
        assert calls[0]["model"] == "gpt-5.4-mini"
        assert calls[0]["api_key"] == _API_KEY

    def test_load_model_defaults_to_openai(self):
        handler = LLMHandler()
        handler.load_model("gpt-5.4-nano", _API_KEY)
        assert handler.provider == PROVIDER_OPENAI

    def test_load_model_rejects_unknown_provider(self):
        handler = LLMHandler()
        with pytest.raises(ValueError):
            handler.load_model("gpt-5.4-nano", _API_KEY, provider="Gemini")


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


class TestAnthropicFetchAvailableModels:
    """Anthropic's list is fetched live from the key via the SDK models endpoint."""

    def test_returns_model_ids_in_api_order(self):
        handler = LLMHandler()
        with patch("anthropic.Anthropic") as MockClient:
            MockClient.return_value.models.list.return_value = _fake_models_list(
                "claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5")
            models = handler.fetch_available_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY)
        assert models == ["claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5"]

    def test_threads_the_api_key_into_the_client(self):
        handler = LLMHandler()
        with patch("anthropic.Anthropic") as MockClient:
            MockClient.return_value.models.list.return_value = _fake_models_list("claude-opus-5")
            handler.fetch_available_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY)
        MockClient.assert_called_once_with(api_key=_ANTHROPIC_KEY)

    def test_empty_key_raises_before_any_network_call(self):
        handler = LLMHandler()
        with patch("anthropic.Anthropic") as MockClient:
            with pytest.raises(ValueError):
                handler.fetch_available_models(PROVIDER_ANTHROPIC, "")
        MockClient.assert_not_called()

    def test_auth_failure_becomes_friendly_value_error(self):
        handler = LLMHandler()
        with patch("anthropic.Anthropic") as MockClient:
            MockClient.return_value.models.list.side_effect = _anthropic_status_error(
                anthropic.AuthenticationError, 401)
            with pytest.raises(ValueError) as excinfo:
                handler.fetch_available_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY)
        assert "Anthropic" in str(excinfo.value)
        assert "Traceback" not in str(excinfo.value)

    def test_connection_failure_becomes_friendly_value_error(self):
        handler = LLMHandler()
        with patch("anthropic.Anthropic") as MockClient:
            MockClient.return_value.models.list.side_effect = anthropic.APIConnectionError(
                request=_ANTHROPIC_REQUEST)
            with pytest.raises(ValueError) as excinfo:
                handler.fetch_available_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY)
        assert "Anthropic" in str(excinfo.value)


class TestAnthropicLoadModel:
    def test_builds_chatanthropic_for_anthropic_provider(self):
        handler = LLMHandler()
        calls = _capture_chatanthropic_kwargs(
            handler, "claude-opus-5", _ANTHROPIC_KEY, provider=PROVIDER_ANTHROPIC)
        assert calls[0]["model"] == "claude-opus-5"
        assert calls[0]["api_key"] == _ANTHROPIC_KEY

    def test_sets_provider_to_anthropic(self):
        handler = LLMHandler()
        _capture_chatanthropic_kwargs(
            handler, "claude-opus-5", _ANTHROPIC_KEY, provider=PROVIDER_ANTHROPIC)
        assert handler.provider == PROVIDER_ANTHROPIC

    def test_accepts_any_model_id_no_curated_check(self):
        # Anthropic's list is dynamic, so load must not reject ids outside a hardcoded set.
        handler = LLMHandler()
        calls = _capture_chatanthropic_kwargs(
            handler, "some-future-claude", _ANTHROPIC_KEY, provider=PROVIDER_ANTHROPIC)
        assert calls[0]["model"] == "some-future-claude"

    def test_rejects_missing_api_key(self):
        handler = LLMHandler()
        with pytest.raises(ValueError, match="[Aa]nthropic"):
            handler.load_model("claude-opus-5", "", provider=PROVIDER_ANTHROPIC)

    def test_disable_thinking_sets_max_tokens_cap(self):
        handler = LLMHandler()
        calls = _capture_chatanthropic_kwargs(
            handler, "claude-opus-5", _ANTHROPIC_KEY, disable_thinking=True,
            provider=PROVIDER_ANTHROPIC)
        assert calls[0]["max_tokens"] == _SUMMARY_MAX_PREDICT

    def test_disable_thinking_passes_no_thinking_config(self):
        # Relies on ChatAnthropic's thinking-off default; no reasoning_effort/thinking kwargs.
        handler = LLMHandler()
        calls = _capture_chatanthropic_kwargs(
            handler, "claude-opus-5", _ANTHROPIC_KEY, disable_thinking=True,
            provider=PROVIDER_ANTHROPIC)
        assert "thinking" not in calls[0]
        assert "reasoning_effort" not in calls[0]

    def test_default_load_does_not_cap_tokens(self):
        handler = LLMHandler()
        calls = _capture_chatanthropic_kwargs(
            handler, "claude-opus-5", _ANTHROPIC_KEY, provider=PROVIDER_ANTHROPIC)
        assert "max_tokens" not in calls[0]


class TestAnthropicProviderModelListing:
    def test_get_available_models_accepts_anthropic(self):
        handler = LLMHandler()
        # With no fetched list yet, Anthropic reports an empty list (needs a key).
        assert handler.get_available_models(PROVIDER_ANTHROPIC) == []

    def test_get_context_tokens_flat_for_anthropic_model(self):
        handler = LLMHandler()
        assert handler.get_context_tokens("claude-opus-5") == _MAX_CONTEXT_TOKENS

    def test_is_thinking_model_true_for_anthropic_model(self):
        handler = LLMHandler()
        assert handler.is_thinking_model("claude-opus-5") is True


class TestAnthropicInvokeModelErrorTranslation:
    """Raw anthropic failures must become provider-named ValueErrors."""

    def _handler_raising(self, error):
        handler = LLMHandler()
        _capture_chatanthropic_kwargs(
            handler, "claude-opus-5", _ANTHROPIC_KEY, provider=PROVIDER_ANTHROPIC)
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

    def test_authentication_error_becomes_anthropic_message(self):
        err = self._invoke_expecting_value_error(
            _anthropic_status_error(anthropic.AuthenticationError, 401))
        assert str(err) == _ANTHROPIC_AUTH_ERROR_MESSAGE

    def test_permission_denied_is_treated_as_key_problem(self):
        err = self._invoke_expecting_value_error(
            _anthropic_status_error(anthropic.PermissionDeniedError, 403))
        assert str(err) == _ANTHROPIC_AUTH_ERROR_MESSAGE

    def test_rate_limit_error_becomes_anthropic_message(self):
        err = self._invoke_expecting_value_error(
            _anthropic_status_error(anthropic.RateLimitError, 429))
        assert str(err) == _ANTHROPIC_RATE_LIMIT_ERROR_MESSAGE

    def test_connection_error_becomes_anthropic_message(self):
        err = self._invoke_expecting_value_error(
            anthropic.APIConnectionError(request=_ANTHROPIC_REQUEST))
        assert str(err) == _ANTHROPIC_CONNECTION_ERROR_MESSAGE

    def test_timeout_is_treated_as_connection_problem(self):
        err = self._invoke_expecting_value_error(
            anthropic.APITimeoutError(request=_ANTHROPIC_REQUEST))
        assert str(err) == _ANTHROPIC_CONNECTION_ERROR_MESSAGE

    def test_anthropic_messages_name_the_provider(self):
        for msg in (_ANTHROPIC_AUTH_ERROR_MESSAGE, _ANTHROPIC_RATE_LIMIT_ERROR_MESSAGE,
                    _ANTHROPIC_CONNECTION_ERROR_MESSAGE):
            assert "Anthropic" in msg


class TestMissingKeyMessage:
    def test_names_openai_by_default(self):
        assert "OpenAI" in missing_key_message(PROVIDER_OPENAI)
        assert "Model Options" in missing_key_message(PROVIDER_OPENAI)

    def test_names_anthropic_when_active(self):
        assert "Anthropic" in missing_key_message(PROVIDER_ANTHROPIC)
        assert "Model Options" in missing_key_message(PROVIDER_ANTHROPIC)
