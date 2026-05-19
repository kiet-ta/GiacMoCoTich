from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

import torch
import yaml
from torch.utils.data import DataLoader, Subset

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lewm.datasets import ChapterTransitionDataset  # noqa: E402
from lewm.diagnostics import latent_diagnostics  # noqa: E402
from lewm.losses import gaussian_regularizer, prediction_loss  # noqa: E402
from lewm.models import LeWMModel  # noqa: E402


def resolve_device(name: str) -> torch.device:
    if name == "auto":
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")
    return torch.device(name)


def resolve_amp_enabled(precision: str, device: torch.device) -> bool:
    if precision == "auto":
        return device.type == "cuda"
    if precision in {"fp16", "amp", "mixed"}:
        return device.type == "cuda"
    return False


def load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        return yaml.safe_load(file)


def build_episode_safe_split(
    dataset: ChapterTransitionDataset,
    dataset_cfg: dict,
    seed: int,
) -> tuple[Subset, Subset, dict]:
    split_unit = str(dataset_cfg.get("split_unit", "episode"))
    val_fraction = float(dataset_cfg.get("validation_fraction", 0.15))
    if not 0.0 < val_fraction < 0.8:
        raise ValueError("dataset.validation_fraction must be between 0.0 and 0.8")
    if len(dataset) < 2:
        raise ValueError("At least two transitions are required for training and validation.")

    if split_unit == "transition":
        generator = torch.Generator().manual_seed(seed)
        indices = torch.randperm(len(dataset), generator=generator).tolist()
        val_size = max(1, int(round(len(indices) * val_fraction)))
        val_size = min(val_size, len(indices) - 1)
        val_indices = sorted(indices[:val_size])
        train_indices = sorted(indices[val_size:])
        return (
            Subset(dataset, train_indices),
            Subset(dataset, val_indices),
            {
                "split_unit": "transition",
                "train_transitions": len(train_indices),
                "val_transitions": len(val_indices),
                "train_episodes": [],
                "val_episodes": [],
            },
        )

    if split_unit != "episode":
        raise ValueError("dataset.split_unit must be 'episode' or 'transition'")

    episodes = dataset.episode_names()
    if len(episodes) < 2:
        raise ValueError(
            "Episode-safe split requires at least two recorded episodes. "
            "Collect more runs or set dataset.split_unit=transition for a smoke test only."
        )

    shuffled = episodes[:]
    random.Random(seed).shuffle(shuffled)
    val_episode_count = max(1, int(round(len(shuffled) * val_fraction)))
    val_episode_count = min(val_episode_count, len(shuffled) - 1)
    val_episodes = sorted(shuffled[:val_episode_count])
    train_episodes = sorted(shuffled[val_episode_count:])
    train_indices = dataset.indices_for_episodes(train_episodes)
    val_indices = dataset.indices_for_episodes(val_episodes)
    return (
        Subset(dataset, train_indices),
        Subset(dataset, val_indices),
        {
            "split_unit": "episode",
            "train_episodes": train_episodes,
            "val_episodes": val_episodes,
            "episode_counts": dataset.episode_counts(),
            "train_transitions": len(train_indices),
            "val_transitions": len(val_indices),
        },
    )


def make_loader(dataset: Subset, batch_size: int, shuffle: bool, num_workers: int, device: torch.device) -> DataLoader:
    return DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        num_workers=num_workers,
        pin_memory=device.type == "cuda",
        persistent_workers=num_workers > 0,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    args = parser.parse_args()

    config = load_config(args.config)
    train_cfg = config["training"]
    dataset_cfg = config["dataset"]
    model_cfg = config["model"]

    torch.manual_seed(int(train_cfg.get("seed", 42)))
    seed = int(train_cfg.get("seed", 42))
    device = resolve_device(str(train_cfg.get("device", "auto")))
    use_amp = resolve_amp_enabled(str(train_cfg.get("precision", "auto")), device)

    dataset = ChapterTransitionDataset(
        dataset_cfg["root"],
        image_size=int(dataset_cfg.get("image_size", 128)),
        max_transitions=int(dataset_cfg.get("max_transitions", 0)),
    )
    train_dataset, val_dataset, split_report = build_episode_safe_split(dataset, dataset_cfg, seed)
    min_transitions = int(dataset_cfg.get("min_train_transitions", 2))
    if len(train_dataset) < min_transitions:
        raise ValueError(
            f"Training split has {len(train_dataset)} transitions, "
            f"but dataset.min_train_transitions={min_transitions}."
        )

    batch_size = int(train_cfg.get("batch_size", 64))
    num_workers = int(train_cfg.get("num_workers", 2))
    train_loader = make_loader(train_dataset, batch_size, True, num_workers, device)
    val_loader = make_loader(val_dataset, batch_size, False, num_workers, device)

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
    scaler = torch.amp.GradScaler("cuda", enabled=use_amp)
    gaussian_weight = float(train_cfg.get("gaussian_weight", 0.05))
    grad_clip_norm = float(train_cfg.get("grad_clip_norm", 1.0))

    checkpoint_dir = Path(train_cfg.get("checkpoint_dir", "models/lewm/chapter_2/checkpoints"))
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    metrics_path = Path(train_cfg.get("metrics_path", "models/lewm/chapter_2/training_metrics.json"))
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    split_path = checkpoint_dir / "split_report.json"
    split_path.write_text(json.dumps(split_report, indent=2), encoding="utf-8")

    best_val = float("inf")
    history: list[dict[str, float | dict]] = []
    for epoch in range(1, int(train_cfg.get("epochs", 20)) + 1):
        model.train()
        train_loss = 0.0
        train_pred_loss = 0.0
        train_reg_loss = 0.0
        for batch in train_loader:
            frame = batch["frame"].to(device)
            action = batch["action"].to(device)
            next_frame = batch["next_frame"].to(device)
            with torch.amp.autocast("cuda", enabled=use_amp):
                output = model(frame, action, next_frame)
                pred_loss = prediction_loss(output["predicted_next"], output["target_next"])
                reg_loss = gaussian_regularizer(torch.cat([output["latent"], output["target_next"]], dim=0))
                loss = pred_loss + gaussian_weight * reg_loss

            optimizer.zero_grad(set_to_none=True)
            scaler.scale(loss).backward()
            if grad_clip_norm > 0.0:
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), grad_clip_norm)
            scaler.step(optimizer)
            scaler.update()
            train_loss += float(loss.item()) * frame.size(0)
            train_pred_loss += float(pred_loss.item()) * frame.size(0)
            train_reg_loss += float(reg_loss.item()) * frame.size(0)
        train_loss /= max(len(train_dataset), 1)
        train_pred_loss /= max(len(train_dataset), 1)
        train_reg_loss /= max(len(train_dataset), 1)

        val_report = evaluate_loss(model, val_loader, device, gaussian_weight)
        val_loss = float(val_report["loss"])
        row = {
            "epoch": float(epoch),
            "train_loss": train_loss,
            "train_prediction_loss": train_pred_loss,
            "train_gaussian_regularizer": train_reg_loss,
            "val_loss": val_loss,
            "val_prediction_loss": float(val_report["prediction_loss"]),
            "val_gaussian_regularizer": float(val_report["gaussian_regularizer"]),
            "val_latent": val_report["latent"],
        }
        history.append(row)
        print(json.dumps(row))

        latest = checkpoint_dir / "latest.pt"
        checkpoint = {
            "model": model.state_dict(),
            "config": config,
            "history": history,
            "split_report": split_report,
        }
        torch.save(checkpoint, latest)
        if val_loss < best_val:
            best_val = val_loss
            torch.save(checkpoint, checkpoint_dir / "best.pt")

    metrics_path.write_text(
        json.dumps(
            {
                "best_val_loss": best_val,
            "dataset_root": dataset_cfg["root"],
            "samples": len(dataset),
            "device": str(device),
            "amp_enabled": use_amp,
            "split": split_report,
            "history": history,
            },
            indent=2,
        ),
        encoding="utf-8",
    )


@torch.no_grad()
def evaluate_loss(model: LeWMModel, loader: DataLoader, device: torch.device, gaussian_weight: float) -> dict:
    model.eval()
    total_loss = 0.0
    total_pred = 0.0
    total_reg = 0.0
    count = 0
    latent_batches = []
    for batch in loader:
        frame = batch["frame"].to(device)
        action = batch["action"].to(device)
        next_frame = batch["next_frame"].to(device)
        output = model(frame, action, next_frame)
        pred_loss = prediction_loss(output["predicted_next"], output["target_next"])
        reg_loss = gaussian_regularizer(torch.cat([output["latent"], output["target_next"]], dim=0))
        loss = pred_loss + gaussian_weight * reg_loss
        total_loss += float(loss.item()) * frame.size(0)
        total_pred += float(pred_loss.item()) * frame.size(0)
        total_reg += float(reg_loss.item()) * frame.size(0)
        count += frame.size(0)
        latent_batches.append(output["latent"].detach().cpu())
    latents = torch.cat(latent_batches, dim=0) if latent_batches else torch.empty((0, 0))
    return {
        "loss": total_loss / max(count, 1),
        "prediction_loss": total_pred / max(count, 1),
        "gaussian_regularizer": total_reg / max(count, 1),
        "latent": latent_diagnostics(latents) if count > 1 else {},
    }


if __name__ == "__main__":
    main()
