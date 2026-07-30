"""Shared, Streamlit-free model/key logic for the chat and summary pages.

Both `TTRPGChatbot` and `CampaignSummarizer` render their "Model Options" out of
this one module so the two pages can't drift apart the way their duplicated key
fields already could.  The module is pure: it takes (key, persisted model) and
returns data.  The pages keep only the widget wiring.

OpenAI is the only backend: the model list is curated, keyless, and validated
immediately.
"""
from . import LLMHandler

# Session-state slot holding the OpenAI API key.
KEY_SLOT = "openai_api_key"
KEY_LABEL = "OpenAI API Key"


class ModelOptions:
    def __init__(self, llm_handler):
        self._llm = llm_handler

    def known_models(self):
        """Curated list a persisted choice is validated against (no key, no
        network)."""
        return self._llm.get_available_models()

    def resolve_models(self, api_key):
        """Return ``(models, error)`` for the model dropdown.

        The curated list is returned immediately, with no key and no network
        call, so *error* is always ``None``.
        """
        try:
            models = self._llm.fetch_available_models(api_key)
            error = None
        except ValueError as e:
            models, error = [], str(e)
        return models, error

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
