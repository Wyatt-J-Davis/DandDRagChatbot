import openai
import anthropic
from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic
from langchain.schema.output_parser import StrOutputParser

# The provider dimension.  OpenAI and Anthropic are both wired up; a third
# provider slots in behind this same seam without the pages having to branch.
PROVIDER_OPENAI = "OpenAI"
PROVIDER_ANTHROPIC = "Anthropic"

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

# The key is never validated up front for OpenAI, so the first real call is
# where a bad key, a throttle, or a dead network shows up.  These are the only
# forms of those failures the user ever sees.
_AUTH_ERROR_MESSAGE = (
    "Your OpenAI API key was rejected. Please check your key in Model Options."
)
_RATE_LIMIT_ERROR_MESSAGE = (
    "OpenAI is rate limiting requests right now. Please wait a moment and try again."
)
_CONNECTION_ERROR_MESSAGE = (
    "Could not reach OpenAI. Please check your internet connection and try again."
)

# Anthropic's parallel set.  The SDKs share exception class names, so the only
# difference from the OpenAI strings is the provider name.
_ANTHROPIC_AUTH_ERROR_MESSAGE = (
    "Your Anthropic API key was rejected. Please check your key in Model Options."
)
_ANTHROPIC_RATE_LIMIT_ERROR_MESSAGE = (
    "Anthropic is rate limiting requests right now. Please wait a moment and try again."
)
_ANTHROPIC_CONNECTION_ERROR_MESSAGE = (
    "Could not reach Anthropic. Please check your internet connection and try again."
)

# invoke_model's friendly-error translation is provider-aware: it looks up the
# message set belonging to the provider the loaded model came from.  A new
# provider adds its own set here without touching the translation logic.
_ERROR_MESSAGES = {
    PROVIDER_OPENAI: {
        "auth": _AUTH_ERROR_MESSAGE,
        "rate_limit": _RATE_LIMIT_ERROR_MESSAGE,
        "connection": _CONNECTION_ERROR_MESSAGE,
    },
    PROVIDER_ANTHROPIC: {
        "auth": _ANTHROPIC_AUTH_ERROR_MESSAGE,
        "rate_limit": _ANTHROPIC_RATE_LIMIT_ERROR_MESSAGE,
        "connection": _ANTHROPIC_CONNECTION_ERROR_MESSAGE,
    },
}


def missing_key_message(provider=PROVIDER_OPENAI):
    """Provider-named prompt shown by every page that gates an action behind the
    session key, so the instruction stays identical wherever the user runs into
    it and always names the backend they selected."""
    name = provider if provider in _ERROR_MESSAGES else PROVIDER_OPENAI
    return (
        f"🔑 Enter your {name} API key in **Model Options** on the sidebar to enable "
        "chat and campaign summaries. Uploading notes does not require a key."
    )


# Back-compat constant for the OpenAI wording; pages call missing_key_message()
# so the banner names the active provider.
MISSING_KEY_MESSAGE = missing_key_message(PROVIDER_OPENAI)


class LLMHandler:
    def __init__(self):
        self.currnet_model = None
        self.availble_models = list(_SUPPORTED_MODELS)
        # The Anthropic list is fetched live from the key; the app owns caching
        # across reruns, so a fresh handler starts with no known Anthropic models.
        self.anthropic_models = []
        # Tracks which provider the loaded model belongs to so invoke_model can
        # translate failures into that provider's wording.
        self.provider = PROVIDER_OPENAI

    def get_available_models(self, provider=PROVIDER_OPENAI):
        """Return the models currently known for *provider*.

        For OpenAI this is the curated hardcoded list, needing no key and no
        network call.  For Anthropic it is whatever list this handler has been
        given for the current run (empty until a key fetches one).
        """
        if provider == PROVIDER_ANTHROPIC:
            return list(self.anthropic_models)
        return self.availble_models

    def fetch_available_models(self, provider, api_key):
        """Return the model list for *provider*, stateless (the app owns caching).

        For OpenAI the curated list is returned with no network call, so a key
        is not required.  For Anthropic the SDK models-list endpoint is called
        with the key; failures surface as a friendly, provider-named ValueError.
        """
        if provider == PROVIDER_OPENAI:
            return list(_SUPPORTED_MODELS)
        if provider == PROVIDER_ANTHROPIC:
            if not api_key:
                raise ValueError(
                    "No Anthropic API key provided. Please enter your API key in Model Options."
                )
            messages = _ERROR_MESSAGES[PROVIDER_ANTHROPIC]
            try:
                client = anthropic.Anthropic(api_key=api_key)
                return [model.id for model in client.models.list()]
            except (anthropic.AuthenticationError, anthropic.PermissionDeniedError) as e:
                raise ValueError(messages["auth"]) from e
            except anthropic.RateLimitError as e:
                raise ValueError(messages["rate_limit"]) from e
            except anthropic.APIConnectionError as e:
                raise ValueError(messages["connection"]) from e
        raise ValueError(f"Provider {provider} is not supported.")

    def is_thinking_model(self, model_name):
        """Return True if *model_name* has thinking/reasoning capability.

        Every model offered by either provider is a reasoning model.
        """
        return True

    def get_context_tokens(self, model_name):
        """Return the effective context size (tokens) to use for *model_name*."""
        return _MAX_CONTEXT_TOKENS

    def load_model(self, model_name, api_key, disable_thinking=False, provider=PROVIDER_OPENAI):
        if provider == PROVIDER_OPENAI:
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
                kwargs["reasoning_effort"] = "minimal"
                kwargs["max_completion_tokens"] = _SUMMARY_MAX_PREDICT
            self.currnet_model = ChatOpenAI(**kwargs)
            self.provider = provider
        elif provider == PROVIDER_ANTHROPIC:
            # The Anthropic list is dynamic, so there is no curated set to
            # validate against; the model id comes straight from the fetched list.
            if not api_key:
                raise ValueError("No Anthropic API key provided. Please enter your API key in Model Options.")
            kwargs = {"model": model_name, "api_key": api_key}
            if disable_thinking:
                # A hard max_tokens cap bounds cost and latency across every model
                # the dropdown might list (including ones that reject an explicit
                # thinking-off).  No thinking config is passed: ChatAnthropic's
                # default is thinking-off, so the cap alone keeps the map-reduce
                # from hanging or running up huge bills.
                kwargs["max_tokens"] = _SUMMARY_MAX_PREDICT
            self.currnet_model = ChatAnthropic(**kwargs)
            self.provider = provider
        else:
            raise ValueError(f"Provider {provider} is not supported.")

    def invoke_model(self, prompt, mappings):
        if self.currnet_model is None:
            raise ValueError("No model loaded. Please load a model before invoking.")

        messages = _ERROR_MESSAGES.get(self.provider, _ERROR_MESSAGES[PROVIDER_OPENAI])
        chain = (
            prompt
            | self.currnet_model
            | StrOutputParser()
        )
        try:
            return chain.invoke(mappings)
        except (openai.AuthenticationError, openai.PermissionDeniedError,
                anthropic.AuthenticationError, anthropic.PermissionDeniedError) as e:
            raise ValueError(messages["auth"]) from e
        except (openai.RateLimitError, anthropic.RateLimitError) as e:
            raise ValueError(messages["rate_limit"]) from e
        except (openai.APIConnectionError, anthropic.APIConnectionError) as e:
            # APITimeoutError subclasses this in both SDKs, so timeouts read as
            # connectivity too.
            raise ValueError(messages["connection"]) from e
