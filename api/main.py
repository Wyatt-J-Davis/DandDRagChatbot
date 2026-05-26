import os
import uvicorn
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.utils.LLMHandler import LLMHandler


def get_llm_handler() -> LLMHandler:
    return LLMHandler()


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

    return application


app = create_app()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("api.main:app", host="127.0.0.1", port=port, reload=False)
