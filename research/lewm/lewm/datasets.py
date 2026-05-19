from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import numpy as np
import torch
from PIL import Image
from torch.utils.data import Dataset


ACTION_DIM = 6


def action_to_vector(action: dict[str, Any]) -> torch.Tensor:
    """Convert a Godot action dictionary into a stable numeric vector."""
    values = np.zeros((ACTION_DIM,), dtype=np.float32)
    values[0] = float(action.get("move_x", 0.0))
    values[1] = float(action.get("move_y", 0.0))
    values[2] = float(action.get("attack", 0.0))
    values[3] = float(action.get("dash", 0.0))
    values[4] = float(action.get("weapon_id", 0.0)) / 2.0
    values[5] = float(action.get("boss_action_id", 0.0)) / 6.0
    return torch.from_numpy(values)


def load_image(path: Path, image_size: int) -> torch.Tensor:
    image = Image.open(path).convert("RGB")
    if image.size != (image_size, image_size):
        image = image.resize((image_size, image_size), Image.Resampling.BILINEAR)
    array = np.asarray(image, dtype=np.float32) / 255.0
    array = np.transpose(array, (2, 0, 1))
    return torch.from_numpy(array)


class ChapterTransitionDataset(Dataset):
    """Frame/action/next-frame transitions recorded from a Godot chapter."""

    def __init__(self, root: str | Path, image_size: int = 128, max_transitions: int = 0) -> None:
        self.root = Path(root)
        self.image_size = image_size
        self.samples = self._discover_samples(max_transitions)

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, index: int) -> dict[str, Any]:
        sample = self.samples[index]
        episode_dir: Path = sample["episode_dir"]
        frame = load_image(episode_dir / sample["frame"], self.image_size)
        next_frame = load_image(episode_dir / sample["next_frame"], self.image_size)
        action = action_to_vector(sample.get("action", {}))
        return {
            "frame": frame,
            "action": action,
            "next_frame": next_frame,
            "episode": episode_dir.name,
            "t": int(sample.get("t", index)),
        }

    def _discover_samples(self, max_transitions: int) -> list[dict[str, Any]]:
        episodes_dir = self.root / "episodes"
        if not episodes_dir.exists():
            raise FileNotFoundError(f"Missing dataset episodes directory: {episodes_dir}")

        samples: list[dict[str, Any]] = []
        for episode_dir in sorted(p for p in episodes_dir.iterdir() if p.is_dir()):
            actions_path = episode_dir / "actions.jsonl"
            if not actions_path.exists():
                continue
            with actions_path.open("r", encoding="utf-8") as file:
                for line in file:
                    if not line.strip():
                        continue
                    row = json.loads(line)
                    if "frame" not in row or "next_frame" not in row:
                        continue
                    row["episode_dir"] = episode_dir
                    samples.append(row)
                    if max_transitions > 0 and len(samples) >= max_transitions:
                        return samples
        if not samples:
            raise ValueError(f"No transitions found under {episodes_dir}")
        return samples


Chapter2TransitionDataset = ChapterTransitionDataset
