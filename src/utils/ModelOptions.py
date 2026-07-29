"""Shared, Streamlit-free provider/key/model logic for the chat and summary pages.

Both `TTRPGChatbot` and `CampaignSummarizer` render their "Model Options" out of
this one module so the two pages can't drift apart the way their duplicated key
fields already could.  The module is pure: it takes (provider, keys, persisted
model, model-list cache) and returns data.  The pages keep only the widget wiring
and the session-state cache dict.

Today only the OpenAI path is exercised (curated list, keyless, immediate
validation).  A second provider slots in by extending the routing tables and the
`resolve_models` fetch branch, without the pages having to change.
"""
from . import LLMHandler

PROVIDER_OPENAI = LLMHandler.PROVIDER_OPENAI

# Providers offered in the selector.  OpenAI is the only selectable entry today.
SUPPORTED_PROVIDERS = [PROVIDER_OPENAI]

# OpenAI stays the fresh-install default so first-run UX is unchanged.
DEFAULT_PROVIDER = PROVIDER_OPENAI

# Each provider's key lives in its own session slot so switching providers never
# erases the key entered for the other one.
_KEY_SLOTS = {PROVIDER_OPENAI: "openai_api_key"}


class ModelOptions:
    def __init__(self, llm_handler):
        self._llm = llm_handler

    @staticmethod
    def providers():
        return list(SUPPORTED_PROVIDERS)

    @staticmethod
    def default_provider():
        return DEFAULT_PROVIDER

    @staticmethod
    def normalize_provider(provider):
        """Coerce an unknown/absent provider back to the default."""
        return provider if provider in SUPPORTED_PROVIDERS else DEFAULT_PROVIDER

    @staticmethod
    def key_slot(provider):
        """Session-state key name holding *provider*'s API key."""
        return _KEY_SLOTS.get(provider, _KEY_SLOTS[DEFAULT_PROVIDER])

    @staticmethod
    def key_label(provider):
        """Label for the key text field, named after the active provider."""
        return f"{ModelOptions.normalize_provider(provider)} API Key"

    def known_models(self, provider):
        """Models to validate a persisted choice against — curated for OpenAI,
        needing no key and no network."""
        return self._llm.get_available_models(provider)

    def resolve_models(self, provider, api_key, cache):
        """Return ``(models, error, cache)`` for the model dropdown.

        For OpenAI the curated list is returned immediately, with no key and no
        network call, so *error* is always ``None`` and *cache* is untouched.
        The cache is threaded through unchanged so a provider that fetches its
        list from the key (and must cache it across reruns) can be added here
        without changing either page's call site.
        """
        cache = cache if cache is not None else {}
        try:
            models = self._llm.fetch_available_models(provider, api_key)
            error = None
        except ValueError as e:
            models, error = [], str(e)
        return models, error, cache

    def validate_persisted_model(self, model_name, models):
        """Return ``(model_or_None, warning_or_None)`` for a restored model.

        A model still offered is kept; one that is gone is dropped with a
        reselect prompt.  ``None`` (nothing persisted) passes through cleanly.
        """
        if model_name is None or model_name in models:
            return model_name, None
        return None, (
            f"Previously selected model '{model_name}' is no longer offered. "
            "Please select a model in Model Options."
        )

    @staticmethod
    def preselect_index(model_name, models):
        """Index of the persisted model, else 0 (cheapest/first) as the default."""
        if model_name in models:
            return models.index(model_name)
        return 0
