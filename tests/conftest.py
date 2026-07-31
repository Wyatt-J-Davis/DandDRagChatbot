"""
Patch heavy/external dependencies before any project modules are imported.
AppTest runs in the same process, so sys.modules patches apply to the app too.
"""
import sys
import os
from unittest.mock import MagicMock

# Ensure project root is on path for absolute imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# --- openai ---
# Deliberately NOT mocked: LLMHandler catches openai's real exception classes to
# translate them into user-facing messages, and `except <MagicMock>` is a
# TypeError.  The package is a thin HTTP client, so importing it is cheap.

# --- langchain_openai ---
# OpenAIEmbeddings and ChatOpenAI are imported at module level; mocking the
# package keeps tests off the network.
mock_langchain_openai = MagicMock()
sys.modules["langchain_openai"] = mock_langchain_openai

# --- Chroma vector store ---
mock_chroma_mod = MagicMock()
sys.modules["langchain_chroma"] = mock_chroma_mod

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
