from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import torch
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lewm.losses import gaussian_regularizer, prediction_loss  # noqa: E402
from lewm.models import LeWMModel  # noqa: E402


def load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        return yaml.safe_load(file)


def candidate_devices() -> list[torch.device]:
    devices = [torch.device("cpu")]
    if torch.cuda.is_available():
        devices.append(torch.device("cuda"))
    return devices


def benchmark(device: torch.device, config: dict, batch_size: int, steps: int, warmup: int) -> dict:
    dataset_cfg = config["dataset"]
    model_cfg = config["model"]
    train_cfg = config["training"]
    image_size = int(dataset_cfg.get("image_size", 128))
    action_dim = int(model_cfg.get("action_dim", 8))
    use_amp = device.type == "cuda" and str(train_cfg.get("precision", "auto")) in {"auto", "amp", "fp16", "mixed"}

    model = LeWMModel(
        action_dim=action_dim,
        latent_dim=int(model_cfg.get("latent_dim", 256)),
        hidden_dim=int(model_cfg.get("hidden_dim", 512)),
    ).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-4)
    scaler = torch.amp.GradScaler("cuda", enabled=use_amp)

    frame = torch.rand(batch_size, 3, image_size, image_size, device=device)
    next_frame = torch.rand(batch_size, 3, image_size, image_size, device=device)
    action = torch.rand(batch_size, action_dim, device=device) * 2.0 - 1.0

    def step() -> float:
        optimizer.zero_grad(set_to_none=True)
        with torch.amp.autocast("cuda", enabled=use_amp):
            output = model(frame, action, next_frame)
            loss = prediction_loss(output["predicted_next"], output["target_next"])
            loss = loss + 0.05 * gaussian_regularizer(torch.cat([output["latent"], output["target_next"]], dim=0))
        scaler.scale(loss).backward()
        scaler.step(optimizer)
        scaler.update()
        return float(loss.item())

    for _ in range(warmup):
        step()
    if device.type == "cuda":
        torch.cuda.synchronize()

    started = time.perf_counter()
    last_loss = 0.0
    for _ in range(steps):
        last_loss = step()
    if device.type == "cuda":
        torch.cuda.synchronize()
    elapsed = max(time.perf_counter() - started, 1e-9)
    return {
        "device": str(device),
        "batch_size": batch_size,
        "steps": steps,
        "amp_enabled": use_amp,
        "seconds": elapsed,
        "samples_per_second": float(batch_size * steps / elapsed),
        "last_loss": last_loss,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--steps", type=int, default=10)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    config = load_config(args.config)
    results = [benchmark(device, config, args.batch_size, args.steps, args.warmup) for device in candidate_devices()]
    recommended = max(results, key=lambda row: row["samples_per_second"])
    report = {
        "results": results,
        "recommended_device": recommended["device"],
        "recommended_amp": bool(recommended["amp_enabled"]),
    }
    text = json.dumps(report, indent=2)
    print(text)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
