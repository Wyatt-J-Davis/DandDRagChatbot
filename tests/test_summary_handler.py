"""Unit tests for SummaryHandler — session state and LLM calls are mocked."""
import pytest
import pandas as pd
import streamlit as st
from unittest.mock import MagicMock, patch

from src.utils.SummaryHandler import SummaryHandler

RAW_NOTES_KEY = SummaryHandler.RAW_NOTES_KEY
SUMMARY_KEY = SummaryHandler.SUMMARY_KEY


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class _SS(dict):
    """Minimal session_state stand-in supporting attr and item access."""
    def __getattr__(self, name):
        try:
            return self[name]
        except KeyError:
            raise AttributeError(name)

    def __setattr__(self, name, value):
        self[name] = value

    def get(self, key, default=None):
        return self[key] if key in self else default


@pytest.fixture(autouse=True)
def _session_state():
    ss = _SS()
    with patch("streamlit.session_state", ss):
        yield ss


def _make_handler():
    """Return a SummaryHandler backed by a mock LLM."""
    return SummaryHandler(MagicMock())


def _write_raw_notes(rows=None):
    """Seed raw notes into session state as a DataFrame JSON string."""
    if rows is None:
        rows = [
            {"Date": "2023-01-01", "Contents": "The party entered the dungeon."},
            {"Date": "2023-01-08", "Contents": "They defeated the goblin king."},
        ]
    st.session_state[RAW_NOTES_KEY] = pd.DataFrame(rows).to_json()


# ---------------------------------------------------------------------------
# summary_exists / raw_notes_exist / get_saved_summary
# ---------------------------------------------------------------------------

class TestSessionChecks:
    def test_summary_exists_false_when_absent(self):
        assert _make_handler().summary_exists() is False

    def test_summary_exists_true_when_present(self):
        st.session_state[SUMMARY_KEY] = {"summary": "x"}
        assert _make_handler().summary_exists() is True

    def test_raw_notes_exist_false_when_absent(self):
        assert _make_handler().raw_notes_exist() is False

    def test_raw_notes_exist_true_when_present(self):
        _write_raw_notes()
        assert _make_handler().raw_notes_exist() is True

    def test_get_saved_summary_returns_none_when_missing(self):
        assert _make_handler().get_saved_summary() is None

    def test_get_saved_summary_returns_dict_when_present(self):
        st.session_state[SUMMARY_KEY] = {"summary": "Campaign started.", "model": "gpt-5.4-nano"}
        result = _make_handler().get_saved_summary()
        assert result["summary"] == "Campaign started."
        assert result["model"] == "gpt-5.4-nano"


# ---------------------------------------------------------------------------
# _format_party_members
# ---------------------------------------------------------------------------

class TestFormatPartyMembers:
    def setup_method(self):
        self.h = SummaryHandler(MagicMock())

    def test_none_returns_fallback(self):
        assert self.h._format_party_members(None) == "unknown party members"

    def test_empty_list_returns_fallback(self):
        assert self.h._format_party_members([]) == "unknown party members"

    def test_all_unnamed_returns_fallback(self):
        members = [{"id": "1", "name": "", "note_taker": False}]
        assert self.h._format_party_members(members) == "unknown party members"

    def test_single_named_member(self):
        members = [{"id": "1", "name": "Aria", "note_taker": True}]
        assert self.h._format_party_members(members) == "Aria"

    def test_two_named_members_uses_and(self):
        members = [
            {"id": "1", "name": "Aria", "note_taker": True},
            {"id": "2", "name": "Brom", "note_taker": False},
        ]
        result = self.h._format_party_members(members)
        assert "Aria" in result
        assert "Brom" in result
        assert "and" in result

    def test_three_members_comma_separated(self):
        members = [
            {"id": "1", "name": "Aria", "note_taker": True},
            {"id": "2", "name": "Brom", "note_taker": False},
            {"id": "3", "name": "Cael", "note_taker": False},
        ]
        result = self.h._format_party_members(members)
        assert "Aria" in result
        assert "Brom" in result
        assert "Cael" in result
        assert "and" in result

    def test_whitespace_only_name_excluded(self):
        members = [
            {"id": "1", "name": "   ", "note_taker": False},
            {"id": "2", "name": "Brom", "note_taker": False},
        ]
        result = self.h._format_party_members(members)
        assert result == "Brom"


# ---------------------------------------------------------------------------
# _split_into_chunks
# ---------------------------------------------------------------------------

class TestSplitIntoChunks:
    def setup_method(self):
        self.h = SummaryHandler(MagicMock())

    def test_single_chunk_when_text_fits(self):
        text = "Short text."
        chunks = self.h._split_into_chunks(text, chunk_size=1000)
        assert chunks == ["Short text."]

    def test_splits_into_multiple_chunks(self):
        text = "aaaa bbbb cccc dddd eeee"
        chunks = self.h._split_into_chunks(text, chunk_size=10)
        assert len(chunks) > 1

    def test_all_text_represented_across_chunks(self):
        text = "word " * 200
        chunks = self.h._split_into_chunks(text, chunk_size=100)
        combined = "".join(chunks)
        assert "word" in combined

    def test_no_empty_chunks(self):
        text = "a " * 300
        chunks = self.h._split_into_chunks(text, chunk_size=50)
        for c in chunks:
            assert c.strip() != ""

    def test_exact_fit_returns_one_chunk(self):
        text = "x" * 500
        chunks = self.h._split_into_chunks(text, chunk_size=500)
        assert len(chunks) == 1
        assert chunks[0] == text


# ---------------------------------------------------------------------------
# _sort_chronologically
# ---------------------------------------------------------------------------

class TestSortChronologically:
    def setup_method(self):
        self.h = SummaryHandler(MagicMock())

    def test_sorts_iso_dates_ascending(self):
        df = pd.DataFrame({
            "Date": ["2023-03-15", "2023-01-01", "2023-06-30"],
            "Contents": ["C", "A", "B"],
        })
        result = self.h._sort_chronologically(df)
        assert list(result["Contents"]) == ["A", "C", "B"]

    def test_unparseable_dates_do_not_raise(self):
        df = pd.DataFrame({
            "Date": ["not-a-date", "also-bad"],
            "Contents": ["X", "Y"],
        })
        result = self.h._sort_chronologically(df)
        assert len(result) == 2

    def test_returns_reset_index(self):
        df = pd.DataFrame(
            {"Date": ["2023-02-01", "2023-01-01"], "Contents": ["B", "A"]},
            index=[10, 20],
        )
        result = self.h._sort_chronologically(df)
        assert list(result.index) == [0, 1]

    def test_trailing_colon_in_date_is_parsed_correctly(self):
        df = pd.DataFrame({
            "Date": ["1/1/2023", "9/11/2024:", "3/1/2024"],
            "Contents": ["First", "Colon date", "Third"],
        })
        result = self.h._sort_chronologically(df)
        assert list(result["Contents"]) == ["First", "Third", "Colon date"]

    def test_mixed_us_format_dates_sort_chronologically(self):
        df = pd.DataFrame({
            "Date": ["12/1/2023", "1/5/2023", "6/15/2023"],
            "Contents": ["Dec", "Jan", "Jun"],
        })
        result = self.h._sort_chronologically(df)
        assert list(result["Contents"]) == ["Jan", "Jun", "Dec"]


# ---------------------------------------------------------------------------
# _get_chunk_char_size
# ---------------------------------------------------------------------------

class TestGetChunkCharSize:
    def setup_method(self):
        self.mock_llm = MagicMock()
        self.h = SummaryHandler(self.mock_llm)

    def test_returns_int(self):
        self.mock_llm.get_context_tokens.return_value = 4096
        assert isinstance(self.h._get_chunk_char_size("gpt-5.4-nano"), int)

    def test_uses_context_tokens_from_llm_handler(self):
        self.mock_llm.get_context_tokens.return_value = 8192
        size = self.h._get_chunk_char_size("gpt-5.4-nano")
        # 8192 * 0.5 (usage ratio) * 4 (chars/token)
        assert size == 16384

    def test_chunk_size_matches_default_context_tokens(self):
        self.mock_llm.get_context_tokens.return_value = 4096
        size = self.h._get_chunk_char_size("gpt-5.4-nano")
        assert size == 8192

    def test_delegates_model_name_to_llm_handler(self):
        self.mock_llm.get_context_tokens.return_value = 4096
        self.h._get_chunk_char_size("some-other-model")
        self.mock_llm.get_context_tokens.assert_called_once_with("some-other-model")


# ---------------------------------------------------------------------------
# generate_summary_streaming
# ---------------------------------------------------------------------------

class TestGenerateSummaryStreaming:
    def test_raises_when_raw_notes_missing(self):
        h = _make_handler()
        with pytest.raises(FileNotFoundError):
            list(h.generate_summary_streaming("gpt-5.4-nano"))

    def test_yields_only_false_then_true(self):
        _write_raw_notes()
        h = _make_handler()
        h.llm_handler.invoke_model.return_value = "The campaign summary."

        with patch.object(h, "_get_chunk_char_size", return_value=100_000), \
             patch.object(h, "_sort_chronologically", side_effect=lambda df: df):
            results = list(h.generate_summary_streaming("gpt-5.4-nano"))

        done_results = [r for r in results if r[0] is True]
        progress_results = [r for r in results if r[0] is False]
        assert len(done_results) == 1
        assert len(progress_results) >= 1

    def test_final_yield_contains_summary_text(self):
        _write_raw_notes()
        h = _make_handler()
        h.llm_handler.invoke_model.return_value = "Narrative summary text."

        with patch.object(h, "_get_chunk_char_size", return_value=100_000):
            results = list(h.generate_summary_streaming("gpt-5.4-nano"))

        is_done, progress, text = results[-1]
        assert is_done is True
        assert progress == 100
        assert "Narrative summary text." in text

    def test_saves_summary_to_session_state(self):
        _write_raw_notes()
        h = _make_handler()
        h.llm_handler.invoke_model.return_value = "Saved summary."

        with patch.object(h, "_get_chunk_char_size", return_value=100_000):
            list(h.generate_summary_streaming("gpt-5.4-nano"))

        data = st.session_state[SUMMARY_KEY]
        assert data["summary"] == "Saved summary."
        assert data["model"] == "gpt-5.4-nano"
        assert "generated_at" in data

    def test_multi_chunk_calls_invoke_multiple_times(self):
        _write_raw_notes(rows=[
            {"Date": "2023-01-01", "Contents": "A " * 500},
            {"Date": "2023-01-02", "Contents": "B " * 500},
        ])
        h = _make_handler()
        h.llm_handler.invoke_model.return_value = "chunk summary"

        with patch.object(h, "_get_chunk_char_size", return_value=200):
            list(h.generate_summary_streaming("gpt-5.4-nano"))

        assert h.llm_handler.invoke_model.call_count > 1

    def test_progress_values_are_within_range(self):
        _write_raw_notes()
        h = _make_handler()
        h.llm_handler.invoke_model.return_value = "ok"

        with patch.object(h, "_get_chunk_char_size", return_value=100_000):
            results = list(h.generate_summary_streaming("gpt-5.4-nano"))

        for _, progress, _ in results:
            assert 0 <= progress <= 100

    def test_party_members_included_in_final_summary_prompt(self):
        _write_raw_notes()
        h = _make_handler()
        h.llm_handler.invoke_model.return_value = "Summary with party."

        party = [
            {"id": "1", "name": "Aria", "note_taker": True},
            {"id": "2", "name": "Brom", "note_taker": False},
        ]

        with patch.object(h, "_get_chunk_char_size", return_value=100_000):
            list(h.generate_summary_streaming("gpt-5.4-nano", party_members=party))

        # The final invoke_model call should include party_members in its input dict
        last_call_kwargs = h.llm_handler.invoke_model.call_args
        input_dict = last_call_kwargs.args[1]
        assert "party_members" in input_dict
        assert "Aria" in input_dict["party_members"]
        assert "Brom" in input_dict["party_members"]

    def test_generate_without_party_members_does_not_raise(self):
        _write_raw_notes()
        h = _make_handler()
        h.llm_handler.invoke_model.return_value = "Summary."

        with patch.object(h, "_get_chunk_char_size", return_value=100_000):
            results = list(h.generate_summary_streaming("gpt-5.4-nano", party_members=None))

        assert results[-1][0] is True

    def test_generate_with_empty_party_members_does_not_raise(self):
        _write_raw_notes()
        h = _make_handler()
        h.llm_handler.invoke_model.return_value = "Summary."

        with patch.object(h, "_get_chunk_char_size", return_value=100_000):
            results = list(h.generate_summary_streaming("gpt-5.4-nano", party_members=[]))

        assert results[-1][0] is True

    def test_chunk_sizing_uses_llm_handler_context_clamp(self):
        from src.utils.LLMHandler import _MAX_CONTEXT_TOKENS

        h = _make_handler()
        h.llm_handler.get_context_tokens.return_value = _MAX_CONTEXT_TOKENS
        assert h._get_chunk_char_size("gpt-5.4-nano") == 32768

    def test_multi_chunk_runs_full_map_reduce_to_completion(self):
        _write_raw_notes(rows=[
            {"Date": "2023-01-01", "Contents": "A " * 2000},
            {"Date": "2023-01-02", "Contents": "B " * 2000},
            {"Date": "2023-01-03", "Contents": "C " * 2000},
        ])
        h = _make_handler()
        # Map output is verbose enough to force a reduce pass; the combine pass
        # then returns something short, so the loop converges.
        state = {"calls": 0}

        def _shrinking(*a, **k):
            state["calls"] += 1
            return "summary text " * 20 if state["calls"] <= 30 else "short summary"

        h.llm_handler.invoke_model.side_effect = _shrinking

        with patch.object(h, "_get_chunk_char_size", return_value=500):
            results = list(h.generate_summary_streaming("gpt-5.4-nano"))

        statuses = [text for done, _, text in results if not done]
        assert any("Summarizing section" in s for s in statuses)
        assert any("Combining summaries" in s for s in statuses)
        assert any("Writing final campaign summary" in s for s in statuses)
        assert results[-1][0] is True

        data = st.session_state[SUMMARY_KEY]
        assert data["model"] == "gpt-5.4-nano"
        assert data["summary"]

    def test_reduce_loop_raises_when_it_does_not_converge(self):
        from src.utils.SummaryHandler import _MAX_REDUCE_PASSES

        _write_raw_notes(rows=[
            {"Date": "2023-01-01", "Contents": "A " * 2000},
            {"Date": "2023-01-02", "Contents": "B " * 2000},
        ])
        h = _make_handler()
        # Each pass makes real progress but shrinks the material only slowly,
        # so it would need far more than the cap to fit — the pass cap is the
        # only thing that stops this, and it must, so the summarizer can't hang.
        def _slowly_shrinking(prompt, mappings):
            return "x" * max(int(len(mappings["text"]) * 0.7), 1)

        h.llm_handler.invoke_model.side_effect = _slowly_shrinking

        with patch.object(h, "_get_chunk_char_size", return_value=300):
            with pytest.raises(RuntimeError, match="did not converge"):
                list(h.generate_summary_streaming("gpt-5.4-nano"))

        assert h.llm_handler.invoke_model.call_count <= _MAX_REDUCE_PASSES * 50

    def test_reduce_loop_raises_when_model_output_does_not_shrink(self):
        _write_raw_notes(rows=[
            {"Date": "2023-01-01", "Contents": "A " * 500},
            {"Date": "2023-01-02", "Contents": "B " * 500},
        ])
        h = _make_handler()
        # Model returns very verbose output — combined never shrinks below chunk_size
        h.llm_handler.invoke_model.return_value = "word " * 200  # ~1000 chars

        with patch.object(h, "_get_chunk_char_size", return_value=200):
            with pytest.raises(RuntimeError):
                list(h.generate_summary_streaming("gpt-5.4-nano"))
