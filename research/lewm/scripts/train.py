from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import torch
import yaml
from torch.utils.data import DataLoader, random_split

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lewm.datasets import Chapter2TransitionDataset  # noqa: E402
from lewm.losses import gaussian_regularizer, prediction_loss  # noqa: E402
from lewm.models import LeWMModel  # noqa: E402


def resolve_device(name: str) -> torch.device:
    if name == "auto":
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")
    return torch.device(name)


def load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        return yaml.safe_load(file)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    args = parser.parse_args()

    config = load_config(args.config)
    train_cfg = config["training"]
    dataset_cfg = config["dataset"]
    model_cfg = config["model"]

    torch.manual_seed(int(train_cfg.get("seed", 42)))
    device = resolve_device(str(train_cfg.get("device", "auto")))

    dataset = Chapter2TransitionDataset(
        dataset_cfg["root"],
        image_size=int(dataset_cfg.get("image_size", 128)),
        max_transitions=int(dataset_cfg.get("max_transitions", 0)),
    )
    val_fraction = float(dataset_cfg.get("validation_fraction", 0.15))
    val_size = max(1, int(len(dataset) * val_fraction))
    train_size = len(dataset) - val_size
    train_dataset, val_dataset = random_split(
        dataset,
        [train_size, val_size],
        generator=torch.Generator().manual_seed(int(train_cfg.get("seed", 42))),
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=int(train_cfg.get("batch_size", 64)),
        shuffle=True,
        num_workers=int(train_cfg.get("num_workers", 2)),
    )
    val_loader = DataLoader(
        val_dataset,
        batch_size=int(train_cfg.get("batch_size", 64)),
        shuffle=False,
        num_workers=int(train_cfg.get("num_workers", 2)),
    )

    model = LeWMModel(
        action_dim=int(model_cfg.get("action_dim", 6)),
        latent_dim=int(model_cfg.get("latent_dim", 256)),
        hidden_dim=int(model_cfg.get("hidden_dim", 512)),
    ).to(device)
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=float(train_cfg.get("learning_rate", 3e-4)),
        weight_decay=float(train_cfg.get("weight_decay", 1e-6)),
    )
    gaussian_weight = float(train_cfg.get("gaussian_weight", 0.05))

    checkpoint_dir = Path(train_cfg.get("checkpoint_dir", "models/lewm/chapter2/checkpoints"))
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    metrics_path = Path(train_cfg.get("metrics_path", "models/lewm/chapter2/training_metrics.json"))
    metrics_path.parent.mkdir(parents=True, exist_ok=True)

    best_val = float("inf")
    history: list[dict[str, float]] = []
    for epoch in range(1, int(train_cfg.get("epochs", 20)) + 1):
        model.train()
        train_loss = 0.0
        for batch in train_loader:
            frame = batch["frame"].to(device)
            action = batch["action"].to(device)
            next_frame = batch["next_frame"].to(device)
            output = model(frame, action, next_frame)
            pred_loss = prediction_loss(output["predicted_next"], output["target_next"])
            reg_loss = gaussian_regularizer(torch.cat([output["latent"], output["target_next"]], dim=0))
            loss = pred_loss + gaussian_weight * reg_loss

            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            optimizer.step()
            train_loss += float(loss.item()) * frame.size(0)
        train_loss /= max(len(train_dataset), 1)

        val_loss = evaluate_loss(model, val_loader, device, gaussian_weight)
        row = {"epoch": float(epoch), "train_loss": train_loss, "val_loss": val_loss}
        history.append(row)
        print(json.dumps(row))

        latest = checkpoint_dir / "latest.pt"
        torch.save({"model": model.state_dict(), "config": config, "history": history}, latest)
        if val_loss < best_val:
            best_val = val_loss
            torch.save({"model": model.state_dict(), "config": config, "history": history}, checkpoint_dir / "best.pt")

    metrics_path.write_text(json.dumps({"best_val_loss": best_val, "history": history}, indent=2), encoding="utf-8")


@torch.no_grad()
def evaluate_loss(model: LeWMModel, loader: DataLoader, device: torch.device, gaussian_weight: float) -> float:
    model.eval()
    total = 0.0
    count = 0
    for batch in loader:
        frame = batch["frame"].to(device)
        action = batch["action"].to(device)
        next_frame = batch["next_frame"].to(device)
        output = model(frame, action, next_frame)
        pred_loss = prediction_loss(output["predicted_next"], output["target_next"])
        reg_loss = gaussian_regularizer(torch.cat([output["latent"], output["target_next"]], dim=0))
        loss = pred_loss + gaussian_weight * reg_loss
        total += float(loss.item()) * frame.size(0)
        count += frame.size(0)
    return total / max(count, 1)


if __name__ == "__main__":
    main()
