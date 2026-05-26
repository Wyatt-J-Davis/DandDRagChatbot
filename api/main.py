import io
import json
import os
import uvicorn
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, StreamingResponse
from langchain_core.prompts import ChatPromptTemplate
from pydantic import BaseModel

from src.utils.DatabaseHandler import DatabaseHandler, DATABASE_DIR
from src.utils.LLMHandler import LLMHandler
from src.utils.SummaryHandler import SummaryHandler

_USER_DATA_FILE = "data/user_data.json"
_NOTES_FILE = "data/editor_notes.txt"

_CHAT_PROMPT = ChatPromptTemplate.from_messages([
    (
        "system",
        "You are an expert in answering questions about a TTRPG campaign described in provided documents. "
        "The provided documents describe a campaign where the party members (player characters) are {partymembers}. "
        "Here are the relevant documents from {notetaker}'s perspective (could be in first person or third person): {notes}"
        "\n Base your answers only off of the provided documents. "
        "Do not use extraneous information to answer the question. "
        "Do not provide references to the documents.",
    ),
    ("user", "{question}"),
])


def get_llm_handler() -> LLMHandler:
    return LLMHandler()


def get_db_handler() -> DatabaseHandler:
    return DatabaseHandler()


def get_summary_handler() -> SummaryHandler:
    return SummaryHandler(get_llm_handler())


def _sse_event(payload: dict) -> str:
    return f"data: {json.dumps(payload)}\n\n"


class UploadNotesRequest(BaseModel):
    file_path: str


class ChatRequest(BaseModel):
    question: str
    model: str
    temperature: float


class SummaryGenerateRequest(BaseModel):
    model: str
    party_members: list[str] = []


class NotesRequest(BaseModel):
    content: str


class PartyRequest(BaseModel):
    party_members: list[dict] = []


def create_app() -> FastAPI:
    application = FastAPI()

    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @application.get("/health")
    def health():
        return {"status": "ok"}

    @application.get("/models")
    def models(handler: LLMHandler = Depends(get_llm_handler)):
        return [m.model for m in handler.get_available_models()]

    @application.post("/upload-notes")
    def upload_notes(
        body: UploadNotesRequest,
        db: DatabaseHandler = Depends(get_db_handler),
    ):
        def event_stream():
            try:
                db.create_retrival_artifacts(DATABASE_DIR)

                class _FileWrapper:
                    def __init__(self, path: str):
                        self.name = os.path.basename(path)
                        self._path = path

                    def read(self):
                        with open(self._path, "rb") as f:
                            return f.read()

                    def getvalue(self):
                        return self.read()

                doc = _FileWrapper(body.file_path)
                for pct in db.generate_database(doc, DATABASE_DIR):
                    yield _sse_event({
                        "done": False,
                        "progress": int(pct),
                        "message": f"Processing… {int(pct)}%",
                    })
                yield _sse_event({"done": True, "progress": 100})
            except Exception as exc:
                yield _sse_event({"done": True, "error": True, "message": str(exc)})

        return StreamingResponse(event_stream(), media_type="text/event-stream")

    @application.post("/chat")
    def chat(
        body: ChatRequest,
        llm: LLMHandler = Depends(get_llm_handler),
        db: DatabaseHandler = Depends(get_db_handler),
    ):
        def event_stream():
            try:
                yield _sse_event({"done": False, "progress": 10, "message": "Retrieving relevant notes…"})

                db.create_retrival_artifacts(DATABASE_DIR)
                notes = db.retrieve_notes(body.question)

                yield _sse_event({"done": False, "progress": 50, "message": "Generating response…"})

                party_members: list[dict] = []
                note_taker = "Unknown"
                try:
                    if os.path.isfile(_USER_DATA_FILE):
                        with open(_USER_DATA_FILE, "r") as f:
                            user_data = json.load(f)
                        party_members = user_data.get("party_members", [])
                        takers = [m.get("name", "") for m in party_members if m.get("note_taker")]
                        if takers:
                            note_taker = takers[0]
                except Exception:
                    pass

                member_names = [m.get("name", "") for m in party_members if m.get("name")]
                if len(member_names) > 1:
                    formatted_members = ", ".join(member_names[:-1]) + ", and " + member_names[-1]
                elif member_names:
                    formatted_members = member_names[0]
                else:
                    formatted_members = "the party"

                if notes:
                    llm.load_model(body.model, body.temperature)
                    answer = llm.invoke_model(
                        _CHAT_PROMPT,
                        {
                            "question": body.question,
                            "partymembers": formatted_members,
                            "notes": notes,
                            "notetaker": note_taker,
                        },
                    )
                else:
                    answer = (
                        "Could not find any relevant journal entries for your query. "
                        "It could be that there is not any relevant information regarding your query in the notes, "
                        "the question needs to be reworded, or spelling needs to be reviewed."
                    )

                sources = [doc.page_content for doc in notes]
                yield _sse_event({"done": True, "answer": answer, "sources": sources})
            except Exception as exc:
                yield _sse_event({"done": True, "error": True, "message": str(exc)})

        return StreamingResponse(event_stream(), media_type="text/event-stream")

    @application.get("/summary")
    def summary_get(summary: SummaryHandler = Depends(get_summary_handler)):
        data = summary.get_saved_summary()
        return data if data is not None else {}

    @application.get("/notes")
    def notes_get():
        if os.path.isfile(_NOTES_FILE):
            with open(_NOTES_FILE, "r", encoding="utf-8") as f:
                return {"content": f.read()}
        return {"content": ""}

    @application.post("/notes")
    def notes_post(body: NotesRequest):
        os.makedirs(os.path.dirname(_NOTES_FILE), exist_ok=True)
        with open(_NOTES_FILE, "w", encoding="utf-8") as f:
            f.write(body.content)
        return {"status": "ok"}

    @application.post("/notes/vectorize")
    def notes_vectorize(
        body: NotesRequest,
        db: DatabaseHandler = Depends(get_db_handler),
    ):
        def event_stream():
            try:
                db.create_retrival_artifacts(DATABASE_DIR)

                class _TextWrapper:
                    name = "notes.txt"

                    def __init__(self, content: str):
                        self._bytes = content.encode("utf-8")

                    def read(self):
                        return self._bytes

                    def getvalue(self):
                        return self._bytes

                wrapper = _TextWrapper(body.content)
                for pct in db.generate_database(wrapper, DATABASE_DIR):
                    yield _sse_event({
                        "done": False,
                        "progress": int(pct),
                        "message": f"Vectorizing… {int(pct)}%",
                    })
                yield _sse_event({"done": True, "progress": 100})
            except Exception as exc:
                yield _sse_event({"done": True, "error": True, "message": str(exc)})

        return StreamingResponse(event_stream(), media_type="text/event-stream")

    @application.post("/summary/generate")
    def summary_generate(
        body: SummaryGenerateRequest,
        summary: SummaryHandler = Depends(get_summary_handler),
    ):
        def event_stream():
            try:
                for is_done, progress, text in summary.generate_summary_streaming(
                    body.model, body.party_members
                ):
                    if is_done:
                        yield _sse_event({"done": True, "progress": 100})
                    else:
                        yield _sse_event({"done": False, "progress": progress, "message": text})
            except Exception as exc:
                yield _sse_event({"done": True, "error": True, "message": str(exc)})

        return StreamingResponse(event_stream(), media_type="text/event-stream")

    @application.get("/party")
    def party_get():
        if os.path.isfile(_USER_DATA_FILE):
            with open(_USER_DATA_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            return {"party_members": data.get("party_members", [])}
        return {"party_members": []}

    @application.post("/party")
    def party_post(body: PartyRequest):
        data = {}
        if os.path.isfile(_USER_DATA_FILE):
            with open(_USER_DATA_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
        data["party_members"] = body.party_members
        os.makedirs(os.path.dirname(_USER_DATA_FILE), exist_ok=True)
        with open(_USER_DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f)
        return {"status": "ok"}

    @application.get("/notes/export/txt")
    def notes_export_txt():
        if not os.path.isfile(_NOTES_FILE):
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="No notes file found.")
        with open(_NOTES_FILE, "rb") as f:
            content = f.read()
        return Response(
            content=content,
            media_type="text/plain",
            headers={"Content-Disposition": "attachment; filename=\"editor_notes.txt\""},
        )

    @application.get("/notes/export/docx")
    def notes_export_docx():
        if not os.path.isfile(_NOTES_FILE):
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="No notes file found.")
        from docx import Document
        with open(_NOTES_FILE, "r", encoding="utf-8") as f:
            text = f.read()
        doc = Document()
        for line in text.splitlines():
            doc.add_paragraph(line)
        buf = io.BytesIO()
        doc.save(buf)
        buf.seek(0)
        return Response(
            content=buf.read(),
            media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            headers={"Content-Disposition": "attachment; filename=\"editor_notes.docx\""},
        )

    return application


app = create_app()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("api.main:app", host="127.0.0.1", port=port, reload=False)
