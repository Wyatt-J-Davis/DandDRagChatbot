"""
Patch heavy/external dependencies before any project modules are imported.
AppTest runs in the same process, so sys.modules patches apply to the app too.
"""
import sys
import os
import pytest
from unittest.mock import MagicMock

# Ensure project root is on path for absolute imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# --- openai ---
mock_openai = MagicMock()
sys.modules["openai"] = mock_openai

# --- langchain_openai ---
mock_langchain_openai = MagicMock()
sys.modules["langchain_openai"] = mock_langchain_openai

# --- FastEmbed embeddings (replaces HuggingFace) ---
mock_fastembed = MagicMock()
sys.modules["fastembed"] = mock_fastembed
# langchain_community.embeddings.FastEmbedEmbeddings is imported at module level
mock_lc_community = MagicMock()
mock_lc_community.embeddings.FastEmbedEmbeddings = MagicMock()
sys.modules["langchain_community"] = mock_lc_community
sys.modules["langchain_community.embeddings"] = mock_lc_community.embeddings

# --- Chroma vector store ---
mock_chroma_mod = MagicMock()
sys.modules["langchain_chroma"] = mock_chroma_mod

# --- SemanticChunker ---
mock_exp = MagicMock()
mock_exp_splitter = MagicMock()
sys.modules["langchain_experimental"] = mock_exp
sys.modules["langchain_experimental.text_splitter"] = mock_exp_splitter

# --- streamlit_lottie ---
sys.modules["streamlit_lottie"] = MagicMock()

# --- st_tiny_editor ---
sys.modules["st_tiny_editor"] = MagicMock()

# --- torch / transformers / HuggingFace (no longer used but may be
#     pulled in transitively by other langchain packages) ---
for heavy in ("torch", "torchvision", "transformers",
              "sentence_transformers", "langchain_huggingface"):
    if heavy not in sys.modules:
        sys.modules[heavy] = MagicMock()


@pytest.fixture(autouse=True)
def _isolate_user_data(tmp_path, monkeypatch):
    """Redirect _USERDATAFILE to a temp path so tests never read/write production data."""
    import src.app.TTRPGChatBot as chatbot_module
    monkeypatch.setattr(chatbot_module.TTRPGChatbot, "_USERDATAFILE", str(tmp_path / "user_data_test.json"))
    yield tmp_path
