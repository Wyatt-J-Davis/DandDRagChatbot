"""Unit tests for LLMHandler — ollama and OllamaLLM are mocked in conftest."""
import pytest
from unittest.mock import MagicMock, patch

from src.utils.LLMHandler import LLMHandler, _MAX_CONTEXT_TOKENS


def _make_model(name: str) -> MagicMock:
    m = MagicMock()
    m.model = name
    m.__getitem__ = lambda self, key: name if key == "model" else None
    return m


class TestGetAvailableModels:
    def test_returns_list_from_ollama(self):
        handler = LLMHandler()
        models = handler.get_available_models()
        # conftest sets one model: "llama3:latest"
        assert len(models) == 1
        assert models[0].model == "llama3:latest"


class TestGetContextTokens:
    def test_returns_declared_context_when_below_cap(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        mock_info = MagicMock()
        mock_info.modelinfo = {"llama.context_length": 4096}
        with patch.object(llm_module.ollama, "show", return_value=mock_info):
            result = handler.get_context_tokens("some-model")
        assert result == 4096

    def test_clamps_to_max_when_declared_context_is_large(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        mock_info = MagicMock()
        mock_info.modelinfo = {"llama.context_length": 131072}
        with patch.object(llm_module.ollama, "show", return_value=mock_info):
            result = handler.get_context_tokens("some-model")
        assert result == _MAX_CONTEXT_TOKENS

    def test_returns_default_when_ollama_show_raises(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        with patch.object(llm_module.ollama, "show", side_effect=Exception("API error")):
            result = handler.get_context_tokens("some-model")
        assert result == 4096


class TestIsThinkingModel:
    def test_returns_true_when_thinking_in_capabilities(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        mock_info = MagicMock()
        mock_info.capabilities = ["completion", "thinking", "tools"]
        with patch.object(llm_module.ollama, "show", return_value=mock_info):
            assert handler.is_thinking_model("qwen3:9b") is True

    def test_returns_false_when_thinking_not_in_capabilities(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        mock_info = MagicMock()
        mock_info.capabilities = ["completion", "tools"]
        with patch.object(llm_module.ollama, "show", return_value=mock_info):
            assert handler.is_thinking_model("llama3:latest") is False

    def test_returns_false_when_capabilities_is_none(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        mock_info = MagicMock()
        mock_info.capabilities = None
        with patch.object(llm_module.ollama, "show", return_value=mock_info):
            assert handler.is_thinking_model("some-model") is False

    def test_returns_false_on_exception(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        with patch.object(llm_module.ollama, "show", side_effect=Exception("API error")):
            assert handler.is_thinking_model("some-model") is False


class TestLoadModel:
    def test_raises_value_error_for_unknown_model(self):
        handler = LLMHandler()
        with pytest.raises(ValueError, match="not found"):
            handler.load_model("nonexistent:model", 0.7)

    def test_loads_known_model_successfully(self):
        handler = LLMHandler()
        handler.load_model("llama3:latest", 0.5)
        assert handler.currnet_model is not None

    def test_current_model_is_none_before_load(self):
        handler = LLMHandler()
        assert handler.currnet_model is None

    def test_loading_sets_current_model_to_non_none(self):
        handler = LLMHandler()
        assert handler.currnet_model is None
        handler.load_model("llama3:latest", 0.7)
        assert handler.currnet_model is not None

    def test_load_model_sets_num_predict_unlimited_and_explicit_num_ctx(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        calls = []
        original = llm_module.OllamaLLM
        llm_module.OllamaLLM = lambda **kw: calls.append(kw) or MagicMock()
        try:
            handler.load_model("llama3:latest", 0.7)
        finally:
            llm_module.OllamaLLM = original
        assert calls
        assert calls[0].get("num_predict") == -1
        assert "num_ctx" in calls[0]


class TestLoadModelDisableThinking:
    def _capture_ollama_calls(self, handler, disable_thinking, is_thinking_return):
        import src.utils.LLMHandler as llm_module
        calls = []
        original = llm_module.OllamaLLM
        llm_module.OllamaLLM = lambda **kw: calls.append(kw) or MagicMock()
        try:
            with patch.object(handler, "is_thinking_model", return_value=is_thinking_return):
                handler.load_model("llama3:latest", 0.7, disable_thinking=disable_thinking)
        finally:
            llm_module.OllamaLLM = original
        return calls

    def test_disable_thinking_caps_num_predict(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        calls = self._capture_ollama_calls(handler, disable_thinking=True, is_thinking_return=False)
        assert calls[0].get("num_predict") == llm_module._SUMMARY_MAX_PREDICT

    def test_disable_thinking_sets_reasoning_false_for_thinking_model(self):
        handler = LLMHandler()
        calls = self._capture_ollama_calls(handler, disable_thinking=True, is_thinking_return=True)
        assert calls[0].get("reasoning") is False

    def test_disable_thinking_does_not_set_reasoning_for_non_thinking_model(self):
        handler = LLMHandler()
        calls = self._capture_ollama_calls(handler, disable_thinking=True, is_thinking_return=False)
        assert "reasoning" not in calls[0]

    def test_default_leaves_num_predict_unlimited_and_no_reasoning(self):
        import src.utils.LLMHandler as llm_module
        handler = LLMHandler()
        calls = []
        original = llm_module.OllamaLLM
        llm_module.OllamaLLM = lambda **kw: calls.append(kw) or MagicMock()
        try:
            handler.load_model("llama3:latest", 0.7)
        finally:
            llm_module.OllamaLLM = original
        assert calls[0].get("num_predict") == -1
        assert "reasoning" not in calls[0]


class TestInvokeModel:
    def test_raises_when_no_model_loaded(self):
        handler = LLMHandler()
        mock_prompt = MagicMock()
        with pytest.raises(ValueError, match="No model loaded"):
            handler.invoke_model(mock_prompt, {})

    def test_invokes_chain_with_mappings(self):
        handler = LLMHandler()
        handler.load_model("llama3:latest", 0.7)

        mock_prompt = MagicMock()
        mock_chain = MagicMock()
        mock_chain.invoke.return_value = "The dragon appeared at dawn."

        mock_prompt.__or__ = MagicMock(return_value=mock_chain)
        mock_chain.__or__ = MagicMock(return_value=mock_chain)

        result = handler.invoke_model(mock_prompt, {"question": "Where is the dragon?"})
        assert result == "The dragon appeared at dawn."
        mock_chain.invoke.assert_called_once_with({"question": "Where is the dragon?"})
