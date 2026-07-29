"""Shared, Streamlit-free provider/key/model logic for the chat and summary pages.

Both `TTRPGChatbot` and `CampaignSummarizer` render their "Model Options" out of
this one module so the two pages can't drift apart the way their duplicated key
fields already could.  The module is pure: it takes (provider, keys, persisted
model, model-list cache) and returns data.  The pages keep only the widget wiring
and the session-state cache dict.

OpenAI uses a curated, keyless, immediately-validated list.  Anthropic fetches
its list live from the key: the list is empty until a valid key is present,
session-cached and refetched only when the key changes, and a restored model is
validated lazily once that list is available.
"""
from . import LLMHandler

PROVIDER_OPENAI = LLMHandler.PROVIDER_OPENAI
PROVIDER_ANTHROPIC = LLMHandler.PROVIDER_ANTHROPIC

# Providers offered in the selector.
SUPPORTED_PROVIDERS = [PROVIDER_OPENAI, PROVIDER_ANTHROPIC]

# OpenAI stays the fresh-install default so first-run UX is unchanged.
DEFAULT_PROVIDER = PROVIDER_OPENAI

# Each provider's key lives in its own session slot so switching providers never
# erases the key entered for the other one.
_KEY_SLOTS = {
    PROVIDER_OPENAI: "openai_api_key",
    PROVIDER_ANTHROPIC: "anthropic_api_key",
}

# Where the Anthropic fetched list is parked inside the app-owned cache dict.
_ANTHROPIC_CACHE_KEY = "anthropic"


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
        """Models to validate a persisted choice against — curated for OpenAI
        (no key, no network); the currently-known list for Anthropic."""
        return self._llm.get_available_models(provider)

    def resolve_models(self, provider, api_key, cache):
        """Return ``(models, error, cache)`` for the model dropdown.

        For OpenAI the curated list is returned immediately, with no key and no
        network call, so *error* is always ``None`` and *cache* is untouched.
        For Anthropic the list is empty until a key is present, otherwise it is
        fetched from the key and cached; a failed fetch surfaces a readable,
        provider-named *error* string (de-facto early key validation).
        """
        cache = cache if cache is not None else {}
        if provider == PROVIDER_ANTHROPIC:
            return self._resolve_anthropic(api_key, cache)
        try:
            models = self._llm.fetch_available_models(provider, api_key)
            error = None
        except ValueError as e:
            models, error = [], str(e)
        return models, error, cache

    def _resolve_anthropic(self, api_key, cache):
        # Empty/disabled until a key is entered; the page shows the hint.
        if not api_key:
            return [], None, cache
        entry = cache.get(_ANTHROPIC_CACHE_KEY)
        # Refetch only when the key value changes, not on every rerun.
        if entry is not None and entry.get("key") == api_key:
            return list(entry.get("models", [])), entry.get("error"), cache
        try:
            models = self._llm.fetch_available_models(PROVIDER_ANTHROPIC, api_key)
            error = None
        except ValueError as e:
            models, error = [], str(e)
        cache[_ANTHROPIC_CACHE_KEY] = {"key": api_key, "models": list(models), "error": error}
        return list(models), error, cache

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

    def validate_persisted_model_deferred(self, model_name, models):
        """Validate a restored model only once its list is actually available.

        An empty *models* means the list has not been fetched yet (e.g. Anthropic
        with no key): the model is kept optimistically with no warning.  Once the
        list is available it is validated like the immediate path, so a saved
        model the key can no longer use is dropped with the reselect prompt.
        """
        if not models:
            return model_name, None
        return self.validate_persisted_model(model_name, models)

    @staticmethod
    def preselect_index(model_name, models):
        """Index of the persisted model, else 0 (cheapest/first) as the default."""
        if model_name in models:
            return models.index(model_name)
        return 0
