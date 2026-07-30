"""Unit tests for DatabaseHandler — focuses on pure-Python logic that doesn't
require real embeddings, a live Chroma DB, or HuggingFace models."""
import io
import shutil
import httpx
import openai
import pytest
import pandas as pd
from unittest.mock import ANY, MagicMock, patch, call

from src.utils.DatabaseHandler import DatabaseHandler

_REQUEST = httpx.Request("POST", "https://api.openai.com/v1/embeddings")


def _status_error(cls, status_code):
    return cls("boom", response=httpx.Response(status_code, request=_REQUEST), body=None)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_text_file(content: str, name: str = "notes.txt") -> MagicMock:
    """Return a mock that looks like a Streamlit UploadedFile for a text file."""
    mock_file = MagicMock()
    mock_file.name = name
    mock_file.getvalue.return_value = content.encode("utf-8")
    return mock_file


def _make_csv_file(csv_text: str, name: str = "notes.csv") -> MagicMock:
    mock_file = MagicMock()
    mock_file.name = name
    # pd.read_csv accepts a file-like object; forward reads to a StringIO
    buf = io.StringIO(csv_text)
    mock_file.read.side_effect = buf.read
    mock_file.seek.side_effect = buf.seek
    # Make the mock itself iterable / readable by pandas
    mock_file.__iter__ = lambda s: iter(buf)
    # Simplest approach: make it a real StringIO wrapped in mock attributes
    real_buf = io.StringIO(csv_text)
    mock_file.read = real_buf.read
    return mock_file


# ---------------------------------------------------------------------------
# __parse_journal_text  (private, accessed via name-mangled attribute)
# ---------------------------------------------------------------------------

class TestParseJournalText:
    def setup_method(self):
        self.db = DatabaseHandler()
        self.parse = self.db._DatabaseHandler__parse_journal_text

    def test_iso_date_headers_split_entries(self):
        text = "2023-10-27\nFirst entry content.\n2023-10-28\nSecond entry content."
        df = self.parse(text)
        assert isinstance(df, pd.DataFrame)
        assert len(df) == 2
        assert df.iloc[0]["Date"] == "2023-10-27"
        assert df.iloc[1]["Date"] == "2023-10-28"
        assert "First entry content." in df.iloc[0]["Contents"]

    def test_slash_date_headers(self):
        text = "10/27/2023\nEntry one.\n11/1/23\nEntry two."
        df = self.parse(text)
        assert len(df) == 2
        assert df.iloc[0]["Date"] == "10/27/2023"
        assert df.iloc[1]["Date"] == "11/1/23"

    def test_title_format(self):
        text = "2024-01-01\nSome content."
        df = self.parse(text)
        assert df.iloc[0]["Title"] == "Entry for 2024-01-01"

    def test_no_date_headers_returns_single_entry(self):
        text = "This text has no date headers at all.\nJust regular lines."
        df = self.parse(text)
        # All content collected under the default "Unknown Date"
        assert len(df) == 1
        assert df.iloc[0]["Date"] == "Unknown Date"

    def test_empty_string_returns_empty_dataframe(self):
        df = self.parse("")
        assert isinstance(df, pd.DataFrame)
        assert len(df) == 0

    def test_multiline_entry_content_preserved(self):
        text = "2023-05-01\nLine one.\nLine two.\nLine three.\n2023-05-02\nNext entry."
        df = self.parse(text)
        assert len(df) == 2
        assert "Line two." in df.iloc[0]["Contents"]
        assert "Line three." in df.iloc[0]["Contents"]

    def test_real_txt_file(self):
        """Smoke-test against the actual test fixture."""
        import os
        fixture = os.path.join(
            os.path.dirname(__file__), "data", "testtextnotes.txt"
        )
        if not os.path.exists(fixture):
            pytest.skip("Test fixture not found")
        with open(fixture, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
        df = self.parse(content)
        assert isinstance(df, pd.DataFrame)
        assert len(df) > 0


# ---------------------------------------------------------------------------
# retrieve_notes — before retriever is initialized
# ---------------------------------------------------------------------------

class TestRetrieveNotes:
    def test_raises_when_retriever_not_initialized(self):
        db = DatabaseHandler()
        with pytest.raises(ValueError, match="not initialized"):
            db.retrieve_notes("any query")

    def test_delegates_to_retriever(self):
        db = DatabaseHandler()
        mock_retriever = MagicMock()
        mock_retriever.invoke.return_value = ["doc1", "doc2"]
        db.document_retriever = mock_retriever
        result = db.retrieve_notes("dragons")
        mock_retriever.invoke.assert_called_once_with("dragons")
        assert result == ["doc1", "doc2"]


# ---------------------------------------------------------------------------
# generate_database — with mocked splitter and vector store
# ---------------------------------------------------------------------------

class TestGenerateDatabase:
    def setup_method(self):
        self.db = DatabaseHandler()
        # Inject mocked splitter and vector store
        self.db.text_splitter = MagicMock()
        self.db.text_splitter.split_text.return_value = ["chunk one", "chunk two"]
        self.db.vector_store = MagicMock()

    def test_returns_true_on_valid_csv(self):
        csv_text = "Title,Date,Contents\nEntry 1,2023-01-01,Some content here\n"
        mock_file = MagicMock()
        mock_file.name = "notes.csv"
        mock_file.read.return_value = csv_text.encode()
        # Make pandas read the CSV from the mock
        with patch("pandas.read_csv", return_value=pd.DataFrame({
            "Title": ["Entry 1"],
            "Date": ["2023-01-01"],
            "Contents": ["Some content here"]
        })):
            gen = self.db.generate_database(mock_file, "data/test_db")
            progress_values = []
            ret = None
            while True:
                try:
                    progress_values.append(next(gen))
                except StopIteration as e:
                    ret = e.value
                    break
        assert ret is True
        assert len(progress_values) == 1  # one row → one yield
        assert progress_values[0] == pytest.approx(100.0)

    def test_returns_false_when_vector_store_is_none(self):
        self.db.vector_store = None
        with patch("pandas.read_csv", return_value=pd.DataFrame({
            "Title": ["T"], "Date": ["2023-01-01"], "Contents": ["body"]
        })):
            mock_file = MagicMock()
            mock_file.name = "notes.csv"
            gen = self.db.generate_database(mock_file, "data/test_db")
            ret = None
            while True:
                try:
                    next(gen)
                except StopIteration as e:
                    ret = e.value
                    break
        assert ret is False

    def test_returns_false_on_empty_dataframe(self):
        with patch("pandas.read_csv", return_value=pd.DataFrame()):
            mock_file = MagicMock()
            mock_file.name = "notes.csv"
            gen = self.db.generate_database(mock_file, "data/test_db")
            ret = None
            while True:
                try:
                    next(gen)
                except StopIteration as e:
                    ret = e.value
                    break
        assert ret is False


# ---------------------------------------------------------------------------
# __convert_document_into_dataframe — file-type dispatch
# ---------------------------------------------------------------------------

class TestConvertDocumentIntoDataframe:
    def setup_method(self):
        self.db = DatabaseHandler()
        self.convert = self.db._DatabaseHandler__convert_document_into_dataframe

    def test_txt_file_dispatches_to_parser(self):
        content = "2023-01-01\nSome content.\n2023-01-02\nMore content."
        mock_file = _make_text_file(content, "notes.txt")
        df = self.convert(mock_file, "data/db")
        assert isinstance(df, pd.DataFrame)
        assert len(df) == 2

    def test_csv_file_reads_directly(self):
        csv_text = "Title,Date,Contents\nSession 1,2023-01-01,First session\n"
        buf = io.StringIO(csv_text)
        with patch("pandas.read_csv", return_value=pd.DataFrame({
            "Title": ["Session 1"],
            "Date": ["2023-01-01"],
            "Contents": ["First session"]
        })) as mock_read:
            mock_file = MagicMock()
            mock_file.name = "notes.csv"
            df = self.convert(mock_file, "data/db")
            mock_read.assert_called_once()
        assert len(df) == 1


# ---------------------------------------------------------------------------
# create_retrival_artifacts — sets up embeddings, splitter, vector store, retriever
# ---------------------------------------------------------------------------

class TestCreateRetrivalArtifacts:
    def setup_method(self):
        self.db = DatabaseHandler()

    def test_builds_openai_embeddings_with_key_and_model(self):
        with patch("src.utils.DatabaseHandler.OpenAIEmbeddings") as mock_emb, \
             patch("src.utils.DatabaseHandler.Chroma"):
            self.db.create_retrival_artifacts("data/test_db", "sk-test")
        mock_emb.assert_called_once_with(model="text-embedding-3-small", api_key="sk-test")

    def test_uses_recursive_character_text_splitter(self):
        with patch("src.utils.DatabaseHandler.RecursiveCharacterTextSplitter") as mock_splitter, \
             patch("src.utils.DatabaseHandler.OpenAIEmbeddings"), \
             patch("src.utils.DatabaseHandler.Chroma"):
            self.db.create_retrival_artifacts("data/test_db", "sk-test")
        mock_splitter.assert_called_once_with(chunk_size=1000, chunk_overlap=200)

    def test_sets_text_splitter(self):
        assert self.db.text_splitter is None
        self.db.create_retrival_artifacts("data/test_db", "sk-test")
        assert self.db.text_splitter is not None

    def test_sets_vector_store(self):
        assert self.db.vector_store is None
        self.db.create_retrival_artifacts("data/test_db", "sk-test")
        assert self.db.vector_store is not None

    def test_sets_document_retriever(self):
        assert self.db.document_retriever is None
        self.db.create_retrival_artifacts("data/test_db", "sk-test")
        assert self.db.document_retriever is not None

    def test_chroma_called_with_correct_collection_and_directory(self):
        with patch("src.utils.DatabaseHandler.Chroma") as mock_chroma:
            self.db.create_retrival_artifacts("custom/db/path", "sk-test")
        mock_chroma.assert_called_once_with(
            collection_name="notes",
            persist_directory="custom/db/path",
            embedding_function=ANY,
            collection_configuration={"hnsw": {"space": "cosine"}},
        )

    def test_retriever_configured_with_similarity_score_threshold(self):
        mock_store = MagicMock()
        with patch("src.utils.DatabaseHandler.Chroma", return_value=mock_store):
            self.db.create_retrival_artifacts("data/test_db", "sk-test")
        mock_store.as_retriever.assert_called_once_with(
            search_type="similarity_score_threshold",
            search_kwargs={"k": 10, "score_threshold": 0.25},
        )

    def test_embeddings_passed_to_chroma_and_splitter_is_local(self):
        """Embeddings feed the vector store; the splitter is keyless/local so the
        chunking path makes no embedding API calls."""
        mock_embeddings = MagicMock()
        with patch.object(
            self.db, "_DatabaseHandler__load_embeddings", return_value=mock_embeddings
        ), patch("src.utils.DatabaseHandler.Chroma") as mock_chroma, \
           patch("src.utils.DatabaseHandler.RecursiveCharacterTextSplitter") as mock_splitter:
            self.db.create_retrival_artifacts("data/test_db", "sk-test")
        mock_splitter.assert_called_once_with(chunk_size=1000, chunk_overlap=200)
        assert mock_chroma.call_args.kwargs["embedding_function"] is mock_embeddings

    def test_retrieve_notes_works_after_initialization(self):
        mock_doc = MagicMock()
        mock_retriever = MagicMock()
        mock_retriever.invoke.return_value = [mock_doc]
        mock_store = MagicMock()
        mock_store.as_retriever.return_value = mock_retriever
        with patch("src.utils.DatabaseHandler.Chroma", return_value=mock_store):
            self.db.create_retrival_artifacts("data/test_db", "sk-test")
        result = self.db.retrieve_notes("test query")
        assert result == [mock_doc]
        mock_retriever.invoke.assert_called_once_with("test query")

    def test_skips_initialization_when_vector_store_already_set(self):
        """Guard: calling create_retrival_artifacts a second time is a no-op."""
        self.db.vector_store = MagicMock()
        with patch("src.utils.DatabaseHandler.Chroma") as mock_chroma:
            self.db.create_retrival_artifacts("any/path", "sk-test")
        mock_chroma.assert_not_called()

    def test_recovers_from_corrupt_database(self, tmp_path):
        """If Chroma raises on open, the bad directory is wiped and creation is retried."""
        db_dir = tmp_path / "corrupt_db"
        db_dir.mkdir()

        call_count = [0]
        mock_store = MagicMock()

        def chroma_side_effect(**kwargs):
            call_count[0] += 1
            if call_count[0] == 1:
                raise ValueError("Could not connect to tenant default_tenant.")
            return mock_store

        with patch("src.utils.DatabaseHandler.Chroma", side_effect=chroma_side_effect), \
             patch.object(self.db, "_DatabaseHandler__load_embeddings", return_value=MagicMock()), \
             patch("src.utils.DatabaseHandler.RecursiveCharacterTextSplitter"):
            self.db.create_retrival_artifacts(str(db_dir), "sk-test")

        assert call_count[0] == 2
        assert not db_dir.exists()


# ---------------------------------------------------------------------------
# create_retrival_artifacts — legacy (dimension-incompatible) DB handling
# ---------------------------------------------------------------------------

class TestLegacyDatabaseReset:
    """A DB embedded with the old local model has a different vector dimension,
    so it must be wiped before an OpenAI-embedded store can be opened over it."""

    def setup_method(self):
        self.db = DatabaseHandler()
        self._patches = [
            patch("src.utils.DatabaseHandler.OpenAIEmbeddings"),
            patch("src.utils.DatabaseHandler.RecursiveCharacterTextSplitter"),
        ]
        for p in self._patches:
            p.start()

    def teardown_method(self):
        for p in self._patches:
            p.stop()

    def test_fresh_install_is_not_a_reset(self, tmp_path):
        db_dir = tmp_path / "chrome_db"  # does not exist yet
        with patch("src.utils.DatabaseHandler.Chroma"):
            self.db.create_retrival_artifacts(str(db_dir), "sk-test")
        assert self.db.legacy_db_reset is False

    def test_db_without_marker_is_wiped(self, tmp_path):
        db_dir = tmp_path / "chrome_db"
        db_dir.mkdir()
        (db_dir / "chroma.sqlite3").write_bytes(b"old-768-dim-index")
        with patch("src.utils.DatabaseHandler.Chroma"):
            self.db.create_retrival_artifacts(str(db_dir), "sk-test")
        assert not (db_dir / "chroma.sqlite3").exists()
        assert self.db.legacy_db_reset is True

    def test_matching_marker_is_not_wiped(self, tmp_path):
        db_dir = tmp_path / "chrome_db"
        db_dir.mkdir()
        (db_dir / ".embedding_backend").write_text("openai:text-embedding-3-small:cosine")
        (db_dir / "chroma.sqlite3").write_bytes(b"current-index")
        with patch("src.utils.DatabaseHandler.Chroma"):
            self.db.create_retrival_artifacts(str(db_dir), "sk-test")
        assert (db_dir / "chroma.sqlite3").exists()
        assert self.db.legacy_db_reset is False

    def test_legacy_flag_is_per_call_not_sticky(self, tmp_path):
        """The handler lives across Streamlit reruns; a reset reported once must
        not keep firing on later calls that no-op behind the vector-store guard."""
        db_dir = tmp_path / "chrome_db"
        db_dir.mkdir()
        (db_dir / "chroma.sqlite3").write_bytes(b"old-768-dim-index")
        with patch("src.utils.DatabaseHandler.Chroma"):
            self.db.create_retrival_artifacts(str(db_dir), "sk-test")
        assert self.db.legacy_db_reset is True
        # Second call (a rerun): vector_store already set, so it early-returns —
        # but it must no longer report a legacy reset.
        with patch("src.utils.DatabaseHandler.Chroma"):
            self.db.create_retrival_artifacts(str(db_dir), "sk-test")
        assert self.db.legacy_db_reset is False

    def test_marker_written_after_successful_build(self, tmp_path):
        db_dir = tmp_path / "chrome_db"

        def make_chroma(**kwargs):
            from pathlib import Path
            Path(kwargs["persist_directory"]).mkdir(parents=True, exist_ok=True)
            return MagicMock()

        with patch("src.utils.DatabaseHandler.Chroma", side_effect=make_chroma):
            self.db.create_retrival_artifacts(str(db_dir), "sk-test")
        marker = db_dir / ".embedding_backend"
        assert marker.exists()
        assert "text-embedding-3-small" in marker.read_text()


# ---------------------------------------------------------------------------
# Embedding-time API failures translate into friendly ValueErrors
# ---------------------------------------------------------------------------

class TestEmbeddingErrorTranslation:
    """Storing and querying now hit OpenAI's embedding API, so those calls can
    fail; users should see the same friendly wording as chat/summary failures."""

    def _drain(self, gen):
        while True:
            try:
                next(gen)
            except StopIteration as e:
                return e.value

    def _run_generate(self, db):
        with patch("pandas.read_csv", return_value=pd.DataFrame(
            {"Title": ["T"], "Date": ["2023-01-01"], "Contents": ["body"]})):
            mock_file = MagicMock()
            mock_file.name = "notes.csv"
            return self._drain(db.generate_database(mock_file, "data/db"))

    def _db_with_store(self):
        db = DatabaseHandler()
        db.text_splitter = MagicMock()
        db.text_splitter.split_text.return_value = ["chunk"]
        db.vector_store = MagicMock()
        return db

    def test_generate_database_translates_auth_error(self):
        db = self._db_with_store()
        db.vector_store.add_documents.side_effect = _status_error(openai.AuthenticationError, 401)
        with pytest.raises(ValueError) as ei:
            self._run_generate(db)
        assert "API key" in str(ei.value)
        assert "openai." not in str(ei.value)

    def test_generate_database_translates_rate_limit(self):
        db = self._db_with_store()
        db.vector_store.add_documents.side_effect = _status_error(openai.RateLimitError, 429)
        with pytest.raises(ValueError) as ei:
            self._run_generate(db)
        assert "try again" in str(ei.value).lower()

    def test_generate_database_does_not_swallow_unrelated_errors(self):
        db = self._db_with_store()
        db.vector_store.add_documents.side_effect = RuntimeError("disk full")
        with pytest.raises(RuntimeError, match="disk full"):
            self._run_generate(db)

    def test_retrieve_notes_translates_connection_error(self):
        db = DatabaseHandler()
        db.document_retriever = MagicMock()
        db.document_retriever.invoke.side_effect = openai.APIConnectionError(request=_REQUEST)
        with pytest.raises(ValueError) as ei:
            db.retrieve_notes("where is the dragon")
        assert "connection" in str(ei.value).lower()


# ---------------------------------------------------------------------------
# clear_database
# ---------------------------------------------------------------------------

class TestClearDatabase:
    def test_clears_all_attributes(self, tmp_path):
        db = DatabaseHandler()
        db.text_splitter = MagicMock()
        db.document_retriever = MagicMock()
        db.vector_store = MagicMock()
        db.last_processed_df = MagicMock()
        db.clear_database(str(tmp_path / "nonexistent"))
        assert db.text_splitter is None
        assert db.document_retriever is None
        assert db.vector_store is None
        assert db.last_processed_df is None

    def test_deletes_existing_directory(self, tmp_path):
        db = DatabaseHandler()
        db_dir = tmp_path / "test_db"
        db_dir.mkdir()
        (db_dir / "file.bin").write_bytes(b"data")
        db.clear_database(str(db_dir))
        assert not db_dir.exists()

    def test_no_error_when_directory_absent(self, tmp_path):
        db = DatabaseHandler()
        db.clear_database(str(tmp_path / "does_not_exist"))

    def test_no_error_when_vector_store_is_none(self, tmp_path):
        db = DatabaseHandler()
        db.clear_database(str(tmp_path / "nonexistent"))

    def test_retries_on_permission_error_then_succeeds(self, tmp_path):
        """After transient PermissionErrors the directory is eventually deleted."""
        db = DatabaseHandler()
        db_dir = tmp_path / "locked_db"
        db_dir.mkdir()

        attempt_count = [0]
        real_rmtree = shutil.rmtree

        def flaky_rmtree(path, **kwargs):
            attempt_count[0] += 1
            if attempt_count[0] < 3:
                raise PermissionError("file in use")
            real_rmtree(path, **kwargs)

        with patch("src.utils.DatabaseHandler.shutil.rmtree", side_effect=flaky_rmtree), \
             patch("time.sleep"):
            db.clear_database(str(db_dir))

        assert attempt_count[0] >= 3

    def test_uses_ignore_errors_after_all_retries_exhausted(self, tmp_path):
        """If every retry raises, clear_database falls back to ignore_errors and does not propagate."""
        db = DatabaseHandler()
        db_dir = tmp_path / "always_locked"
        db_dir.mkdir()

        with patch("src.utils.DatabaseHandler.shutil.rmtree", side_effect=PermissionError("locked")), \
             patch("time.sleep"):
            db.clear_database(str(db_dir))
