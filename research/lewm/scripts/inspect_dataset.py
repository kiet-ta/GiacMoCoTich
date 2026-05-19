from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lewm.datasets import action_to_vector  # noqa: E402


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        return yaml.safe_load(file)


def inspect_dataset(root: Path, image_size: int, max_image_checks: int) -> dict[str, Any]:
    episodes_dir = root / "episodes"
    report: dict[str, Any] = {
        "root": str(root),
        "expected_image_size": image_size,
        "ok": True,
        "episodes": 0,
        "transitions": 0,
        "metadata_rows": 0,
        "missing_files": [],
        "malformed_rows": [],
        "image_size_mismatches": [],
        "action_min": None,
        "action_max": None,
        "source_counts": {},
        "scripted_profile_counts": {},
        "episode_summaries": [],
        "recommendations": [],
    }

    if not episodes_dir.exists():
        report["ok"] = False
        report["recommendations"].append("Record gameplay with --lewm-record before training.")
        return report

    action_min: list[float] | None = None
    action_max: list[float] | None = None
    image_checks_left = max_image_checks

    for episode_dir in sorted(path for path in episodes_dir.iterdir() if path.is_dir()):
        actions_path = episode_dir / "actions.jsonl"
        metadata_path = episode_dir / "metadata.jsonl"
        summary = {
            "episode": episode_dir.name,
            "transitions": 0,
            "metadata_rows": 0,
            "first_frame": "",
            "last_frame": "",
        }
        report["episodes"] += 1

        if not actions_path.exists():
            report["missing_files"].append(str(actions_path))
            continue

        with actions_path.open("r", encoding="utf-8") as file:
            for line_no, line in enumerate(file, start=1):
                if not line.strip():
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    report["malformed_rows"].append(f"{actions_path}:{line_no}")
                    continue

                frame = str(row.get("frame", ""))
                next_frame = str(row.get("next_frame", ""))
                if not frame or not next_frame:
                    report["malformed_rows"].append(f"{actions_path}:{line_no}")
                    continue

                for frame_rel in (frame, next_frame):
                    frame_path = episode_dir / frame_rel
                    if not frame_path.exists():
                        report["missing_files"].append(str(frame_path))
                    elif image_checks_left > 0:
                        with Image.open(frame_path) as image:
                            if image.size != (image_size, image_size):
                                report["image_size_mismatches"].append({
                                    "path": str(frame_path),
                                    "size": list(image.size),
                                })
                        image_checks_left -= 1

                action = action_to_vector(row.get("action", {})).tolist()
                if action_min is None:
                    action_min = action[:]
                    action_max = action[:]
                else:
                    action_min = [min(a, b) for a, b in zip(action_min, action)]
                    action_max = [max(a, b) for a, b in zip(action_max or action, action)]

                summary["transitions"] += 1
                report["transitions"] += 1
                summary["first_frame"] = summary["first_frame"] or frame
                summary["last_frame"] = next_frame

        if metadata_path.exists():
            with metadata_path.open("r", encoding="utf-8") as file:
                for line_no, line in enumerate(file, start=1):
                    if not line.strip():
                        continue
                    summary["metadata_rows"] += 1
                    try:
                        metadata_row = json.loads(line)
                    except json.JSONDecodeError:
                        report["malformed_rows"].append(f"{metadata_path}:{line_no}")
                        continue
                    metadata = metadata_row.get("metadata", {})
                    source = str(metadata.get("record_source", "unknown"))
                    profile = str(metadata.get("scripted_profile", "unknown"))
                    report["source_counts"][source] = int(report["source_counts"].get(source, 0)) + 1
                    report["scripted_profile_counts"][profile] = int(report["scripted_profile_counts"].get(profile, 0)) + 1
                report["metadata_rows"] += summary["metadata_rows"]

        report["episode_summaries"].append(summary)

    report["action_min"] = action_min
    report["action_max"] = action_max

    if report["episodes"] < 2:
        report["recommendations"].append("Collect at least two episodes for episode-safe validation split.")
    if report["transitions"] < 500:
        report["recommendations"].append("For first useful training, collect at least 500 transitions; prefer thousands.")
    sources = set(report["source_counts"].keys())
    if report["metadata_rows"] > 0 and not {"human", "scripted"}.issubset(sources):
        report["recommendations"].append("For the chosen plan, mix human and scripted Chapter 2 episodes before the review run.")
    if report["missing_files"] or report["malformed_rows"] or report["image_size_mismatches"]:
        report["ok"] = False
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=None)
    parser.add_argument("--root", type=Path, default=None)
    parser.add_argument("--image-size", type=int, default=None)
    parser.add_argument("--max-image-checks", type=int, default=32)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--allow-missing", action="store_true")
    args = parser.parse_args()

    config: dict[str, Any] = {}
    if args.config is not None:
        config = load_config(args.config)

    dataset_cfg = config.get("dataset", {})
    root = args.root or Path(dataset_cfg.get("root", "ml_data/lewm_raw/chapter_2"))
    image_size = args.image_size or int(dataset_cfg.get("image_size", 128))
    report = inspect_dataset(root, image_size, args.max_image_checks)

    text = json.dumps(report, indent=2)
    print(text)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")

    if not report["ok"] and not args.allow_missing:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
