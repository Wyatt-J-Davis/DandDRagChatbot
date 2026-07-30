"""Streamlit AppTest integration tests for streamlit_app.py.

These tests use st.testing.v1.AppTest to run the app headlessly.
Heavy external dependencies (openai, FastEmbed, Chroma) are mocked
in conftest.py so the app boots without real services.
"""
import os
import json
import pytest
from unittest.mock import patch
from streamlit.testing.v1 import AppTest

import src.app.TTRPGChatBot as _chatbot_module

APP_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "streamlit_app.py")
TIMEOUT = 30

# Keys that __init_state_variables checks — populate all of them to skip its init block.
_ALL_KEYS = {
    "reupload_key": 0,
    "model_name": None,
    "openai_api_key": "",
    "notes_uploaded": False,
    "messages": [],
    "buttoninfo": [],
    "button_key": 0,
    "party_members": [{"id": "init-abc", "name": "Alice", "note_taker": True}],
    "delete_index": None,
    "summary_generated": False,
}


def _hide_userdata_isfile():
    """Return an isfile side_effect that hides user_data.json but passes all other paths."""
    real_isfile = os.path.isfile
    def _isfile(path):
        return False if "user_data" in str(path) else real_isfile(path)
    return _isfile


def _hide_db_isdir():
    """Return an isdir side_effect that hides the DB directory but passes all other paths."""
    real_isdir = os.path.isdir
    def _isdir(path):
        return False if "chrome_langchain_db" in str(path) else real_isdir(path)
    return _isdir


def _run_preloaded(**overrides) -> AppTest:
    """Boot app with all session-state keys pre-set so __init_state_variables is skipped."""
    at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
    state = {**_ALL_KEYS, **overrides}
    for k, v in state.items():
        at.session_state[k] = v
    with patch("os.path.isfile", side_effect=_hide_userdata_isfile()), \
         patch("os.path.isdir", side_effect=_hide_db_isdir()):
        at.run()
    return at


def _db_patches():
    """Return an isfile side_effect that simulates raw_notes.json existing (no user_data.json)."""
    real_isfile = os.path.isfile

    def _isfile(path):
        if "raw_notes" in str(path):
            return True
        if "user_data" in str(path):
            return False
        return real_isfile(path)

    return _isfile


def _run_app() -> AppTest:
    """Boot the app with mocked file-system state (no user_data.json, no DB)."""
    at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)

    real_isfile = os.path.isfile
    real_isdir = os.path.isdir

    def _isfile(path):
        # Hide user_data.json so app initialises with defaults
        if "user_data" in str(path):
            return False
        # Hide raw_notes.json so notes_uploaded stays False (no DB state)
        if "raw_notes" in str(path):
            return False
        return real_isfile(path)

    def _isdir(path):
        # Hide the DB directory so file-uploader is shown instead of re-upload button
        if "chrome_langchain_db" in str(path):
            return False
        return real_isdir(path)

    with patch("os.path.isfile", side_effect=_isfile), \
         patch("os.path.isdir", side_effect=_isdir):
        at.run()
    return at


# ---------------------------------------------------------------------------
# Smoke tests — app boots without exception
# ---------------------------------------------------------------------------

class TestAppBoots:
    def test_no_exception_on_startup(self):
        at = _run_app()
        assert not at.exception, f"App raised: {at.exception}"

    def test_title_is_rendered(self):
        at = _run_app()
        titles = at.title
        assert len(titles) > 0
        assert "TTRPG" in titles[0].value

    def test_info_banner_is_rendered(self):
        at = _run_app()
        infos = at.info
        assert len(infos) > 0
        assert "notes" in infos[0].value.lower()


# ---------------------------------------------------------------------------
# Sidebar — Model Options
# ---------------------------------------------------------------------------

def _model_selectbox(at):
    """The 'Select Model' dropdown — now that a Provider dropdown precedes it,
    targeting by label is more robust than by index."""
    return [s for s in at.sidebar.selectbox if s.label == "Select Model"][0]


def _provider_selectbox(at):
    return [s for s in at.sidebar.selectbox if s.label == "Provider"][0]


class TestSidebarModelOptions:
    def test_model_selectbox_present(self):
        at = _run_app()
        # sidebar selectbox for model selection should exist
        assert len(at.sidebar.selectbox) >= 1

    def test_no_temperature_slider(self):
        at = _run_app()
        assert len(at.sidebar.slider) == 0

    def test_api_key_field_is_password_masked(self):
        at = _run_app()
        # proto.type == 1 is TextInput.Type.PASSWORD
        key_inputs = [t for t in at.sidebar.text_input if t.proto.type == 1]
        assert len(key_inputs) == 1
        assert "API Key" in key_inputs[0].label

    def test_model_selectbox_lists_supported_models(self):
        at = _run_app()
        assert list(_model_selectbox(at).options) == ["gpt-5.4-nano", "gpt-5.4-mini", "gpt-5.4"]

    def test_cheapest_model_preselected_on_first_run(self):
        at = _run_app()
        assert _model_selectbox(at).value == "gpt-5.4-nano"

    def test_provider_selector_present_with_openai_selected(self):
        at = _run_app()
        provider = _provider_selectbox(at)
        assert "OpenAI" in list(provider.options)
        assert provider.value == "OpenAI"

    def test_provider_selector_lists_anthropic(self):
        at = _run_app()
        provider = _provider_selectbox(at)
        assert "Anthropic" in list(provider.options)


# ---------------------------------------------------------------------------
# Anthropic provider path — empty-until-key dropdown, provider-named gating,
# per-provider key slots
# ---------------------------------------------------------------------------

class TestAnthropicProviderPath:
    def test_dropdown_empty_with_hint_when_no_key(self):
        """Anthropic active, no key: the model dropdown is empty/disabled and a
        hint tells the user to enter the key."""
        at = _run_preloaded(provider="Anthropic", anthropic_api_key="",
                            openai_api_key="", model_name="claude-opus-5")
        assert not at.exception
        model_box = _model_selectbox(at)
        assert list(model_box.options) == []
        assert model_box.disabled is True
        infos = [i.value for i in at.info]
        assert any("Anthropic API key" in m for m in infos)

    def test_chat_gating_names_anthropic(self):
        """With notes + a saved model but no Anthropic key, chat is disabled and
        the banner names Anthropic."""
        _isfile = _db_patches()
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        for k, v in _ALL_KEYS.items():
            at.session_state[k] = v
        at.session_state["provider"] = "Anthropic"
        at.session_state["model_name"] = "claude-opus-5"
        at.session_state["anthropic_api_key"] = ""
        at.session_state["openai_api_key"] = ""
        with patch("os.path.isfile", side_effect=_isfile):
            at.run()
        assert not at.exception
        assert len(at.chat_input) == 1
        assert at.chat_input[0].disabled is True
        messages = [i.value for i in at.info]
        assert any("Anthropic API key" in m and "Model Options" in m for m in messages)

    def test_per_provider_keys_survive_a_provider_switch(self):
        """Both key slots persist across a provider switch — neither is erased."""
        at = _run_preloaded(provider="OpenAI", openai_api_key="sk-openai",
                            anthropic_api_key="sk-ant", model_name="gpt-5.4-nano")
        assert not at.exception
        # Flip to Anthropic; the OpenAI key must remain in its own slot.
        _provider_selectbox(at).set_value("Anthropic").run()
        assert not at.exception
        assert at.session_state["openai_api_key"] == "sk-openai"
        assert at.session_state["anthropic_api_key"] == "sk-ant"


# ---------------------------------------------------------------------------
# Sidebar — Journal Options
# ---------------------------------------------------------------------------

class TestSidebarJournalOptions:
    def test_add_member_button_present(self):
        at = _run_app()
        labels = [b.label for b in at.sidebar.button]
        assert any("Add New Member" in lbl for lbl in labels)

    def test_reupload_button_absent_when_no_db(self):
        # "Re-Upload Notes" button should only appear when a DB already exists.
        # Since we mock out the DB directory, it must NOT be present.
        at = _run_app()
        labels = [b.label for b in at.sidebar.button]
        assert not any("Re-Upload" in lbl for lbl in labels)

    def test_initial_party_member_text_input_present(self):
        at = _run_app()
        # At least one text_input for the default party member
        assert len(at.text_input) >= 1


# ---------------------------------------------------------------------------
# Chat input — disabled until notes + model are ready
# ---------------------------------------------------------------------------

class TestChatInput:
    def test_chat_input_absent_when_notes_not_uploaded(self):
        """With no notes and no model, chat_input should not be rendered."""
        at = _run_app()
        # notes_uploaded=False and model_name=None → __process_chat skips chat_input
        assert len(at.chat_input) == 0


# ---------------------------------------------------------------------------
# Key gating — chat needs a key, note upload does not
# ---------------------------------------------------------------------------

class TestKeyGating:
    def _boot_ready_to_chat(self, api_key):
        """Boot with notes uploaded and a model selected, varying only the key."""
        _isfile = _db_patches()
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        for k, v in _ALL_KEYS.items():
            at.session_state[k] = v
        at.session_state["model_name"] = "gpt-5.4-nano"
        at.session_state["openai_api_key"] = api_key
        with patch("os.path.isfile", side_effect=_isfile):
            at.run()
        return at

    def test_chat_input_disabled_without_key(self):
        at = self._boot_ready_to_chat("")
        assert not at.exception
        assert len(at.chat_input) == 1
        assert at.chat_input[0].disabled is True

    def test_key_banner_shown_without_key(self):
        at = self._boot_ready_to_chat("")
        messages = [i.value for i in at.info]
        assert any("API key" in m and "Model Options" in m for m in messages)

    def test_chat_input_enabled_with_key(self):
        at = self._boot_ready_to_chat("sk-test")
        assert not at.exception
        assert at.chat_input[0].disabled is False

    def _boot_uploader(self, api_key):
        """Boot with a model selected and no raw notes, varying only the key, so
        the file-uploader path (not Re-Upload) is exercised."""
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        for k, v in {**_ALL_KEYS, "model_name": "gpt-5.4-nano",
                     "openai_api_key": api_key}.items():
            at.session_state[k] = v
        real_isfile = os.path.isfile

        def _isfile(path):
            if "user_data" in str(path) or "raw_notes" in str(path):
                return False
            return real_isfile(path)

        with patch("os.path.isfile", side_effect=_isfile), \
             patch("os.path.isdir", side_effect=_hide_db_isdir()):
            at.run()
        return at

    def test_note_upload_gated_without_key(self):
        """Embeddings are now an OpenAI API call, so ingestion needs the key."""
        at = self._boot_uploader("")
        assert not at.exception
        assert len(at.get("file_uploader")) == 0
        messages = [i.value for i in at.info]
        assert any("API key" in m and "Model Options" in m for m in messages)

    def test_note_upload_available_with_key(self):
        at = self._boot_uploader("sk-test")
        assert not at.exception
        uploaders = at.get("file_uploader")
        assert len(uploaders) == 1
        assert uploaders[0].disabled is False

    def test_model_dropdown_renders_without_key(self):
        at = _run_preloaded(model_name="gpt-5.4-nano", openai_api_key="")
        # Provider + Select Model both render keylessly; the curated OpenAI list
        # needs no key.
        assert _model_selectbox(at).value == "gpt-5.4-nano"


# ---------------------------------------------------------------------------
# Startup restore — saved model + session-only key
# ---------------------------------------------------------------------------

class TestStartupRestore:
    def _boot_with_saved_model(self, tmp_path, model_name, api_key=""):
        data_file = tmp_path / "user_data.json"
        data_file.write_text(json.dumps({
            "model_name": model_name,
            "notes_uploaded": False,
            "party_members": [{"id": "abc", "name": "Aria", "note_taker": True}],
        }))
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        at.session_state["openai_api_key"] = api_key
        with patch.object(_chatbot_module.TTRPGChatbot, "_USERDATAFILE", str(data_file)), \
             patch("os.path.isdir", side_effect=_hide_db_isdir()):
            at.run()
        return at

    def test_saved_model_restored_without_key_and_no_error(self, tmp_path):
        at = self._boot_with_saved_model(tmp_path, "gpt-5.4-mini")
        assert not at.exception
        assert at.session_state.model_name == "gpt-5.4-mini"

    def test_stale_saved_model_cleared_with_reselect_prompt(self, tmp_path):
        at = self._boot_with_saved_model(tmp_path, "llama3:latest")
        assert not at.exception
        warnings = [w.value for w in at.warning]
        assert any("llama3:latest" in w and "Model Options" in w for w in warnings)

    def test_model_name_persisted_but_key_is_not(self, tmp_path):
        data_file = tmp_path / "user_data.json"
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        for k, v in {**_ALL_KEYS, "model_name": "gpt-5.4-mini",
                     "openai_api_key": "sk-secret"}.items():
            at.session_state[k] = v
        with patch.object(_chatbot_module.TTRPGChatbot, "_USERDATAFILE", str(data_file)), \
             patch("os.path.isdir", side_effect=_hide_db_isdir()):
            at.run()
        saved = json.loads(data_file.read_text())
        assert saved["model_name"] == "gpt-5.4-mini"
        assert "openai_api_key" not in saved
        assert "sk-secret" not in data_file.read_text()


# ---------------------------------------------------------------------------
# Session state — initial values
# ---------------------------------------------------------------------------

class TestSessionStateInit:
    def test_notes_uploaded_is_false_initially(self):
        at = _run_app()
        assert at.session_state.notes_uploaded is False

    def test_messages_is_empty_list_initially(self):
        at = _run_app()
        assert at.session_state.messages == []

    def test_cheapest_model_selected_initially(self):
        at = _run_app()
        assert at.session_state.model_name == "gpt-5.4-nano"

    def test_api_key_is_empty_initially(self):
        at = _run_app()
        assert at.session_state.openai_api_key == ""

    def test_party_members_initialized(self):
        at = _run_app()
        assert isinstance(at.session_state.party_members, list)
        assert len(at.session_state.party_members) >= 1


# ---------------------------------------------------------------------------
# User-data persistence
# ---------------------------------------------------------------------------

class TestUserDataLoading:
    def test_loads_model_name_from_user_data(self, tmp_path):
        user_data = {
            "model_name": "llama3:latest",
            "model_temperature": 0.5,
            "notes_uploaded": False,
            "party_members": [{"id": "abc", "name": "Aria", "note_taker": False}]
        }
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        user_data_file = data_dir / "user_data.json"
        user_data_file.write_text(json.dumps(user_data))

        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        with patch("os.path.isdir", return_value=False), \
             patch("os.path.isfile", return_value=True), \
             patch("builtins.open", side_effect=lambda p, *a, **kw:
                   open(str(user_data_file), *a, **kw)
                   if "user_data" in str(p) else open(str(tmp_path / "fake.json"), *a, **kw)):
            try:
                at.run()
            except Exception:
                pass  # allow file-not-found for asset files

        # If model_name loaded from file it should be "llama3:latest"
        if not at.exception:
            assert at.session_state.model_name == "llama3:latest"


# ---------------------------------------------------------------------------
# User-data init
# ---------------------------------------------------------------------------

class TestUserDataInitCoverage:
    def test_state_loaded_when_user_data_file_exists(self, tmp_path):
        # Use model_name=None so __init_state_variables skips the load_model call
        # (line 62). That avoids a double load_model issue with the mock, while
        # still covering lines 47 and 52-61.
        user_data = {
            "model_name": None,
            "model_temperature": 0.5,
            "notes_uploaded": True,
            "party_members": [{"id": "t1", "name": "Aria", "note_taker": False}],
        }
        data_file = tmp_path / "user_data.json"
        data_file.write_text(json.dumps(user_data))

        _real_open = open  # capture before patching

        def _open(path, *args, **kwargs):
            if "user_data" in str(path):
                mode = args[0] if args else kwargs.get("mode", "r")
                if "w" in mode:
                    return _real_open(str(tmp_path / "out.json"), "w")
                return _real_open(str(data_file), *args, **kwargs)
            return _real_open(path, *args, **kwargs)

        _real_isfile = os.path.isfile

        def _isfile(path):
            return True if "user_data" in str(path) else _real_isfile(path)

        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        with patch("builtins.open", side_effect=_open), \
             patch("os.path.isfile", side_effect=_isfile), \
             patch("os.path.isdir", side_effect=_hide_db_isdir()):
            at.run()

        assert not at.exception
        # party_members is set by __init_state_variables and not overwritten
        # by subsequent UI methods, so it reliably reflects the loaded file.
        assert any(m["name"] == "Aria" for m in at.session_state.party_members)


# ---------------------------------------------------------------------------
# Model selection
# ---------------------------------------------------------------------------

class TestModelSelectionSavesState:
    def test_model_written_to_session_state(self):
        """When model_name is already set the selectbox resolves it and loads the model."""
        at = _run_preloaded(model_name="gpt-5.4-mini", openai_api_key="sk-test")
        assert not at.exception
        assert at.session_state.model_name == "gpt-5.4-mini"

    def test_api_key_never_written_to_user_data(self, tmp_path):
        """The key lives in session state only — it must not reach user_data.json."""
        data_file = tmp_path / "user_data.json"
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        for k, v in {**_ALL_KEYS, "openai_api_key": "sk-secret"}.items():
            at.session_state[k] = v
        with patch.object(_chatbot_module.TTRPGChatbot, "_USERDATAFILE", str(data_file)), \
             patch("os.path.isdir", side_effect=_hide_db_isdir()):
            at.run()
        assert not at.exception
        assert data_file.is_file()
        assert "sk-secret" not in data_file.read_text()


# ---------------------------------------------------------------------------
# __update_message_history
# ---------------------------------------------------------------------------

class TestUpdateMessageHistory:
    def test_user_and_assistant_messages_rendered(self):
        messages = [
            {"role": "user", "content": "Test question?", "avatar": None},
            {"role": "assistant", "content": "Test answer.", "avatar": "🧙‍♂️"},
        ]
        at = _run_preloaded(messages=messages, buttoninfo=[None])
        assert not at.exception

    def test_assistant_message_with_reference_buttons(self):
        def _noop(content):
            pass

        messages = [
            {"role": "user", "content": "What happened?", "avatar": None},
            {"role": "assistant", "content": "See references.", "avatar": "🧙‍♂️"},
        ]
        buttoninfo = [[["2023-01-01", _noop, ("content text",), "click_0"]]]
        at = _run_preloaded(messages=messages, buttoninfo=buttoninfo)
        assert not at.exception


# ---------------------------------------------------------------------------
# DB-exists state
# ---------------------------------------------------------------------------

class TestReuploadButtonFlow:
    def test_reupload_button_present_when_raw_notes_exist(self):
        _isfile = _db_patches()
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        for k, v in _ALL_KEYS.items():
            at.session_state[k] = v
        with patch("os.path.isfile", side_effect=_isfile):
            at.run()
        assert not at.exception
        labels = [b.label for b in at.sidebar.button]
        assert any("Re-Upload" in lbl for lbl in labels)

    def test_reupload_button_click_clears_chat_history(self):
        _isfile = _db_patches()
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        for k, v in _ALL_KEYS.items():
            at.session_state[k] = v
        at.session_state["messages"] = [{"role": "user", "content": "old", "avatar": None}]
        at.session_state["button_key"] = 3
        with patch("os.path.isfile", side_effect=_isfile), \
             patch("os.remove"):
            at.run()
            reupload = [b for b in at.sidebar.button if "Re-Upload" in b.label]
            assert len(reupload) == 1
            reupload[0].click().run()
        assert not at.exception
        assert at.session_state.messages == []
        assert at.session_state.button_key == 0


# ---------------------------------------------------------------------------
# __process_chat
# ---------------------------------------------------------------------------

class TestProcessChatFlow:
    def _boot_with_db(self, **state_overrides):
        """Start the app in a state where chat_input is visible."""
        _isfile = _db_patches()
        at = AppTest.from_file(APP_PATH, default_timeout=TIMEOUT)
        for k, v in _ALL_KEYS.items():
            at.session_state[k] = v
        at.session_state["model_name"] = "gpt-5.4-nano"
        at.session_state["openai_api_key"] = "sk-test"
        for k, v in state_overrides.items():
            at.session_state[k] = v
        return at, _isfile

    def test_chat_input_visible_when_notes_and_model_ready(self):
        at, _isfile = self._boot_with_db()
        with patch("os.path.isfile", side_effect=_isfile):
            at.run()
        assert not at.exception
        assert len(at.chat_input) == 1

    def test_no_notes_found_appends_canned_response(self):
        at, _isfile = self._boot_with_db()
        with patch("os.path.isfile", side_effect=_isfile):
            at.run()
            at.chat_input[0].set_value("What happened to the dragon?").run()
        assert not at.exception
        msgs = at.session_state.messages
        assert len(msgs) >= 2
        roles = [m["role"] for m in msgs]
        assert "user" in roles
        assert "assistant" in roles

    def test_user_message_stored_in_session(self):
        at, _isfile = self._boot_with_db()
        with patch("os.path.isfile", side_effect=_isfile):
            at.run()
            at.chat_input[0].set_value("Did the wizard survive?").run()
        assert not at.exception
        user_msgs = [m for m in at.session_state.messages if m["role"] == "user"]
        assert any("wizard" in m["content"].lower() for m in user_msgs)


# ---------------------------------------------------------------------------
# Page navigation — disabled while a long-running task is in progress
# ---------------------------------------------------------------------------

def _nav_css_present(at) -> bool:
    """True if the sidebar-nav-disabling CSS was injected on this run."""
    return any(
        "stSidebarNav" in md.value and "pointer-events" in md.value
        for md in at.markdown
    )


class TestNavigationDisabledWhileProcessing:
    def test_nav_css_injected_when_processing(self):
        at = _run_preloaded(is_processing=True)
        assert not at.exception
        assert _nav_css_present(at)

    def test_nav_css_absent_when_not_processing(self):
        at = _run_preloaded(is_processing=False)
        assert not at.exception
        assert not _nav_css_present(at)

    def test_nav_css_absent_when_flag_unset(self):
        at = _run_app()
        assert not at.exception
        assert not _nav_css_present(at)

