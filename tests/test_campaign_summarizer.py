"""Unit tests for CampaignSummarizer — Streamlit calls are mocked."""

import json
import pytest
from unittest.mock import MagicMock, patch, mock_open

from src.app.CampaignSummarizer import CampaignSummarizer


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
    def get(self, key, default=None):
        return self[key] if key in self else default
    def pop(self, key, *args):
        return dict.pop(self, key, *args)


def _make_summarizer():
    """Instantiate CampaignSummarizer without running __init__."""
    cs = CampaignSummarizer.__new__(CampaignSummarizer)
    cs.llm_handler = MagicMock()
    cs.summary_handler = MagicMock()
    return cs


# ---------------------------------------------------------------------------
# __init_state_variables — party_members persistence
# ---------------------------------------------------------------------------

class TestInitStateVariables:
    """__init_state_variables must load party_members from user data when absent from session."""

    def test_loads_party_members_from_file_when_absent_from_session(self, tmp_path):
        cs = _make_summarizer()
        saved_members = [{"id": "1", "name": "Aria", "note_taker": True}]
        data_file = tmp_path / "user_data.json"
        data_file.write_text(json.dumps({
            "summary_model_name": "gpt-5.4-nano",
            "party_members": saved_members,
        }))
        cs._USERDATAFILE = str(data_file)
        ss = _SS()
        with patch("streamlit.session_state", ss):
            cs._CampaignSummarizer__init_state_variables()
        assert ss.get("party_members") == saved_members

    def test_party_members_defaults_to_empty_list_when_file_absent(self, tmp_path):
        cs = _make_summarizer()
        cs._USERDATAFILE = str(tmp_path / "nonexistent.json")
        ss = _SS()
        with patch("streamlit.session_state", ss):
            cs._CampaignSummarizer__init_state_variables()
        assert ss.get("party_members") == []

    def test_does_not_overwrite_party_members_already_in_session(self, tmp_path):
        cs = _make_summarizer()
        existing = [{"id": "99", "name": "Veteran", "note_taker": False}]
        data_file = tmp_path / "user_data.json"
        data_file.write_text(json.dumps({"party_members": [{"id": "1", "name": "Aria", "note_taker": True}]}))
        cs._USERDATAFILE = str(data_file)
        ss = _SS(party_members=existing)
        with patch("streamlit.session_state", ss):
            cs._CampaignSummarizer__init_state_variables()
        assert ss.get("party_members") == existing


# ---------------------------------------------------------------------------
# __extract_headers
# ---------------------------------------------------------------------------

class TestExtractHeaders:
    def test_extracts_h1_header(self):
        cs = _make_summarizer()
        result = cs._CampaignSummarizer__extract_headers("# Title\nSome text")
        assert result == [(1, "Title")]

    def test_extracts_multiple_levels(self):
        cs = _make_summarizer()
        text = "# H1\n## H2\n### H3"
        result = cs._CampaignSummarizer__extract_headers(text)
        assert result == [(1, "H1"), (2, "H2"), (3, "H3")]

    def test_returns_empty_for_no_headers(self):
        cs = _make_summarizer()
        assert cs._CampaignSummarizer__extract_headers("no headers here") == []

    def test_ignores_h4_and_deeper(self):
        cs = _make_summarizer()
        result = cs._CampaignSummarizer__extract_headers("#### Too deep\n##### Even deeper")
        assert result == []

    def test_strips_trailing_whitespace_from_title(self):
        cs = _make_summarizer()
        result = cs._CampaignSummarizer__extract_headers("# Title   ")
        assert result == [(1, "Title")]

    def test_multiple_headers_in_order(self):
        cs = _make_summarizer()
        text = "# Intro\nsome text\n## Section One\nmore text\n## Section Two"
        result = cs._CampaignSummarizer__extract_headers(text)
        assert result == [(1, "Intro"), (2, "Section One"), (2, "Section Two")]


# ---------------------------------------------------------------------------
# run() — party member gate
# ---------------------------------------------------------------------------

class TestRunPartyMemberGate:
    """run() must stop before offering generation when no named party members exist."""

    def _run_to_stop(self, cs, ss):
        """Run cs.run() expecting it to hit st.stop(); capture what st.info was called with."""
        info_calls = []
        with patch("streamlit.session_state", ss), \
             patch.object(cs, "_CampaignSummarizer__init_state_variables"), \
             patch.object(cs, "_CampaignSummarizer__process_model_options"), \
             patch.object(cs, "_notes_in_database", return_value=True), \
             patch("streamlit.title"), \
             patch("streamlit.info", side_effect=lambda msg: info_calls.append(msg)), \
             patch("streamlit.page_link"), \
             patch("streamlit.stop", side_effect=StopIteration), \
             patch("streamlit.button", return_value=False), \
             patch("streamlit.warning"):
            try:
                cs.run()
            except StopIteration:
                pass
        return info_calls

    def test_stops_when_party_members_empty_list(self):
        cs = _make_summarizer()
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        ss = _SS(summary_model_name="gpt-5.4-nano", party_members=[])
        info_calls = self._run_to_stop(cs, ss)
        assert any("party member" in msg.lower() for msg in info_calls)

    def test_stops_when_all_members_have_blank_names(self):
        cs = _make_summarizer()
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        ss = _SS(summary_model_name="gpt-5.4-nano", party_members=[
            {"id": "1", "name": "", "note_taker": False},
            {"id": "2", "name": "   ", "note_taker": False},
        ])
        info_calls = self._run_to_stop(cs, ss)
        assert any("party member" in msg.lower() for msg in info_calls)

    def test_stops_when_party_members_key_absent(self):
        cs = _make_summarizer()
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        ss = _SS(summary_model_name="gpt-5.4-nano")
        info_calls = self._run_to_stop(cs, ss)
        assert any("party member" in msg.lower() for msg in info_calls)

    def test_proceeds_when_at_least_one_named_member(self):
        cs = _make_summarizer()
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        ss = _SS(
            summary_model_name="gpt-5.4-nano",
            party_members=[{"id": "1", "name": "Aria", "note_taker": True}],
            is_processing=False,
        )
        button_called = []
        warning_called = []
        with patch("streamlit.session_state", ss), \
             patch.object(cs, "_CampaignSummarizer__init_state_variables"), \
             patch.object(cs, "_CampaignSummarizer__process_model_options"), \
             patch.object(cs, "_notes_in_database", return_value=True), \
             patch("streamlit.title"), \
             patch("streamlit.info"), \
             patch("streamlit.warning", side_effect=lambda msg: warning_called.append(msg)), \
             patch("streamlit.button", side_effect=lambda *a, **kw: button_called.append(True) or False), \
             patch("streamlit.stop", side_effect=StopIteration), \
             patch("streamlit.page_link"):
            try:
                cs.run()
            except StopIteration:
                pass
        # Button should have been rendered (generate button), not stopped at gate
        assert button_called


# ---------------------------------------------------------------------------
# run() — summary generation is gated behind a session API key
# ---------------------------------------------------------------------------

class TestRunKeyGating:
    """Generation requires a key; without one the button is disabled behind a banner."""

    def _run_to_button(self, cs, ss):
        """Run cs.run() to the generate button; return (info messages, button kwargs)."""
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        info_calls = []
        button_kwargs = []

        def _button(*args, **kwargs):
            button_kwargs.append(kwargs)
            return False

        with patch("streamlit.session_state", ss), \
             patch.object(cs, "_CampaignSummarizer__init_state_variables"), \
             patch.object(cs, "_CampaignSummarizer__process_model_options"), \
             patch.object(cs, "_notes_in_database", return_value=True), \
             patch("streamlit.title"), \
             patch("streamlit.info", side_effect=lambda msg: info_calls.append(msg)), \
             patch("streamlit.warning"), \
             patch("streamlit.button", side_effect=_button), \
             patch("streamlit.stop", side_effect=StopIteration), \
             patch("streamlit.page_link"):
            try:
                cs.run()
            except StopIteration:
                pass
        return info_calls, button_kwargs

    def _ss(self, api_key):
        return _SS(
            summary_model_name="gpt-5.4-nano",
            openai_api_key=api_key,
            party_members=[{"id": "1", "name": "Aria", "note_taker": True}],
            is_processing=False,
        )

    def test_generate_button_disabled_without_key(self):
        cs = _make_summarizer()
        _, button_kwargs = self._run_to_button(cs, self._ss(""))
        assert button_kwargs
        assert button_kwargs[-1]["disabled"] is True

    def test_info_banner_tells_user_to_enter_key(self):
        cs = _make_summarizer()
        info_calls, _ = self._run_to_button(cs, self._ss(""))
        assert any("API key" in msg and "Model Options" in msg for msg in info_calls)

    def test_generate_button_enabled_with_key(self):
        cs = _make_summarizer()
        info_calls, button_kwargs = self._run_to_button(cs, self._ss("sk-test"))
        assert button_kwargs[-1]["disabled"] is False
        assert not any("API key" in msg for msg in info_calls)

    def test_regenerate_button_disabled_without_key(self):
        """An existing summary stays readable without a key; only regeneration is gated."""
        cs = _make_summarizer()
        button_kwargs = []

        def _button(*args, **kwargs):
            button_kwargs.append(kwargs)
            return False

        ss = self._ss("")
        with patch("streamlit.session_state", ss), \
             patch("streamlit.title"), \
             patch("streamlit.write"), \
             patch("streamlit.columns", return_value=(MagicMock(), MagicMock())), \
             patch("streamlit.button", side_effect=_button), \
             patch.object(cs, "_CampaignSummarizer__render_summary"):
            cs._CampaignSummarizer__render_existing_summary(_SAVED_SUMMARY)
        assert button_kwargs
        assert button_kwargs[-1]["disabled"] is True

    def test_regenerate_button_enabled_with_key(self):
        cs = _make_summarizer()
        button_kwargs = []

        def _button(*args, **kwargs):
            button_kwargs.append(kwargs)
            return False

        ss = self._ss("sk-test")
        with patch("streamlit.session_state", ss), \
             patch("streamlit.title"), \
             patch("streamlit.write"), \
             patch("streamlit.columns", return_value=(MagicMock(), MagicMock())), \
             patch("streamlit.button", side_effect=_button), \
             patch.object(cs, "_CampaignSummarizer__render_summary"):
            cs._CampaignSummarizer__render_existing_summary(_SAVED_SUMMARY)
        assert button_kwargs[-1]["disabled"] is False


# ---------------------------------------------------------------------------
# run() — time warning displayed before generate button
# ---------------------------------------------------------------------------

class TestRunTimeWarning:
    def test_warning_shown_when_no_existing_summary(self):
        cs = _make_summarizer()
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        ss = _SS(
            summary_model_name="gpt-5.4-nano",
            party_members=[{"id": "1", "name": "Aria", "note_taker": True}],
            is_processing=False,
        )
        warning_calls = []
        with patch("streamlit.session_state", ss), \
             patch.object(cs, "_CampaignSummarizer__init_state_variables"), \
             patch.object(cs, "_CampaignSummarizer__process_model_options"), \
             patch.object(cs, "_notes_in_database", return_value=True), \
             patch("streamlit.title"), \
             patch("streamlit.info"), \
             patch("streamlit.warning", side_effect=lambda msg: warning_calls.append(msg)), \
             patch("streamlit.button", return_value=False), \
             patch("streamlit.stop", side_effect=StopIteration), \
             patch("streamlit.page_link"):
            try:
                cs.run()
            except StopIteration:
                pass
        assert any("minute" in msg.lower() for msg in warning_calls)


# ---------------------------------------------------------------------------
# __generate_and_display — passes party_members to generate_summary_streaming
# ---------------------------------------------------------------------------

class TestGenerateAndDisplay:
    def _run_generate(self, cs, ss, streaming_results):
        cs.summary_handler.generate_summary_streaming.return_value = iter(streaming_results)
        cs.summary_handler.get_saved_summary.return_value = {
            "summary": "Final text.",
            "model": "gpt-5.4-nano",
            "generated_at": "2026-01-01T00:00:00",
        }
        mock_slot = MagicMock()
        with patch("streamlit.session_state", ss), \
             patch("streamlit.empty", return_value=mock_slot), \
             patch("streamlit.progress", return_value=MagicMock()), \
             patch("streamlit.success"), \
             patch("streamlit.error"), \
             patch("streamlit.stop", side_effect=StopIteration), \
             patch("streamlit.markdown"), \
             patch("streamlit.sidebar", MagicMock()), \
             patch("streamlit.caption"), \
             patch("builtins.open", mock_open(read_data="{}")), \
             patch("json.load", return_value={}):
            try:
                cs._CampaignSummarizer__generate_and_display()
            except StopIteration:
                pass

    def test_passes_party_members_to_streaming(self):
        cs = _make_summarizer()
        cs.llm_handler.load_model.return_value = None
        party = [{"id": "1", "name": "Aria", "note_taker": True}]
        ss = _SS(
            summary_model_name="gpt-5.4-nano",
            openai_api_key="sk-test",
            party_members=party,
        )
        self._run_generate(cs, ss, [(False, 50, "Working..."), (True, 100, "Done")])
        cs.summary_handler.generate_summary_streaming.assert_called_once_with(
            "gpt-5.4-nano", party
        )

    def test_threads_session_api_key_into_load_model(self):
        cs = _make_summarizer()
        cs.llm_handler.load_model.return_value = None
        ss = _SS(
            summary_model_name="gpt-5.4-nano",
            openai_api_key="sk-session-key",
            party_members=[{"id": "1", "name": "Aria", "note_taker": True}],
        )
        self._run_generate(cs, ss, [(True, 100, "Done")])
        args, kwargs = cs.llm_handler.load_model.call_args
        assert args[0] == "gpt-5.4-nano"
        assert args[1] == "sk-session-key"

    def test_loads_summary_model_with_thinking_disabled(self):
        cs = _make_summarizer()
        cs.llm_handler.load_model.return_value = None
        ss = _SS(
            summary_model_name="gpt-5.4-nano",
            openai_api_key="sk-session-key",
            party_members=[{"id": "1", "name": "Aria", "note_taker": True}],
        )
        self._run_generate(cs, ss, [(True, 100, "Done")])
        assert cs.llm_handler.load_model.call_args.kwargs["disable_thinking"] is True

    def test_sets_summary_generated_true_on_success(self):
        cs = _make_summarizer()
        cs.llm_handler.load_model.return_value = None
        ss = _SS(
            summary_model_name="gpt-5.4-nano",
            openai_api_key="sk-test",
            party_members=[{"id": "1", "name": "Aria", "note_taker": True}],
            summary_generated=False,
        )
        self._run_generate(cs, ss, [(False, 50, "Working..."), (True, 100, "Done")])
        assert ss.get("summary_generated") is True


# ---------------------------------------------------------------------------
# Persistence — existing summary bypasses all generation prerequisites
# ---------------------------------------------------------------------------

_SAVED_SUMMARY = {
    "summary": "The campaign so far.",
    "model": "gpt-5.4-nano",
    "generated_at": "2026-01-01T00:00:00",
}


class TestSummaryPersistence:
    """A saved summary must be displayed without requiring notes, raw notes, or party members."""

    def _run_expecting_render(self, cs, ss):
        """Return True if __render_existing_summary was called."""
        render_called = []
        with patch("streamlit.session_state", ss), \
             patch.object(cs, "_CampaignSummarizer__init_state_variables"), \
             patch.object(cs, "_CampaignSummarizer__process_model_options"), \
             patch.object(cs, "_CampaignSummarizer__render_existing_summary",
                          side_effect=lambda s: render_called.append(s)), \
             patch("streamlit.stop", side_effect=StopIteration):
            try:
                cs.run()
            except StopIteration:
                pass
        return bool(render_called)

    def test_shows_summary_when_no_model_selected(self):
        cs = _make_summarizer()
        cs.summary_handler.get_saved_summary.return_value = _SAVED_SUMMARY
        ss = _SS(summary_model_name=None, party_members=[])
        assert self._run_expecting_render(cs, ss)

    def test_shows_summary_when_notes_not_in_database(self):
        cs = _make_summarizer()
        cs.summary_handler.get_saved_summary.return_value = _SAVED_SUMMARY
        with patch.object(cs, "_notes_in_database", return_value=False):
            ss = _SS(summary_model_name="gpt-5.4-nano", party_members=[])
            assert self._run_expecting_render(cs, ss)

    def test_shows_summary_when_raw_notes_missing(self):
        cs = _make_summarizer()
        cs.summary_handler.get_saved_summary.return_value = _SAVED_SUMMARY
        cs.summary_handler.raw_notes_exist.return_value = False
        with patch.object(cs, "_notes_in_database", return_value=True):
            ss = _SS(summary_model_name="gpt-5.4-nano", party_members=[])
            assert self._run_expecting_render(cs, ss)

    def test_shows_summary_when_no_named_party_members(self):
        cs = _make_summarizer()
        cs.summary_handler.get_saved_summary.return_value = _SAVED_SUMMARY
        cs.summary_handler.raw_notes_exist.return_value = True
        with patch.object(cs, "_notes_in_database", return_value=True):
            ss = _SS(summary_model_name="gpt-5.4-nano", party_members=[])
            assert self._run_expecting_render(cs, ss)


# ---------------------------------------------------------------------------
# __generate_and_display — error handling stores in session state, no st.stop
# ---------------------------------------------------------------------------

class TestGenerateAndDisplayErrorHandling:
    def _make_ss(self):
        return _SS(
            summary_model_name="gpt-5.4-nano",
            openai_api_key="sk-test",
            party_members=[{"id": "1", "name": "Aria", "note_taker": True}],
        )

    def test_stores_error_in_session_state_on_model_load_failure(self):
        cs = _make_summarizer()
        cs.llm_handler.load_model.side_effect = RuntimeError("model not found")
        ss = self._make_ss()
        with patch("streamlit.session_state", ss), \
             patch("builtins.open", mock_open(read_data="{}")), \
             patch("json.load", return_value={}):
            cs._CampaignSummarizer__generate_and_display()
        assert "_summary_error" in ss
        assert "gpt-5.4-nano" in ss["_summary_error"]

    def test_stores_error_in_session_state_on_generation_failure(self):
        cs = _make_summarizer()
        cs.llm_handler.load_model.return_value = None
        cs.summary_handler.generate_summary_streaming.side_effect = RuntimeError("LLM crashed")
        ss = self._make_ss()
        mock_slot = MagicMock()
        with patch("streamlit.session_state", ss), \
             patch("streamlit.empty", return_value=mock_slot), \
             patch("streamlit.progress", return_value=MagicMock()), \
             patch("builtins.open", mock_open(read_data="{}")), \
             patch("json.load", return_value={}):
            cs._CampaignSummarizer__generate_and_display()
        assert "_summary_error" in ss
        assert "LLM crashed" in ss["_summary_error"]

    def test_stores_success_flag_in_session_state_on_success(self):
        cs = _make_summarizer()
        cs.llm_handler.load_model.return_value = None
        cs.summary_handler.generate_summary_streaming.return_value = iter([
            (False, 50, "Working..."),
            (True, 100, "Summary text"),
        ])
        ss = self._make_ss()
        mock_slot = MagicMock()
        with patch("streamlit.session_state", ss), \
             patch("streamlit.empty", return_value=mock_slot), \
             patch("streamlit.progress", return_value=MagicMock()), \
             patch("builtins.open", mock_open(read_data="{}")), \
             patch("json.load", return_value={}):
            cs._CampaignSummarizer__generate_and_display()
        assert ss.get("_summary_success") is True
        assert "_summary_error" not in ss

    def _run_with_generation_error(self, cs, ss, error):
        cs.llm_handler.load_model.return_value = None
        cs.summary_handler.generate_summary_streaming.side_effect = error
        with patch("streamlit.session_state", ss), \
             patch("streamlit.empty", return_value=MagicMock()), \
             patch("streamlit.progress", return_value=MagicMock()), \
             patch("builtins.open", mock_open(read_data="{}")), \
             patch("json.load", return_value={}):
            cs._CampaignSummarizer__generate_and_display()
        return ss.get("_summary_error", "")

    def test_friendly_key_error_surfaces_verbatim(self):
        cs = _make_summarizer()
        message = self._run_with_generation_error(
            cs, self._make_ss(),
            ValueError("Your OpenAI API key was rejected. Please check your key in Model Options."),
        )
        assert message == "Your OpenAI API key was rejected. Please check your key in Model Options."

    def test_friendly_rate_limit_error_surfaces_verbatim(self):
        cs = _make_summarizer()
        message = self._run_with_generation_error(
            cs, self._make_ss(), ValueError("Rate limited. Please try again in a moment."),
        )
        assert message == "Rate limited. Please try again in a moment."

    def test_friendly_connection_error_surfaces_verbatim(self):
        cs = _make_summarizer()
        message = self._run_with_generation_error(
            cs, self._make_ss(), ValueError("Could not connect to OpenAI."),
        )
        assert message == "Could not connect to OpenAI."

    def test_friendly_error_is_not_wrapped_in_boilerplate(self):
        cs = _make_summarizer()
        message = self._run_with_generation_error(
            cs, self._make_ss(), ValueError("Your OpenAI API key was rejected."),
        )
        assert "Summary generation failed" not in message

    def test_unexpected_errors_still_get_the_generic_prefix(self):
        cs = _make_summarizer()
        message = self._run_with_generation_error(
            cs, self._make_ss(), RuntimeError("did not converge"),
        )
        assert message.startswith("Summary generation failed")

    def test_friendly_error_clears_regenerating_flag(self):
        cs = _make_summarizer()
        ss = self._make_ss()
        ss["_regenerating_summary"] = True
        self._run_with_generation_error(cs, ss, ValueError("Rate limited. Please try again."))
        assert "_regenerating_summary" not in ss

    def test_does_not_call_st_stop_on_error(self):
        cs = _make_summarizer()
        cs.llm_handler.load_model.side_effect = RuntimeError("boom")
        ss = self._make_ss()
        stop_called = []
        with patch("streamlit.session_state", ss), \
             patch("streamlit.stop", side_effect=lambda: stop_called.append(True)), \
             patch("builtins.open", mock_open(read_data="{}")), \
             patch("json.load", return_value={}):
            cs._CampaignSummarizer__generate_and_display()
        assert not stop_called


# ---------------------------------------------------------------------------
# run() phase 2 — st.rerun() called and is_processing cleared after generation
# ---------------------------------------------------------------------------

class TestRunPhase2Rerun:
    """After phase 2 generation, run() must rerun to re-enable disabled UI elements."""

    _PARTY = [{"id": "1", "name": "Aria", "note_taker": True}]

    def _run_phase2(self, cs, ss, fake_generate=None):
        rerun_called = []
        if fake_generate is None:
            fake_generate = MagicMock()

        def fake_rerun():
            rerun_called.append(True)
            raise StopIteration()

        with patch("streamlit.session_state", ss), \
             patch.object(cs, "_CampaignSummarizer__init_state_variables"), \
             patch.object(cs, "_CampaignSummarizer__process_model_options"), \
             patch.object(cs, "_notes_in_database", return_value=True), \
             patch.object(cs, "_CampaignSummarizer__generate_and_display", side_effect=fake_generate), \
             patch("streamlit.title"), \
             patch("streamlit.info"), \
             patch("streamlit.warning"), \
             patch("streamlit.error"), \
             patch("streamlit.success"), \
             patch("streamlit.stop", side_effect=StopIteration), \
             patch("streamlit.rerun", side_effect=fake_rerun):
            try:
                cs.run()
            except StopIteration:
                pass
        return rerun_called

    def _make_phase2_ss(self):
        return _SS(
            summary_model_name="gpt-5.4-nano",
            is_processing=True,
            _pending_summary_gen=True,
            party_members=self._PARTY,
        )

    def test_reruns_after_successful_generation(self):
        cs = _make_summarizer()
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        ss = self._make_phase2_ss()
        assert self._run_phase2(cs, ss)

    def test_reruns_after_generation_error(self):
        cs = _make_summarizer()
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        ss = self._make_phase2_ss()

        def store_error():
            ss['_summary_error'] = "something went wrong"

        assert self._run_phase2(cs, ss, fake_generate=store_error)

    def test_is_processing_cleared_after_phase2(self):
        cs = _make_summarizer()
        cs.summary_handler.raw_notes_exist.return_value = True
        cs.summary_handler.get_saved_summary.return_value = None
        ss = self._make_phase2_ss()
        self._run_phase2(cs, ss)
        assert ss.get("is_processing") is False
