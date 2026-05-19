from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class SessionStartRequest(BaseModel):
    chapter_id: str


class SessionStartResponse(BaseModel):
    ok: bool = True
    session_id: str
    model_version: str


class SessionEndRequest(BaseModel):
    session_id: str


class UIContract(BaseModel):
    whisper: str = ""
    meter_label: str = ""
    warning: str = ""


class ReactionContract(BaseModel):
    intent: str
    severity: float = Field(ge=0.0, le=100.0)
    effects: list[str] = Field(default_factory=list)
    ui: UIContract = Field(default_factory=UIContract)
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    model_version: str = "unknown"
    latency_ms: float = 0.0
    source: str = "ml"

    class Config:
        extra = "allow"


class PredictReactionRequest(BaseModel):
    session_id: str = ""
    chapter_id: str
    frame_png_base64: str
    action_vector: list[float] = Field(default_factory=list)
    scalar_context: dict[str, Any] = Field(default_factory=dict)
    candidate_reactions: list[dict[str, Any]] = Field(default_factory=list)


class PredictReactionResponse(BaseModel):
    ok: bool = True
    reaction: ReactionContract


class HealthResponse(BaseModel):
    ok: bool = True
    model_loaded: bool
    model_version: str
    device: str
