"""Pure unit tests for TTRPGChatbot class methods — no AppTest, no Streamlit runtime."""

import json
import os
import pytest
from unittest.mock import MagicMock, mock_open, patch

from src.app.TTRPGChatBot import TTRPGChatbot
from src.utils.DatabaseHandler import DATABASE_DIR


class _SS(dict):
    """Minimal session_state stand-in that supports both attr and item access."""
    def __getattr__(self, name):
        try:
            return self[name]
        except KeyError:
            raise AttributeError(name)
    def __setattr__(self, name, value):
        self[name] = value
    def __delattr__(self, name):
        del self[name]


def _make_bot():
    """Instantiate TTRPGChatbot without running __init__ to avoid Streamlit and I/O."""
    bot = TTRPGChatbot.__new__(TTRPGChatbot)
    bot._DATABASEDIR = DATABASE_DIR
    bot._USERDATAFILE = "data//user_data.json"
    bot._PROMPTEMPLATE = MagicMock()
    bot.databasehandler = MagicMock()
    bot.llmhandler = MagicMock()
    return bot


# ---------------------------------------------------------------------------
# __save_user_data — must preserve fields written by other pages
# ---------------------------------------------------------------------------

class TestSaveUserData:
    """__save_user_data must not erase summary_model fields set by CampaignSummarizer."""

    def test_preserves_summary_model_fields_when_file_has_them(self, tmp_path):
        bot = _make_bot()
        data_file = tmp_path / "user_data.json"
        data_file.write_text(json.dumps({
            "summary_model_name": "gpt-5.4",
        }))
        bot._USERDATAFILE = str(data_file)
        ss = _SS(
            model_name="gpt-5.4-nano",
            openai_api_key="sk-secret",
            notes_uploaded=True,
            party_members=[{"id": "1", "name": "Aria", "note_taker": True}],
        )
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__save_user_data()
        saved = json.loads(data_file.read_text())
        assert saved["summary_model_name"] == "gpt-5.4"
        assert saved["model_name"] == "gpt-5.4-nano"

    def test_never_persists_api_key_or_temperature(self, tmp_path):
        bot = _make_bot()
        data_file = tmp_path / "user_data.json"
        bot._USERDATAFILE = str(data_file)
        ss = _SS(
            model_name="gpt-5.4-nano",
            openai_api_key="sk-secret",
            notes_uploaded=True,
            party_members=[],
        )
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__save_user_data()
        saved = json.loads(data_file.read_text())
        assert "openai_api_key" not in saved
        assert "model_temperature" not in saved
        assert "sk-secret" not in data_file.read_text()

    def test_writes_qa_fields_when_no_prior_file(self, tmp_path):
        bot = _make_bot()
        data_file = tmp_path / "user_data.json"
        bot._USERDATAFILE = str(data_file)
        ss = _SS(
            model_name="gpt-5.4-nano",
            notes_uploaded=False,
            party_members=[],
        )
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__save_user_data()
        saved = json.loads(data_file.read_text())
        assert saved["model_name"] == "gpt-5.4-nano"
        assert saved["notes_uploaded"] is False


# ---------------------------------------------------------------------------
# __init_state_variables — resilience to a persisted-but-missing model
# ---------------------------------------------------------------------------

class TestInitStateVariablesMissingModel:
    """If user_data.json names a model that is no longer offered, startup must
    not crash; the app falls back to no model so the user can pick one."""

    def _bot_with_userdata(self, tmp_path, user_data):
        bot = _make_bot()
        bot.summaryhandler = MagicMock()
        bot.summaryhandler.summary_exists.return_value = False
        bot.llmhandler.get_available_models.return_value = [
            "gpt-5.4-nano", "gpt-5.4-mini", "gpt-5.4",
        ]
        data_file = tmp_path / "user_data.json"
        data_file.write_text(json.dumps(user_data))
        bot._USERDATAFILE = str(data_file)
        return bot

    _UD = {
        "model_name": "gpt-5.4-mini",
        "notes_uploaded": False,
        "party_members": [{"id": "p1", "name": "", "note_taker": True}],
    }

    _STALE_UD = {**_UD, "model_name": "llama3:latest"}

    def test_does_not_raise_when_model_unavailable(self, tmp_path):
        bot = self._bot_with_userdata(tmp_path, self._STALE_UD)
        ss = _SS(openai_api_key="sk-test")
        with patch("streamlit.session_state", ss), patch("streamlit.warning"):
            result = bot._TTRPGChatbot__init_state_variables()
        assert result is True

    def test_clears_model_when_unavailable(self, tmp_path):
        bot = self._bot_with_userdata(tmp_path, self._STALE_UD)
        ss = _SS(openai_api_key="sk-test")
        with patch("streamlit.session_state", ss), patch("streamlit.warning"):
            bot._TTRPGChatbot__init_state_variables()
        assert ss["model_name"] is None

    def test_prompts_user_to_reselect_when_model_unavailable(self, tmp_path):
        bot = self._bot_with_userdata(tmp_path, self._STALE_UD)
        ss = _SS(openai_api_key="sk-test")
        with patch("streamlit.session_state", ss), patch("streamlit.warning") as mock_warning:
            bot._TTRPGChatbot__init_state_variables()
        message = mock_warning.call_args.args[0]
        assert "llama3:latest" in message
        assert "Model Options" in message

    def test_stale_model_cleared_even_without_a_key(self, tmp_path):
        """Validation is a list lookup, not a load attempt, so it does not need a key."""
        bot = self._bot_with_userdata(tmp_path, self._STALE_UD)
        ss = _SS(openai_api_key="")
        with patch("streamlit.session_state", ss), patch("streamlit.warning"):
            bot._TTRPGChatbot__init_state_variables()
        assert ss["model_name"] is None
        bot.llmhandler.load_model.assert_not_called()

    def test_keeps_model_when_available(self, tmp_path):
        bot = self._bot_with_userdata(tmp_path, self._UD)
        ss = _SS(openai_api_key="sk-test")
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__init_state_variables()
        assert ss["model_name"] == "gpt-5.4-mini"
        bot.llmhandler.load_model.assert_called_once_with("gpt-5.4-mini", "sk-test")

    def test_skips_eager_load_when_no_api_key(self, tmp_path):
        """Without a key there is nothing to construct — the saved model is kept
        and loading is deferred until the user supplies one."""
        bot = self._bot_with_userdata(tmp_path, self._UD)
        ss = _SS()
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__init_state_variables()
        assert ss["model_name"] == "gpt-5.4-mini"
        bot.llmhandler.load_model.assert_not_called()

    def test_no_warning_when_no_api_key_and_model_is_valid(self, tmp_path):
        """A keyless startup is a normal state, not something to warn about."""
        bot = self._bot_with_userdata(tmp_path, self._UD)
        ss = _SS()
        with patch("streamlit.session_state", ss), patch("streamlit.warning") as mock_warning:
            bot._TTRPGChatbot__init_state_variables()
        mock_warning.assert_not_called()


# ---------------------------------------------------------------------------
# __process_chat — chat is gated behind a session API key
# ---------------------------------------------------------------------------

class TestProcessChatKeyGating:
    """Chat requires a key; without one the input is disabled behind a banner."""

    def _make_ss(self, api_key):
        return _SS(
            notes_uploaded=True,
            model_name="gpt-5.4-nano",
            openai_api_key=api_key,
            messages=[],
            buttoninfo=[],
            button_key=0,
            party_members=[{"id": "p1", "name": "Aria", "note_taker": True}],
            is_processing=False,
        )

    def _run(self, bot, ss):
        with patch("streamlit.session_state", ss), \
             patch("streamlit.chat_input", return_value=None) as mock_chat_input, \
             patch("streamlit.info") as mock_info, \
             patch("streamlit.error"), \
             patch("streamlit.rerun"):
            bot._TTRPGChatbot__process_chat()
        return mock_chat_input, mock_info

    def test_chat_input_disabled_without_key(self):
        bot = _make_bot()
        mock_chat_input, _ = self._run(bot, self._make_ss(""))
        assert mock_chat_input.call_args.kwargs["disabled"] is True

    def test_info_banner_tells_user_to_enter_key(self):
        bot = _make_bot()
        _, mock_info = self._run(bot, self._make_ss(""))
        messages = [c.args[0] for c in mock_info.call_args_list]
        assert any("API key" in m and "Model Options" in m for m in messages)

    def test_chat_input_enabled_with_key(self):
        bot = _make_bot()
        mock_chat_input, mock_info = self._run(bot, self._make_ss("sk-test"))
        assert mock_chat_input.call_args.kwargs["disabled"] is False
        assert not mock_info.call_args_list

    def test_question_not_captured_without_key(self):
        """The widget is disabled, but a stale value must not start a run either."""
        bot = _make_bot()
        ss = self._make_ss("")
        with patch("streamlit.session_state", ss), \
             patch("streamlit.chat_input", return_value="What happened?"), \
             patch("streamlit.info"), \
             patch("streamlit.error"), \
             patch("streamlit.rerun"):
            bot._TTRPGChatbot__process_chat()
        assert "_pending_chat" not in ss
        assert ss["is_processing"] is False


# ---------------------------------------------------------------------------
# __stream_data
# ---------------------------------------------------------------------------

class TestStreamData:
    def test_yields_space_appended_words(self):
        bot = _make_bot()
        with patch("time.sleep"):
            result = list(bot._TTRPGChatbot__stream_data("hello world"))
        assert result == ["hello ", "world "]

    def test_single_word(self):
        bot = _make_bot()
        with patch("time.sleep"):
            result = list(bot._TTRPGChatbot__stream_data("single"))
        assert result == ["single "]


# ---------------------------------------------------------------------------
# __reset_chat_history
# ---------------------------------------------------------------------------

class TestResetChatHistory:
    def test_clears_messages_buttoninfo_and_key(self):
        bot = _make_bot()
        ss = _SS(messages=["m1"], buttoninfo=["b1"], button_key=5)
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__reset_chat_history()
        assert ss["messages"] == []
        assert ss["buttoninfo"] == []
        assert ss["button_key"] == 0


# ---------------------------------------------------------------------------
# __delete_member
# ---------------------------------------------------------------------------

class TestDeleteMember:
    def test_removes_the_specified_member(self):
        bot = _make_bot()
        ss = _SS(party_members=[
            {"id": "aaa", "name": "Alice", "note_taker": False},
            {"id": "bbb", "name": "Bob", "note_taker": False},
        ])
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__delete_member("aaa")
        assert [m["id"] for m in ss["party_members"]] == ["bbb"]

    def test_no_error_when_id_absent(self):
        bot = _make_bot()
        ss = _SS(party_members=[{"id": "aaa", "name": "Alice", "note_taker": False}])
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__delete_member("zzz")
        assert len(ss["party_members"]) == 1


# ---------------------------------------------------------------------------
# __toggle_note_taker
# ---------------------------------------------------------------------------

class TestToggleNoteTaker:
    def test_sets_note_taker_true_on_matching_member(self):
        bot = _make_bot()
        mid = "m1"
        ss = _SS(party_members=[{"id": mid, "name": "Alice", "note_taker": False}])
        ss[f"note_taker_{mid}"] = True
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__toggle_note_taker(mid)
        assert ss["party_members"][0]["note_taker"] is True

    def test_sets_note_taker_false_on_matching_member(self):
        bot = _make_bot()
        mid = "m1"
        ss = _SS(party_members=[{"id": mid, "name": "Alice", "note_taker": True}])
        ss[f"note_taker_{mid}"] = False
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__toggle_note_taker(mid)
        assert ss["party_members"][0]["note_taker"] is False

    def test_does_not_change_non_matching_members(self):
        bot = _make_bot()
        mid = "m1"
        other = "m2"
        ss = _SS(party_members=[
            {"id": mid, "name": "Alice", "note_taker": False},
            {"id": other, "name": "Bob", "note_taker": False},
        ])
        ss[f"note_taker_{mid}"] = True
        with patch("streamlit.session_state", ss):
            bot._TTRPGChatbot__toggle_note_taker(mid)
        assert ss["party_members"][1]["note_taker"] is False


# ---------------------------------------------------------------------------
# __process_chat — happy path (notes found, LLM invoked, response stored)
# ---------------------------------------------------------------------------

class TestProcessChatHappyPath:
    """Unit tests for __process_chat when retrieve_notes returns documents."""

    def _make_ready_bot(self, party_members=None):
        if party_members is None:
            party_members = [{"id": "p1", "name": "Aria", "note_taker": True}]
        bot = _make_bot()
        ss = _SS(
            notes_uploaded=True,
            model_name="llama3:latest",
            messages=[],
            buttoninfo=[],
            button_key=0,
            party_members=party_members,
            is_processing=True,
        )
        return bot, ss

    def _mock_note(self, date="2023-10-27", content="The party defeated the dragon."):
        note = MagicMock()
        note.page_content = content
        note.metadata = {"Date": date}
        return note

    def _run_chat(self, bot, ss, question, notes, llm_response="Answer."):
        # Simulate Phase 2: a question was already captured in Phase 1
        ss["_pending_chat"] = question
        bot.databasehandler.retrieve_notes.return_value = notes
        bot.llmhandler.invoke_model.return_value = llm_response
        with patch("streamlit.session_state", ss), \
             patch("streamlit.chat_input", return_value=None), \
             patch("streamlit.chat_message", return_value=MagicMock()), \
             patch("streamlit.markdown"), \
             patch("streamlit.write_stream"), \
             patch("streamlit.button"), \
             patch("streamlit.empty", return_value=MagicMock()), \
             patch("streamlit.rerun"), \
             patch("time.sleep"), \
             patch("builtins.open", mock_open(read_data="{}")), \
             patch("json.load", return_value={}):
            bot._TTRPGChatbot__process_chat()

    def test_llm_response_stored_as_assistant_message(self):
        bot, ss = self._make_ready_bot()
        self._run_chat(bot, ss, "What happened?", [self._mock_note()], "Aria defeated the dragon.")
        assistant_msgs = [m for m in ss["messages"] if m["role"] == "assistant"]
        assert len(assistant_msgs) == 1
        assert "Aria defeated the dragon." in assistant_msgs[0]["content"]

    def test_user_message_stored_before_response(self):
        bot, ss = self._make_ready_bot()
        self._run_chat(bot, ss, "What happened?", [self._mock_note()])
        roles = [m["role"] for m in ss["messages"]]
        assert roles == ["user", "assistant"]
        assert ss["messages"][0]["content"] == "What happened?"

    def test_reference_buttoninfo_populated_per_note(self):
        bot, ss = self._make_ready_bot()
        notes = [self._mock_note("2023-10-27"), self._mock_note("2023-10-28")]
        self._run_chat(bot, ss, "Tell me about the campaign.", notes)
        assert len(ss["buttoninfo"]) == 1
        btn_entries = ss["buttoninfo"][0]
        assert btn_entries is not None
        assert len(btn_entries) == 2
        dates = [e[0] for e in btn_entries]
        assert "2023-10-27" in dates
        assert "2023-10-28" in dates

    def test_invoke_model_receives_correct_mappings(self):
        bot, ss = self._make_ready_bot()
        self._run_chat(bot, ss, "Did the wizard help?", [self._mock_note()])
        # bot.llmhandler is a MagicMock so call_args.args has no implicit self
        # args[0] = prompt_template, args[1] = mappings dict
        mappings = bot.llmhandler.invoke_model.call_args.args[1]
        assert mappings["question"] == "Did the wizard help?"
        assert "Aria" in mappings["partymembers"]
        assert mappings["notetaker"] == "Aria"

    def test_multiple_party_members_formatted_with_and(self):
        members = [
            {"id": "p1", "name": "Aria", "note_taker": True},
            {"id": "p2", "name": "Brom", "note_taker": False},
            {"id": "p3", "name": "Cael", "note_taker": False},
        ]
        bot, ss = self._make_ready_bot(party_members=members)
        self._run_chat(bot, ss, "Any question?", [self._mock_note()])
        members_str = bot.llmhandler.invoke_model.call_args.args[1]["partymembers"]
        assert "Aria" in members_str
        assert "Brom" in members_str
        assert "Cael" in members_str
        assert "and" in members_str

    def test_button_key_incremented_once_per_retrieved_note(self):
        bot, ss = self._make_ready_bot()
        notes = [
            self._mock_note("2023-11-01"),
            self._mock_note("2023-11-02"),
            self._mock_note("2023-11-03"),
        ]
        self._run_chat(bot, ss, "What happened?", notes)
        assert ss["button_key"] == 3


# ---------------------------------------------------------------------------
# __process_chat — LLM failures surface as friendly messages, not stack traces
# ---------------------------------------------------------------------------

_KEY_REJECTED = "Your OpenAI API key was rejected. Please check your key in Model Options."


class TestProcessChatErrorSurfacing:
    """A ValueError out of invoke_model must reach the user as readable text."""

    def _make_ready_bot(self):
        bot = _make_bot()
        ss = _SS(
            notes_uploaded=True,
            model_name="gpt-5.4-nano",
            messages=[],
            buttoninfo=[],
            button_key=0,
            party_members=[{"id": "p1", "name": "Aria", "note_taker": True}],
            is_processing=True,
        )
        return bot, ss

    def _mock_note(self):
        note = MagicMock()
        note.page_content = "The party defeated the dragon."
        note.metadata = {"Date": "2023-10-27"}
        return note

    def _run_failing_chat(self, bot, ss, error):
        ss["_pending_chat"] = "What happened?"
        bot.databasehandler.retrieve_notes.return_value = [self._mock_note()]
        bot.llmhandler.invoke_model.side_effect = error
        with patch("streamlit.session_state", ss), \
             patch("streamlit.chat_input", return_value=None), \
             patch("streamlit.chat_message", return_value=MagicMock()), \
             patch("streamlit.markdown"), \
             patch("streamlit.write_stream"), \
             patch("streamlit.button"), \
             patch("streamlit.error") as mock_error, \
             patch("streamlit.empty", return_value=MagicMock()), \
             patch("streamlit.rerun"), \
             patch("time.sleep"), \
             patch("builtins.open", mock_open(read_data="{}")), \
             patch("json.load", return_value={}):
            bot._TTRPGChatbot__process_chat()
        return mock_error

    def test_friendly_message_stashed_for_display(self):
        bot, ss = self._make_ready_bot()
        self._run_failing_chat(bot, ss, ValueError(_KEY_REJECTED))
        assert ss.get("_chat_error") == _KEY_REJECTED

    def test_rate_limit_message_stashed_for_display(self):
        bot, ss = self._make_ready_bot()
        self._run_failing_chat(bot, ss, ValueError("Rate limited. Please try again."))
        assert ss.get("_chat_error") == "Rate limited. Please try again."

    def test_connection_message_stashed_for_display(self):
        bot, ss = self._make_ready_bot()
        self._run_failing_chat(bot, ss, ValueError("Could not connect to OpenAI."))
        assert ss.get("_chat_error") == "Could not connect to OpenAI."

    def test_no_assistant_message_recorded_on_failure(self):
        bot, ss = self._make_ready_bot()
        self._run_failing_chat(bot, ss, ValueError(_KEY_REJECTED))
        assert [m["role"] for m in ss["messages"]] == ["user"]

    def test_buttoninfo_stays_aligned_with_assistant_messages(self):
        bot, ss = self._make_ready_bot()
        self._run_failing_chat(bot, ss, ValueError(_KEY_REJECTED))
        assert ss["buttoninfo"] == []

    def test_processing_flag_cleared_so_ui_is_usable_again(self):
        bot, ss = self._make_ready_bot()
        self._run_failing_chat(bot, ss, ValueError(_KEY_REJECTED))
        assert ss["is_processing"] is False

    def test_stashed_error_is_displayed_on_the_next_run(self):
        bot, ss = self._make_ready_bot()
        ss["is_processing"] = False
        ss["_chat_error"] = _KEY_REJECTED
        with patch("streamlit.session_state", ss), \
             patch("streamlit.chat_input", return_value=None), \
             patch("streamlit.error") as mock_error:
            bot._TTRPGChatbot__process_chat()
        mock_error.assert_called_once_with(_KEY_REJECTED)
        assert "_chat_error" not in ss

    def test_unexpected_errors_are_not_swallowed(self):
        bot, ss = self._make_ready_bot()
        with pytest.raises(RuntimeError):
            self._run_failing_chat(bot, ss, RuntimeError("programming error"))
