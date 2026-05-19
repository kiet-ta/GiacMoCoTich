from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

import torch

from .models import LeWMModel


@dataclass
class PlannerConfig:
    horizon: int = 5
    candidates: int = 256
    action_dim: int = 6


class RandomShootingPlanner:
    """Latent-space random shooting scaffold.

    The scoring function is injected because the first research milestone must
    decide whether score comes from probes, hand-authored utility, or benchmark
    objectives.
    """

    def __init__(self, model: LeWMModel, config: PlannerConfig) -> None:
        self.model = model
        self.config = config

    @torch.no_grad()
    def plan(self, image: torch.Tensor, score_fn: Callable[[torch.Tensor], torch.Tensor]) -> torch.Tensor:
        device = image.device
        if image.ndim == 3:
            image = image.unsqueeze(0)
        latent = self.model.encode(image)
        action_sequences = torch.rand(
            self.config.candidates,
            self.config.horizon,
            self.config.action_dim,
            device=device,
        ) * 2.0 - 1.0

        repeated_latent = latent.repeat(self.config.candidates, 1)
        rollout_latent = repeated_latent
        for step in range(self.config.horizon):
            action_embedding = self.model.action_encoder(action_sequences[:, step, :])
            rollout_latent = self.model.predictor(rollout_latent, action_embedding)

        scores = score_fn(rollout_latent)
        best = int(torch.argmax(scores).item())
        return action_sequences[best, 0, :]
