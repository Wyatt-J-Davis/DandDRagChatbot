import gc
import os
import time
import pandas as pd
from langchain_chroma import Chroma
import re
import io
import shutil
from langchain_openai import OpenAIEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.docstore.document import Document as langchaindoc
from docx import Document as DocxReader
from . import LLMHandler

DATABASE_DIR = "data/chrome_langchain_db"
EMBEDDING_MODEL = "text-embedding-3-small"
_CHUNK_SIZE = 1000
_CHUNK_OVERLAP = 200

# Written into the persisted DB dir so a store embedded with a different backend
# (e.g. the old local 768-dim model) is detected and wiped rather than opened
# with mismatched query vectors.
_EMBEDDING_MARKER = ".embedding_backend"
# The distance metric is part of the identity: an L2-built store scores queries
# differently, so switching to cosine must force a rebuild too.
_DISTANCE_METRIC = "cosine"
_EMBEDDING_BACKEND_ID = f"openai:{EMBEDDING_MODEL}:{_DISTANCE_METRIC}"


class DatabaseHandler:
    def __init__(self):
        self.text_splitter = None
        self.document_retriever = None
        self.vector_store = None
        self.last_processed_df = None
        # Set when create_retrival_artifacts discards a dimension-incompatible
        # store on disk, so the page can prompt a one-time re-upload.
        self.legacy_db_reset = False
    
    # function yeilds progress percent until final returncode
    def generate_database(self, document, databasedir):
        df = self.__convert_document_into_dataframe(document, databasedir)
        retCode = True

        if df is not None and not df.empty:
            self.last_processed_df = df
            documents = []
            idlist = []
            l = 0 
            
            for i, row in df.iterrows():
                text = str(row["Contents"])
                # Existing semantic chunking via text_splitter
                chunks = self.text_splitter.split_text(text)
                for chunk in chunks:
                    document = langchaindoc(
                        page_content=chunk,
                        metadata={
                            "Title": row.get("Title", "Untitled"), 
                            "Date": str(row.get("Date", "Unknown")), 
                            "Exerpt Start": chunk[:25], 
                            "Exerpt End": chunk[-25:]
                        },
                        id=str(l)
                    )
                    idlist.append(str(l))
                    documents.append(document)
                    l += 1
                
                # Progress bar logic
                percent_complete = (i + 1) / len(df) * 100
                yield percent_complete # provide percent complete for progress bar usage
                    
            if self.vector_store is not None:
                try:
                    self.vector_store.add_documents(documents=documents, ids=idlist)
                except Exception as e:
                    message = LLMHandler.translate_openai_error(e)
                    if message:
                        raise ValueError(message) from e
                    raise
            else:
                retCode = False
        else:
            retCode = False

        return retCode
    
    def retrieve_notes(self, query):
        if self.document_retriever is not None:
            try:
                relevant_docs = self.document_retriever.invoke(query)
            except Exception as e:
                message = LLMHandler.translate_openai_error(e)
                if message:
                    raise ValueError(message) from e
                raise
            return relevant_docs
        else:
            raise ValueError("Document retriever not initialized. Generate the retriver first with 'create_retrival_artifacts' method.")
    
    def clear_database(self, databasedir):
        self.document_retriever = None
        self.vector_store = None
        self.text_splitter = None
        self.last_processed_df = None
        gc.collect()

        if not os.path.isdir(databasedir):
            return

        for attempt in range(5):
            try:
                shutil.rmtree(databasedir)
                return
            except FileNotFoundError:
                return
            except PermissionError:
                if attempt < 4:
                    time.sleep(0.3)
                    gc.collect()

    def create_retrival_artifacts(self, databasedir, api_key):
        # Per-call signal: the handler persists across Streamlit reruns, so this
        # must be cleared even when the build below no-ops behind the guard,
        # otherwise a one-time legacy wipe would re-fire on every rerun.
        self.legacy_db_reset = False
        if self.vector_store is not None:
            return
        self.__reset_incompatible_database(databasedir)
        embeddings = self.__load_embeddings(api_key)
        self.text_splitter = RecursiveCharacterTextSplitter(chunk_size=_CHUNK_SIZE, chunk_overlap=_CHUNK_OVERLAP)
        try:
            self.vector_store = Chroma(
                    collection_name="notes",
                    persist_directory=databasedir,
                    embedding_function=embeddings,
                    collection_configuration={"hnsw": {"space": _DISTANCE_METRIC}}
                    )
        except Exception:
            gc.collect()
            for attempt in range(5):
                try:
                    if os.path.isdir(databasedir):
                        shutil.rmtree(databasedir)
                    break
                except (FileNotFoundError, PermissionError):
                    if attempt < 4:
                        time.sleep(0.3)
                        gc.collect()
            self.vector_store = Chroma(
                    collection_name="notes",
                    persist_directory=databasedir,
                    embedding_function=embeddings,
                    collection_configuration={"hnsw": {"space": _DISTANCE_METRIC}}
                    )
        self.document_retriever = self.vector_store.as_retriever(
            search_type="similarity_score_threshold",
            search_kwargs={"k": 10, "score_threshold": .25}
            )
        self.__write_backend_marker(databasedir)

    def __reset_incompatible_database(self, databasedir):
        """Wipe a persisted store whose embedding backend does not match the
        current one; its vectors have the wrong dimension and can't be queried."""
        if not os.path.isdir(databasedir):
            return
        marker = os.path.join(databasedir, _EMBEDDING_MARKER)
        if os.path.isfile(marker):
            try:
                with open(marker) as f:
                    if f.read().strip() == _EMBEDDING_BACKEND_ID:
                        return
            except OSError:
                pass
        for attempt in range(5):
            try:
                shutil.rmtree(databasedir)
                break
            except FileNotFoundError:
                break
            except PermissionError:
                if attempt < 4:
                    time.sleep(0.3)
                    gc.collect()
        self.legacy_db_reset = True

    def __write_backend_marker(self, databasedir):
        if not os.path.isdir(databasedir):
            return
        try:
            with open(os.path.join(databasedir, _EMBEDDING_MARKER), "w") as f:
                f.write(_EMBEDDING_BACKEND_ID)
        except OSError:
            pass

    def __convert_document_into_dataframe(self, document, databasedir):
        file_extension = document.name.split('.')[-1].lower()
        
        if file_extension == 'csv':
            df = pd.read_csv(document)
        elif file_extension == 'docx':
            # Read the file into a buffer
            bytes_data = document.read()
            doc_io = io.BytesIO(bytes_data)
            document = DocxReader(doc_io)

            # Create list of paragraphs
            document_text = []
            for paragraph in document.paragraphs:
                document_text.append(paragraph.text)
                
            # Join paragraphs together with newline character
            text_content = '\n'.join(document_text)

            # Parse text content into same dataframe structure
            df = self.__parse_journal_text(text_content)
        # simple text document
        else:
            # Read the text file content and parse it into the same dataframe structure
            stringio = io.StringIO(document.getvalue().decode("utf-8"))
            df = self.__parse_journal_text(stringio.read())
        
        return df


    def __load_embeddings(self, api_key):
        return OpenAIEmbeddings(model=EMBEDDING_MODEL, api_key=api_key)

    def __parse_journal_text(self,file_content):
        """Parses a text file with date headers into a structured list of dicts."""
        # Matches common date formats like 2023-10-27 or 10/27/2023 at the start of a line
        date_pattern = r'^(\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}/\d{2,4})'
        
        entries = []
        current_date = "Unknown Date"
        current_content = []

        for line in file_content.splitlines():
            match = re.match(date_pattern, line.strip())
            if match:
                # If we already have a previous entry, save it before starting a new one
                if current_content:
                    entries.append({
                        "Title": f"Entry for {current_date}",
                        "Date": current_date,
                        "Contents": "\n".join(current_content).strip()
                    })
                current_date = match.group(1)
                current_content = [line[match.end():].strip()] # Start content after the date
            else:
                current_content.append(line.strip())

        # Catch the final entry
        if current_content:
            entries.append({
                "Title": f"Entry for {current_date}",
                "Date": current_date,
                "Contents": "\n".join(current_content).strip()
            })
        return pd.DataFrame(entries)