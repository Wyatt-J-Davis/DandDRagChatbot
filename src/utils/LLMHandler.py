from langchain_ollama import OllamaLLM
from langchain.schema.output_parser import StrOutputParser
import ollama

# Cap context to a value that fits comfortably in consumer RAM for 3B-class models.
# Ollama's runtime default num_ctx can be far smaller than the model's declared
# training context (e.g. 2048 vs 131072 for llama3.2), which silently truncates
# large inputs.  Explicitly setting num_ctx to this cap overrides that default
# while keeping KV-cache memory manageable (~1.75 GB for llama3.2 3B).
_MAX_CONTEXT_TOKENS = 16384

# Summarization tasks use a bounded output budget to prevent thinking models from
# generating unbounded reasoning traces that cause the summarizer to hang.
_SUMMARY_MAX_PREDICT = 4096


class LLMHandler:
    def __init__(self):
        self.currnet_model = None
        self.availble_models = ollama.list().models

    def get_available_models(self):
        return self.availble_models

    def is_thinking_model(self, model_name):
        """Return True if *model_name* has thinking/reasoning capability per Ollama."""
        try:
            info = ollama.show(model_name)
            caps = getattr(info, "capabilities", None)
            if caps:
                return "thinking" in caps
        except Exception:
            pass
        return False

    def get_context_tokens(self, model_name):
        """Return the effective context size (tokens) to use for *model_name*.

        Reads the model's declared context length from Ollama and clamps it to
        _MAX_CONTEXT_TOKENS so the KV cache stays within practical RAM limits.
        Falls back to 4096 if the query fails.
        """
        context_tokens = 4096
        try:
            info = ollama.show(model_name)
            if hasattr(info, "modelinfo") and info.modelinfo:
                for key in ("llama.context_length", "context_length"):
                    if key in info.modelinfo:
                        context_tokens = int(info.modelinfo[key])
                        break
        except Exception:
            pass
        return min(context_tokens, _MAX_CONTEXT_TOKENS)

    def load_model(self, model_name, model_temperature, disable_thinking=False):
        temp_model = self.currnet_model
        for item in self.availble_models:
            if item['model'] == model_name:
                num_ctx = self.get_context_tokens(model_name)
                kwargs = dict(
                    model=model_name,
                    temperature=model_temperature,
                    num_predict=-1,
                    num_ctx=num_ctx,
                )
                if disable_thinking:
                    kwargs["num_predict"] = _SUMMARY_MAX_PREDICT
                    if self.is_thinking_model(model_name):
                        kwargs["reasoning"] = False
                self.currnet_model = OllamaLLM(**kwargs)
        if self.currnet_model == temp_model:
            raise ValueError(f"Model {model_name} not found in local ollama list. Please select an installed model or download it.")

    def invoke_model(self, prompt, mappings):
        if self.currnet_model is not None:
            chain = (
                prompt
                | self.currnet_model
                | StrOutputParser()
            )
            return chain.invoke(mappings)
        else:
            raise ValueError("No model loaded. Please load a model before invoking.")
