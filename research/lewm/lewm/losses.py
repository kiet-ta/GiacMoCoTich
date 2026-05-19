from __future__ import annotations

import torch
import torch.nn.functional as F


def prediction_loss(predicted: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
    return F.mse_loss(predicted, target)


def gaussian_regularizer(latents: torch.Tensor, eps: float = 1e-6) -> torch.Tensor:
    """Encourage non-collapsed approximately standard Gaussian latents.

    This is a compact covariance regularizer suitable for the project scaffold.
    It penalizes non-zero means, non-unit variances, and off-diagonal covariance.
    """
    if latents.ndim != 2:
        latents = latents.flatten(1)
    batch, dim = latents.shape
    if batch < 2:
        return latents.new_tensor(0.0)

    centered = latents - latents.mean(dim=0, keepdim=True)
    cov = centered.T @ centered / float(batch - 1)
    diag = torch.diagonal(cov)
    off_diag = cov - torch.diag(diag)

    mean_penalty = latents.mean(dim=0).pow(2).mean()
    var_penalty = (diag - 1.0).pow(2).mean()
    cov_penalty = off_diag.pow(2).sum() / float(dim * max(dim - 1, 1) + eps)
    return mean_penalty + var_penalty + cov_penalty
