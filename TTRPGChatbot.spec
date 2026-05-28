import sys ; sys.setrecursionlimit(sys.getrecursionlimit() * 5)
# TTRPGChatbot.spec  —  PyInstaller build configuration for the FastAPI backend
#
# Build with:
#   python3 -m PyInstaller TTRPGChatbot.spec
#
# Output: dist\ttrpg_backend\ttrpg_backend.exe  (plus supporting files)

from PyInstaller.utils.hooks import collect_all, collect_data_files, collect_submodules

# ── fastembed — ONNX-based embeddings, no PyTorch required ────────────────
fe_datas, fe_binaries, fe_hiddenimports = collect_all("fastembed")

# ── langchain_community — only data files; importing the full package via
#    collect_all pulls in every optional integration (including torch).
lcc_datas = collect_data_files("langchain_community")

# ── chromadb — uses dynamic imports for telemetry and segment backends ────
chroma_datas, chroma_binaries, chroma_hiddenimports = collect_all("chromadb")

# ── Additional hidden imports that PyInstaller's static analyser misses ───
extra_hiddenimports = [
    # ---- project source ----
    "api",
    "api.main",
    "src",
    "src.app",
    "src.app.TTRPGChatBot",
    "src.app.CampaignSummarizer",
    "src.app.NoteEditor",
    "src.utils",
    "src.utils.DatabaseHandler",
    "src.utils.LLMHandler",
    "src.utils.NavigationHandler",
    "src.utils.SummaryHandler",
    "src.utils.TextEditorHandler",
    # ---- FastAPI / ASGI stack ----
    "fastapi",
    "fastapi.middleware",
    "fastapi.middleware.cors",
    "uvicorn",
    "uvicorn.main",
    "uvicorn.config",
    "uvicorn.logging",
    "uvicorn.loops",
    "uvicorn.loops.auto",
    "uvicorn.protocols",
    "uvicorn.protocols.http",
    "uvicorn.protocols.http.auto",
    "uvicorn.protocols.websockets",
    "uvicorn.protocols.websockets.auto",
    "uvicorn.lifespan",
    "uvicorn.lifespan.on",
    "starlette",
    "starlette.middleware",
    "starlette.middleware.cors",
    "starlette.responses",
    "starlette.routing",
    "pydantic",
    "h11",
    "httptools",
    "watchfiles",
    "websockets",
    # ---- langchain stack ----
    "langchain_core",
    "langchain_core.prompts",
    "langchain_core.prompts.chat",
    "langchain_ollama",
    "langchain_chroma",
    "langchain_experimental",
    "langchain_experimental.text_splitter",
    "langchain.schema.output_parser",
    "langchain.docstore.document",
    # ---- langchain_community (only the embedding we actually use) ----
    "langchain_community.embeddings",
    "langchain_community.embeddings.fastembed",
    # ---- vector store ----
    "chromadb",
    "chromadb.db.impl",
    "chromadb.db.impl.sqlite",
    "chromadb.api.segment",
    "chromadb.telemetry.product.posthog",
    "chromadb.telemetry.product",
    "chromadb.segment.impl.manager.local",
    "chromadb.segment.impl.metadata.sqlite",
    "chromadb.segment.impl.vector.local_persistent_hnsw",
    "chromadb.segment.impl.vector.local_hnsw",
    # ---- embeddings ----
    "fastembed",
    # ---- document parsing (CSV, DOCX, TXT only — no PDF) ----
    "docx",
    # ---- data ----
    "pandas",
    "numpy",
    # ---- LLM client ----
    "ollama",
    # ---- stdlib ----
    "uuid",
    "json",
    "threading",
]

a = Analysis(
    ["api_launcher.py"],
    pathex=["."],
    binaries=[
        *fe_binaries,
        *chroma_binaries,
    ],
    datas=[
        *fe_datas,
        *lcc_datas,
        *chroma_datas,
        ("src",    "src"),
        ("api",    "api"),
        ("assets", "assets"),
    ],
    hiddenimports=[
        *fe_hiddenimports,
        *chroma_hiddenimports,
        *extra_hiddenimports,
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Streamlit and its heavy dependencies are not part of this bundle
        "streamlit",
        "altair",
        "pyarrow",
        "streamlit_quill",
        "streamlit_lottie",
        "tornado",
        # Heavy ML frameworks not used by the FastAPI backend
        "torch",
        "torchvision",
        "torchaudio",
        "transformers",
        "sentence_transformers",
        "langchain_huggingface",
        # PDF libraries — app only handles CSV, DOCX, TXT
        "pdfplumber",
        "pdfminer",
        "pypdfium2",
        # Test frameworks
        "pytest",
        "_pytest",
    ],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="ttrpg_backend",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    icon="assets/icon.ico",
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name="ttrpg_backend",
)
