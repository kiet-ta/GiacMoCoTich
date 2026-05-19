from __future__ import annotations

import torch
from torch import nn


class ConvEncoder(nn.Module):
    def __init__(self, latent_dim: int = 256) -> None:
        super().__init__()
        self.backbone = nn.Sequential(
            nn.Conv2d(3, 32, kernel_size=5, stride=2, padding=2),
            nn.SiLU(),
            nn.Conv2d(32, 64, kernel_size=3, stride=2, padding=1),
            nn.SiLU(),
            nn.Conv2d(64, 128, kernel_size=3, stride=2, padding=1),
            nn.SiLU(),
            nn.Conv2d(128, 256, kernel_size=3, stride=2, padding=1),
            nn.SiLU(),
            nn.AdaptiveAvgPool2d((1, 1)),
        )
        self.projection = nn.Linear(256, latent_dim)

    def forward(self, images: torch.Tensor) -> torch.Tensor:
        features = self.backbone(images).flatten(1)
        return self.projection(features)


class ActionEncoder(nn.Module):
    def __init__(self, action_dim: int = 8, hidden_dim: int = 128) -> None:
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(action_dim, hidden_dim),
            nn.SiLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.SiLU(),
        )

    def forward(self, actions: torch.Tensor) -> torch.Tensor:
        return self.net(actions)


class LatentPredictor(nn.Module):
    def __init__(self, latent_dim: int = 256, action_hidden_dim: int = 128, hidden_dim: int = 512) -> None:
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(latent_dim + action_hidden_dim, hidden_dim),
            nn.SiLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.SiLU(),
            nn.Linear(hidden_dim, latent_dim),
        )

    def forward(self, latent: torch.Tensor, action_embedding: torch.Tensor) -> torch.Tensor:
        return self.net(torch.cat([latent, action_embedding], dim=-1))


class LeWMModel(nn.Module):
    def __init__(self, action_dim: int = 8, latent_dim: int = 256, hidden_dim: int = 512) -> None:
        super().__init__()
        self.encoder = ConvEncoder(latent_dim=latent_dim)
        self.action_encoder = ActionEncoder(action_dim=action_dim)
        self.predictor = LatentPredictor(latent_dim=latent_dim, hidden_dim=hidden_dim)

    def encode(self, images: torch.Tensor) -> torch.Tensor:
        return self.encoder(images)

    def predict_next_latent(self, images: torch.Tensor, actions: torch.Tensor) -> torch.Tensor:
        latent = self.encoder(images)
        action_embedding = self.action_encoder(actions)
        return self.predictor(latent, action_embedding)

    def forward(self, images: torch.Tensor, actions: torch.Tensor, next_images: torch.Tensor | None = None) -> dict[str, torch.Tensor]:
        latent = self.encoder(images)
        action_embedding = self.action_encoder(actions)
        predicted_next = self.predictor(latent, action_embedding)
        output = {
            "latent": latent,
            "predicted_next": predicted_next,
        }
        if next_images is not None:
            output["target_next"] = self.encoder(next_images)
        return output
