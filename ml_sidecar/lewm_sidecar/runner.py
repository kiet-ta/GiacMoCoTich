from __future__ import annotations

import base64
import hashlib
import io
import os
import sys
import time
from pathlib import Path
from typing import Any

import numpy as np
import torch
from PIL import Image

from .adapter import build_reaction, context_prior, safe_candidates


ROOT = Path(__file__).resolve().parents[2]
RESEARCH_ROOT = ROOT / "research" / "lewm"
if RESEARCH_ROOT.exists():
    sys.path.insert(0, str(RESEARCH_ROOT))

from lewm.models import LeWMModel  # noqa: E402


class LeWMSidecarRunner:
    def __init__(self) -> None:
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.image_size = int(os.getenv("LEWM_IMAGE_SIZE", "128"))
        self.action_dim = int(os.getenv("LEWM_ACTION_DIM", "6"))
        self.latent_dim = int(os.getenv("LEWM_LATENT_DIM", "256"))
        self.model = LeWMModel(action_dim=self.action_dim, latent_dim=self.latent_dim).to(self.device)
        self.model.eval()
        self.model_loaded = False
        self.allow_untrained = os.getenv("LEWM_ALLOW_UNTRAINED", "0") == "1"
        self.model_version = "lewm-local-untrained"
        checkpoint = os.getenv("LEWM_CHECKPOINT", "")
        if checkpoint:
            self._load_checkpoint(Path(checkpoint))

    def _load_checkpoint(self, checkpoint: Path) -> None:
        state = torch.load(checkpoint, map_location=self.device)
        model_state = state.get("model", state)
        self.model.load_state_dict(model_state, strict=False)
        self.model_loaded = True
        self.model_version = f"lewm-local:{checkpoint.name}"

    @torch.no_grad()
    def predict(self, payload: Any) -> dict[str, Any]:
        if not self.model_loaded and not self.allow_untrained:
            raise RuntimeError("No LeWM checkpoint loaded. Set LEWM_CHECKPOINT or LEWM_ALLOW_UNTRAINED=1.")
        started = time.perf_counter()
        candidates = safe_candidates(payload.chapter_id, payload.candidate_reactions)
        if not candidates:
            raise ValueError(f"No safe candidate reactions for {payload.chapter_id}")

        image = self._decode_frame(payload.frame_png_base64)
        action = self._action_tensor(payload.action_vector)
        output = self.model(image, action)
        latent = output["predicted_next"][0].detach().float().cpu().numpy()

        scores = [
            self._candidate_score(latent, payload.chapter_id, candidate, payload.scalar_context)
            for candidate in candidates
        ]
        best_index = int(np.argmax(scores))
        confidence = self._confidence(scores)
        latency_ms = (time.perf_counter() - started) * 1000.0
        return build_reaction(
            payload.chapter_id,
            candidates[best_index],
            confidence,
            self.model_version,
            latency_ms,
        )

    def _decode_frame(self, value: str) -> torch.Tensor:
        raw = base64.b64decode(value)
        image = Image.open(io.BytesIO(raw)).convert("RGB")
        if image.size != (self.image_size, self.image_size):
            image = image.resize((self.image_size, self.image_size), Image.Resampling.BILINEAR)
        array = np.asarray(image, dtype=np.float32) / 255.0
        array = np.transpose(array, (2, 0, 1))[None, ...]
        return torch.from_numpy(array).to(self.device)

    def _action_tensor(self, values: list[float]) -> torch.Tensor:
        action = np.zeros((self.action_dim,), dtype=np.float32)
        for index, value in enumerate(values[: self.action_dim]):
            action[index] = float(value)
        return torch.from_numpy(action[None, ...]).to(self.device)

    def _candidate_score(
        self,
        latent: np.ndarray,
        chapter_id: str,
        candidate: dict[str, Any],
        context: dict[str, Any],
    ) -> float:
        intent = str(candidate.get("intent", ""))
        digest = hashlib.sha256(intent.encode("utf-8")).digest()
        latent_score = 0.0
        for offset, byte in enumerate(digest[:12]):
            index = byte % latent.shape[0]
            sign = 1.0 if digest[offset + 12] % 2 == 0 else -1.0
            latent_score += float(latent[index]) * sign
        latent_score = float(np.tanh(latent_score / 6.0))
        prior = context_prior(chapter_id, intent, context)
        return latent_score * 0.65 + prior * 0.35

    def _confidence(self, scores: list[float]) -> float:
        if len(scores) == 1:
            return 0.55
        ordered = sorted(scores, reverse=True)
        margin = ordered[0] - ordered[1]
        return float(1.0 / (1.0 + np.exp(-margin * 4.0)))
