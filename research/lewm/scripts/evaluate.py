from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import torch
import yaml
from torch.utils.data import DataLoader

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lewm.datasets import ChapterTransitionDataset  # noqa: E402
from lewm.losses import gaussian_regularizer, prediction_loss  # noqa: E402
from lewm.models import LeWMModel  # noqa: E402


def load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        return yaml.safe_load(file)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--checkpoint", required=True, type=Path)
    args = parser.parse_args()

    config = load_config(args.config)
    dataset_cfg = config["dataset"]
    model_cfg = config["model"]
    train_cfg = config["training"]
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    dataset = ChapterTransitionDataset(
        dataset_cfg["root"],
        image_size=int(dataset_cfg.get("image_size", 128)),
        max_transitions=int(dataset_cfg.get("max_transitions", 0)),
    )
    loader = DataLoader(dataset, batch_size=int(train_cfg.get("batch_size", 64)), shuffle=False)
    model = LeWMModel(
        action_dim=int(model_cfg.get("action_dim", 6)),
        latent_dim=int(model_cfg.get("latent_dim", 256)),
        hidden_dim=int(model_cfg.get("hidden_dim", 512)),
    ).to(device)
    checkpoint = torch.load(args.checkpoint, map_location=device)
    model.load_state_dict(checkpoint["model"])
    model.eval()

    total_pred = 0.0
    total_reg = 0.0
    count = 0
    latent_batches = []
    with torch.no_grad():
        for batch in loader:
            frame = batch["frame"].to(device)
            action = batch["action"].to(device)
            next_frame = batch["next_frame"].to(device)
            output = model(frame, action, next_frame)
            pred = prediction_loss(output["predicted_next"], output["target_next"])
            reg = gaussian_regularizer(torch.cat([output["latent"], output["target_next"]], dim=0))
            total_pred += float(pred.item()) * frame.size(0)
            total_reg += float(reg.item()) * frame.size(0)
            count += frame.size(0)
            latent_batches.append(output["latent"].detach().cpu())

    latents = torch.cat(latent_batches, dim=0)
    report = {
        "samples": count,
        "prediction_loss": total_pred / max(count, 1),
        "gaussian_regularizer": total_reg / max(count, 1),
        "latent_mean_abs": float(latents.mean(dim=0).abs().mean().item()),
        "latent_variance_mean": float(latents.var(dim=0).mean().item()),
        "latent_variance_min": float(latents.var(dim=0).min().item()),
        "latent_variance_max": float(latents.var(dim=0).max().item()),
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
