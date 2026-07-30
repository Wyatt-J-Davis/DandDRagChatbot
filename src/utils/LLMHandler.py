import openai
from langchain_openai import ChatOpenAI
from langchain.schema.output_parser import StrOutputParser

# Curated list of supported OpenAI models, cheapest first.  Verified against
# OpenAI's published pricing page so the app can never send a model id that
# 404s.  The first entry is the default offered to the user.
_SUPPORTED_MODELS = ["gpt-5.4-nano", "gpt-5.4-mini", "gpt-5.4"]

# Cap the context budget used for chunk sizing.  Kept at the previous value so
# the summarizer's char-based chunking behaviour is unchanged.
_MAX_CONTEXT_TOKENS = 16384

# Summarization tasks use a bounded output budget to prevent reasoning models
# from generating unbounded traces that cause the summarizer to hang.
_SUMMARY_MAX_PREDICT = 4096

# The key is never validated up front, so the first real call is where a bad
# key, a throttle, or a dead network shows up.  These are the only forms of
# those failures the user ever sees.
_AUTH_ERROR_MESSAGE = (
    "Your OpenAI API key was rejected. Please check your key in Model Options."
)
_RATE_LIMIT_ERROR_MESSAGE = (
    "OpenAI is rate limiting requests right now. Please wait a moment and try again."
)
_CONNECTION_ERROR_MESSAGE = (
    "Could not reach OpenAI. Please check your internet connection and try again."
)


def translate_openai_error(exc):
    """Return the app's friendly message for a raw OpenAI SDK error, or None.

    Shared by the chat path (invoke_model) and the embedding path
    (DatabaseHandler) so a rejected key, a throttle, or a dead network reads the
    same wherever it surfaces.
    """
    if isinstance(exc, (openai.AuthenticationError, openai.PermissionDeniedError)):
        return _AUTH_ERROR_MESSAGE
    if isinstance(exc, openai.RateLimitError):
        return _RATE_LIMIT_ERROR_MESSAGE
    if isinstance(exc, openai.APIConnectionError):
        return _CONNECTION_ERROR_MESSAGE
    return None


def missing_key_message():
    """Prompt shown by every page that gates an action behind the session key,
    so the instruction stays identical wherever the user runs into it."""
    return (
        "🔑 Enter your OpenAI API key in **Model Options** on the sidebar to enable "
        "chat, campaign summaries, and note uploads."
    )


MISSING_KEY_MESSAGE = missing_key_message()


class LLMHandler:
    def __init__(self):
        self.currnet_model = None
        self.availble_models = list(_SUPPORTED_MODELS)

    def get_available_models(self):
        """Return the curated OpenAI model list — no key, no network call."""
        return self.availble_models

    def fetch_available_models(self, api_key=""):
        """Return the curated model list; stateless and keyless (the app owns
        caching).  Kept as a method so the model-options layer has a single
        source for the list."""
        return list(_SUPPORTED_MODELS)

    def is_thinking_model(self, model_name):
        """Return True if *model_name* has thinking/reasoning capability.

        Every supported model is a reasoning model.
        """
        return True

    def get_context_tokens(self, model_name):
        """Return the effective context size (tokens) to use for *model_name*."""
        return _MAX_CONTEXT_TOKENS

    def load_model(self, model_name, api_key, disable_thinking=False):
        if model_name not in _SUPPORTED_MODELS:
            raise ValueError(f"Model {model_name} is not supported. Please select one of: {', '.join(_SUPPORTED_MODELS)}.")
        if not api_key:
            raise ValueError("No OpenAI API key provided. Please enter your API key in Model Options.")
        kwargs = {"model": model_name, "api_key": api_key}
        if disable_thinking:
            # Every supported model is a reasoning model, so an unconstrained
            # call can emit an unbounded reasoning trace and stall the
            # summarizer.  Minimal effort plus a hard output cap keeps each
            # map-reduce step terminating (and billable) within known bounds.
            kwargs["reasoning_effort"] = "low"
            kwargs["max_completion_tokens"] = _SUMMARY_MAX_PREDICT
        self.currnet_model = ChatOpenAI(**kwargs)

    def invoke_model(self, prompt, mappings):
        if self.currnet_model is None:
            raise ValueError("No model loaded. Please load a model before invoking.")

        chain = (
            prompt
            | self.currnet_model
            | StrOutputParser()
        )
        try:
            return chain.invoke(mappings)
        except Exception as e:
            message = translate_openai_error(e)
            if message:
                raise ValueError(message) from e
            raise
