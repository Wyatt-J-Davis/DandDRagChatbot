import io
import json
import os
import uvicorn
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from src.utils.DatabaseHandler import DatabaseHandler, DATABASE_DIR
from src.utils.LLMHandler import LLMHandler


def get_llm_handler() -> LLMHandler:
    return LLMHandler()


def get_db_handler() -> DatabaseHandler:
    return DatabaseHandler()


def _sse_event(payload: dict) -> str:
    return f"data: {json.dumps(payload)}\n\n"


class UploadNotesRequest(BaseModel):
    file_path: str


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

    return application


app = create_app()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("api.main:app", host="127.0.0.1", port=port, reload=False)
