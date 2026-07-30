import os
import re
import json
import streamlit as st
from streamlit_lottie import st_lottie

from ..utils import LLMHandler
from ..utils import SummaryHandler
from ..utils.ModelOptions import ModelOptions


class CampaignSummarizer:
    _USERDATAFILE = "data//user_data.json"

    def __init__(self):
        self.llm_handler = LLMHandler.LLMHandler()
        self.summary_handler = SummaryHandler.SummaryHandler(self.llm_handler)

    def _notes_in_database(self):
        return self.summary_handler.raw_notes_exist()

    def __init_state_variables(self):
        if 'is_processing' not in st.session_state:
            st.session_state.is_processing = False

        # The API key is session-only and never restored from disk.
        if 'openai_api_key' not in st.session_state:
            st.session_state.openai_api_key = ""

        needs_model_init = "summary_model_name" not in st.session_state
        needs_party_init = "party_members" not in st.session_state

        if needs_model_init or needs_party_init:
            user_data = {}
            if os.path.isfile(self._USERDATAFILE):
                try:
                    with open(self._USERDATAFILE, "r") as f:
                        user_data = json.load(f)
                except Exception:
                    pass

            if needs_model_init:
                st.session_state.summary_model_name = user_data.get("summary_model_name")

            if needs_party_init:
                st.session_state.party_members = user_data.get("party_members", [])

    def __process_model_options(self):
        modeloptions = ModelOptions(self.llm_handler)
        with st.sidebar:
            st.header("🔧 Model Options")
            st.session_state.openai_api_key = st.text_input(
                "OpenAI API Key",
                type="password",
                value=st.session_state.get("openai_api_key", ""),
                help="Your key is used only for this session and is never saved to disk.",
                disabled=st.session_state.is_processing,
            )
            available_model_names, model_error = modeloptions.resolve_models(
                st.session_state.openai_api_key)

            if model_error:
                st.error(model_error)

            if available_model_names:
                valid_model, warning = modeloptions.validate_persisted_model(
                    st.session_state.summary_model_name, available_model_names)
                st.session_state.summary_model_name = valid_model
                if warning:
                    st.warning(warning)

            selected_model = st.selectbox(
                "Select Model",
                available_model_names,
                index=ModelOptions.preselect_index(st.session_state.summary_model_name, available_model_names) if available_model_names else None,
                disabled=st.session_state.is_processing or not available_model_names,
            )
            if selected_model is not None:
                st.session_state.summary_model_name = selected_model
                self.__save_user_data()

    def __save_user_data(self):
        existing = {}
        if os.path.isfile(self._USERDATAFILE):
            try:
                with open(self._USERDATAFILE, "r") as f:
                    existing = json.load(f)
            except Exception:
                pass
        existing["summary_model_name"] = st.session_state.summary_model_name
        os.makedirs("data", exist_ok=True)
        with open(self._USERDATAFILE, "w") as f:
            json.dump(existing, f)

    def run(self):
        """Entry point for the campaign summary Streamlit page."""
        self.__init_state_variables()
        self.__process_model_options()

        error_msg = st.session_state.pop('_summary_error', None)
        was_success = st.session_state.pop('_summary_success', False)

        existing = self.summary_handler.get_saved_summary()
        if existing and not st.session_state.get("_regenerating_summary"):
            if was_success:
                st.success("Campaign summary generated!")
            if error_msg:
                st.error(error_msg)
            self.__render_existing_summary(existing)
            st.stop()

        if not st.session_state.get("summary_model_name"):
            st.title("📖 Campaign Summary")
            st.info("Please select a model in **Model Options** on the sidebar before viewing the campaign summary.")
            st.stop()

        if not self._notes_in_database():
            st.title("📖 Campaign Summary")
            st.info("No campaign notes found. Please upload your notes on the Q&A page first.")
            st.stop()

        if not self.summary_handler.raw_notes_exist():
            st.title("📖 Campaign Summary")
            st.info("Campaign notes were found but the raw notes file needed for summarization is missing. Please re-upload your notes on the Q&A page.")
            st.stop()

        party_members = st.session_state.get("party_members", []) or []
        named_members = [m for m in party_members if m.get("name", "").strip()]
        if not named_members:
            st.title("📖 Campaign Summary")
            st.info("Please define your party members on the Q&A page before generating a campaign summary.")
            st.stop()

        st.title("📖 Campaign Summary")

        if error_msg:
            st.error(error_msg)

        # Phase 2: execute pending summary generation (widgets already disabled from Phase 1 rerun)
        if st.session_state.pop('_pending_summary_gen', False):
            try:
                self.__generate_and_display()
            finally:
                st.session_state.is_processing = False
            st.rerun()
            return

        st.info("No campaign summary has been generated yet.")

        has_key = bool(st.session_state.get("openai_api_key"))
        if not has_key:
            st.info(LLMHandler.missing_key_message())

        # Phase 1: capture button click and rerun with UI disabled
        if not st.button("✨ Generate Campaign Summary", type="primary",
                         disabled=st.session_state.is_processing or not has_key):
            st.stop()

        st.session_state.is_processing = True
        st.session_state._pending_summary_gen = True
        st.rerun()

    def __render_existing_summary(self, existing):
        generated_date = existing.get("generated_at", "")[:10]
        model_used = existing.get("model", "unknown model")

        header_col, btn_col = st.columns([5, 1])
        with header_col:
            st.title("📖 Campaign Summary")
        with btn_col:
            st.write("")
            # A saved summary stays readable without a key; only regeneration is gated.
            has_key = bool(st.session_state.get("openai_api_key"))
            if st.button("🔄 Regenerate", use_container_width=True,
                         disabled=st.session_state.is_processing or not has_key,
                         help=LLMHandler.missing_key_message() if not has_key else None):
                st.session_state._regenerating_summary = True
                st.rerun()

        self.__render_summary(existing["summary"], model_used, generated_date)

    def __extract_headers(self, text):
        return [
            (len(m.group(1)), m.group(2).strip())
            for m in re.finditer(r'^(#{1,3})\s+(.+)$', text, re.MULTILINE)
        ]

    def __render_summary(self, summary_text, model_used, generated_date):
        headers = self.__extract_headers(summary_text)

        with st.sidebar:
            if headers:
                st.markdown("**Contents**")
                for level, title in headers:
                    indent = "&nbsp;" * (4 * (level - 1))
                    st.markdown(f"{indent}• {title}", unsafe_allow_html=True)
                st.divider()
            st.caption(f"Model: **{model_used}**")
            st.caption(f"Generated: {generated_date}")

        st.markdown(summary_text)

    def __generate_and_display(self):
        model_name = st.session_state.summary_model_name
        party_members = st.session_state.get("party_members", [])
        api_key = st.session_state.get("openai_api_key", "")

        try:
            self.llm_handler.load_model(str(model_name), api_key, disable_thinking=True)
        except Exception as e:
            st.session_state._summary_error = f"Could not load model **{model_name}**: {e}"
            st.session_state.pop("_regenerating_summary", None)
            return

        try:
            with open("assets/star-magic.json", "r", errors="ignore") as f:
                magic_spinner = json.load(f)
        except Exception:
            magic_spinner = None

        animation_slot = st.empty()
        progress_slot = st.empty()

        if magic_spinner:
            with animation_slot.container():
                st_lottie(magic_spinner, height=200, key="summary_page_spinner")

        progress_bar = progress_slot.progress(0, text="Starting summary generation...")

        final_summary = None
        try:
            for is_done, progress, text in self.summary_handler.generate_summary_streaming(model_name, party_members):
                if is_done:
                    final_summary = text
                    st.session_state.summary_generated = True
                else:
                    progress_bar.progress(progress / 100, text=text)
        except ValueError as e:
            # LLMHandler already translated this into user-facing text.
            animation_slot.empty()
            progress_slot.empty()
            st.session_state.pop("_regenerating_summary", None)
            st.session_state._summary_error = str(e)
            return
        except Exception as e:
            animation_slot.empty()
            progress_slot.empty()
            st.session_state.pop("_regenerating_summary", None)
            st.session_state._summary_error = f"Summary generation failed: {e}"
            return

        animation_slot.empty()
        progress_slot.empty()
        st.session_state.pop("_regenerating_summary", None)

        if final_summary:
            st.session_state._summary_success = True
        else:
            st.session_state._summary_error = "Summary generation returned no content."
