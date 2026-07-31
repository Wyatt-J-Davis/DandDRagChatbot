import io
import datetime
import streamlit as st
from langchain_core.prompts import ChatPromptTemplate

_CHUNK_SUMMARY_PROMPT = ChatPromptTemplate.from_messages([
    ("system",
     "You are summarizing a section of D&D campaign journal notes. "
     "Preserve all key plot events, significant character actions and developments, "
     "important NPCs introduced or encountered, notable locations, acquired items, "
     "revealed lore, and any unresolved mysteries or story hooks. "
     "Be thorough but concise. Only include information from the provided text."),
    ("user", "Campaign notes section:\n\n{text}\n\nSummarize this section:")
])

_COMBINE_PROMPT = ChatPromptTemplate.from_messages([
    ("system",
     "You are merging multiple summaries of D&D campaign sections into one unified summary. "
     "Combine all content, eliminate redundancy, and maintain narrative flow. "
     "Do not omit any plot points, characters, locations, or events."),
    ("user", "Section summaries:\n\n{text}\n\nProvide a unified summary:")
])

_MAX_REDUCE_PASSES = 6

_FINAL_SUMMARY_PROMPT = ChatPromptTemplate.from_messages([
    ("system",
     "You are writing a comprehensive campaign overview for a D&D campaign. "
     "The player characters in this campaign are: {party_members}. "
     "Based on the provided material, create a well-organized narrative summary covering: "
     "the overall story arc and major themes, the player characters and their key contributions, "
     "significant NPCs and factions, important locations visited, major plot points and turning points, "
     "and the current state of the campaign. Write in an engaging narrative style."),
    ("user", "Campaign material:\n\n{text}\n\nWrite a comprehensive campaign summary:")
])

# ~4 characters per token is a reasonable estimate for English prose
_CHARS_PER_TOKEN = 4
# Reserve 50% of the context window for the prompt template and model response
_CONTEXT_USAGE_RATIO = 0.5


class SummaryHandler:
    # Saved content lives in session state (scoped to the browser session) rather
    # than on disk, so nothing user-generated is written to the deployment host.
    RAW_NOTES_KEY = "raw_notes_json"
    SUMMARY_KEY = "campaign_summary"

    def __init__(self, llm_handler):
        self.llm_handler = llm_handler

    def summary_exists(self):
        return bool(st.session_state.get(self.SUMMARY_KEY))

    def raw_notes_exist(self):
        return bool(st.session_state.get(self.RAW_NOTES_KEY))

    def get_saved_summary(self):
        return st.session_state.get(self.SUMMARY_KEY)

    def generate_summary_streaming(self, model_name, party_members=None):
        """
        Generator that yields (is_done, progress_pct, text) tuples.

        Intermediate yields: (False, int, status_message)
        Final yield:         (True,  100, final_summary_text)

        Algorithm: map-reduce hierarchical summarization
          1. Sort all notes chronologically.
          2. Concatenate into one text and split into context-window-safe chunks with overlap.
          3. Map phase  — summarize each chunk individually.
          4. Reduce phase — recursively combine summaries until they fit in one context window.
          5. Final synthesis — produce a narrative campaign overview from the reduced material,
             incorporating the names of the player characters.
        """
        import pandas as pd

        if not self.raw_notes_exist():
            raise FileNotFoundError("Raw notes not found. Upload notes on the main page first.")

        df = pd.read_json(io.StringIO(st.session_state[self.RAW_NOTES_KEY]))
        df = self._sort_chronologically(df)
        chunk_size = self._get_chunk_char_size(model_name)

        full_text = "\n\n---\n\n".join(
            f"[{row.get('Date', 'Unknown Date')}]\n{str(row.get('Contents', ''))}"
            for _, row in df.iterrows()
            if str(row.get('Contents', '')).strip()
        )

        chunks = self._split_into_chunks(full_text, chunk_size)
        n = len(chunks)
        party_names = self._format_party_members(party_members)

        if n == 1:
            yield (False, 10, "Generating campaign summary...")
            summary = self.llm_handler.invoke_model(
                _FINAL_SUMMARY_PROMPT, {"text": chunks[0], "party_members": party_names}
            )
        else:
            chunk_summaries = []
            for i, chunk in enumerate(chunks):
                progress = int((i / n) * 60)
                yield (False, progress, f"Summarizing section {i + 1} of {n}...")
                s = self.llm_handler.invoke_model(_CHUNK_SUMMARY_PROMPT, {"text": chunk})
                chunk_summaries.append(s)

            combined = "\n\n---\n\n".join(chunk_summaries)
            reduction_pass = 0
            while len(combined) > chunk_size:
                if reduction_pass >= _MAX_REDUCE_PASSES:
                    raise RuntimeError(
                        f"Summary reduction did not converge after {_MAX_REDUCE_PASSES} passes. "
                        "The model may be generating overly verbose output. "
                        "Try a different model or reduce the size of your campaign notes."
                    )
                prev_len = len(combined)
                reduction_pass += 1
                base_progress = min(60 + reduction_pass * 7, 80)
                yield (False, base_progress, f"Combining summaries (pass {reduction_pass})...")
                sub_chunks = self._split_into_chunks(combined, chunk_size)
                new_summaries = [
                    self.llm_handler.invoke_model(_COMBINE_PROMPT, {"text": sc})
                    for sc in sub_chunks
                ]
                combined = "\n\n---\n\n".join(new_summaries)
                if len(combined) >= prev_len:
                    raise RuntimeError(
                        "Summary reduction made no progress — the model output is not getting shorter. "
                        "The model may be generating overly verbose output. "
                        "Try a different model or reduce the size of your campaign notes."
                    )

            yield (False, 85, "Writing final campaign summary...")
            summary = self.llm_handler.invoke_model(
                _FINAL_SUMMARY_PROMPT, {"text": combined, "party_members": party_names}
            )

        result = {
            "summary": summary,
            "model": model_name,
            "generated_at": datetime.datetime.now().isoformat(),
        }
        st.session_state[self.SUMMARY_KEY] = result

        yield (True, 100, summary)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _format_party_members(self, party_members):
        if not party_members:
            return "unknown party members"
        names = [m.get("name", "").strip() for m in party_members if m.get("name", "").strip()]
        if not names:
            return "unknown party members"
        if len(names) == 1:
            return names[0]
        return ", ".join(names[:-1]) + ", and " + names[-1]

    def _split_into_chunks(self, text, chunk_size):
        """
        Split text into overlapping chunks, preferring natural break points.

        Overlap (~10% of chunk_size) is intentional: it prevents the model from
        losing context about events that straddle a chunk boundary.
        """
        if len(text) <= chunk_size:
            return [text]

        overlap = min(400, chunk_size // 10)
        chunks = []
        start = 0

        while start < len(text):
            end = start + chunk_size
            if end >= len(text):
                chunks.append(text[start:])
                break

            for sep in ("\n\n", "\n", ". ", " "):
                boundary = text.rfind(sep, start, end)
                if boundary > start:
                    end = boundary + len(sep)
                    break

            chunks.append(text[start:end])
            start = max(end - overlap, start + 1)

        return [c for c in chunks if c.strip()]

    def _get_chunk_char_size(self, model_name):
        """
        Determine the safe content chunk size (in characters) for the selected model.

        Uses the same effective context window that LLMHandler reports so
        that chunks are always sized to fit within the runtime context.
        """
        context_tokens = self.llm_handler.get_context_tokens(model_name)
        return int(context_tokens * _CONTEXT_USAGE_RATIO * _CHARS_PER_TOKEN)

    def _sort_chronologically(self, df):
        import pandas as pd

        try:
            df = df.copy()
            # Extract only the date portion (digits + separators) so trailing
            # characters like a stray colon don't prevent a valid date from parsing.
            date_strs = df["Date"].astype(str).str.extract(
                r'(\d{1,4}[-/]\d{1,2}[-/]\d{1,4})', expand=False
            )
            df["_sort_date"] = pd.to_datetime(date_strs, format="mixed", errors="coerce")
            df = df.sort_values("_sort_date", kind="stable").drop(columns=["_sort_date"])
        except Exception:
            pass
        return df.reset_index(drop=True)
