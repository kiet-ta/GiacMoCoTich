from __future__ import annotations

import uuid

from fastapi import FastAPI, HTTPException

from .runner import LeWMSidecarRunner
from .schemas import (
    HealthResponse,
    PredictReactionRequest,
    PredictReactionResponse,
    ReactionContract,
    SessionEndRequest,
    SessionStartRequest,
    SessionStartResponse,
)


app = FastAPI(title="GiacMoCoTich LeWorldModel Sidecar", version="0.1.0")
runner = LeWMSidecarRunner()
sessions: dict[str, str] = {}


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        model_loaded=runner.model_loaded,
        model_version=runner.model_version,
        device=str(runner.device),
    )


@app.post("/v1/session/start", response_model=SessionStartResponse)
def start_session(payload: SessionStartRequest) -> SessionStartResponse:
    session_id = f"{payload.chapter_id}-{uuid.uuid4().hex[:12]}"
    sessions[session_id] = payload.chapter_id
    return SessionStartResponse(session_id=session_id, model_version=runner.model_version)


@app.post("/v1/predict_reaction", response_model=PredictReactionResponse)
def predict_reaction(payload: PredictReactionRequest) -> PredictReactionResponse:
    if payload.session_id and payload.session_id not in sessions:
        raise HTTPException(status_code=404, detail="Unknown LeWM session_id")
    try:
        reaction = runner.predict(payload)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return PredictReactionResponse(reaction=ReactionContract(**reaction))


@app.post("/v1/session/end")
def end_session(payload: SessionEndRequest) -> dict[str, bool]:
    sessions.pop(payload.session_id, None)
    return {"ok": True}
