from __future__ import annotations

import torch


def effective_rank(latents: torch.Tensor, eps: float = 1e-8) -> float:
    """Return entropy-based effective rank for a latent batch."""
    if latents.ndim != 2 or latents.size(0) < 2:
        return 0.0
    centered = latents - latents.mean(dim=0, keepdim=True)
    singular_values = torch.linalg.svdvals(centered)
    weights = singular_values / (singular_values.sum() + eps)
    entropy = -(weights * torch.log(weights + eps)).sum()
    return float(torch.exp(entropy).item())


def latent_diagnostics(latents: torch.Tensor) -> dict[str, float]:
    """Compact collapse diagnostics for LeWM latent batches."""
    if latents.ndim != 2:
        latents = latents.flatten(1)
    variance = latents.var(dim=0)
    return {
        "latent_mean_abs": float(latents.mean(dim=0).abs().mean().item()),
        "latent_variance_mean": float(variance.mean().item()),
        "latent_variance_min": float(variance.min().item()),
        "latent_variance_max": float(variance.max().item()),
        "latent_effective_rank": effective_rank(latents),
    }
