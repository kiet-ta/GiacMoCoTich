# Raw-Pixel LeWorldModel Research Stack

This folder is the first implementation slice for the full raw-pixel LeWorldModel roadmap described in `docs/leworldmodel_research_textbook_v1.md`.

The goal is to train a reconstruction-free JEPA-style world model from Godot Chapter 2 frame/action transitions:

```text
image_t + action_t -> latent(image_t+1)
```

The current Godot rule-based LeWM remains the gameplay fallback and baseline.

## Layout

```text
research/lewm/
  configs/
    train_lewm_chapter1.yaml
    train_lewm_chapter2.yaml
    train_lewm_chapter3.yaml
    planner_chapter2.yaml
  lewm/
    datasets.py
    diagnostics.py
    losses.py
    models.py
    planning.py
  scripts/
    benchmark_device.py
    inspect_dataset.py
    train.py
    evaluate.py
    serve_sidecar.py
```

Expected dataset layout:

```text
ml_data/lewm_raw/chapter_1/
ml_data/lewm_raw/chapter_2/
ml_data/lewm_raw/chapter_3/
  episodes/
    ep_000001/
      frames/
        000000.png
        000001.png
      actions.jsonl
      metadata.jsonl
      episode.json
```

Each `actions.jsonl` row must contain `frame`, `next_frame`, and an `action` object.

Chapter 2 uses an 8D action vector:

```text
move_x, move_y, attack, dash, weapon_id/2, boss_action_id/6, aim_x, aim_y
```

## Quick Commands

Collect scripted Chapter 2 data:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\collect_chapter2_lewm.ps1 `
  -Mode scripted `
  -Profile mixed `
  -DurationSeconds 180
```

Inspect data before training:

```bash
PYTHONPATH=research/lewm python research/lewm/scripts/inspect_dataset.py \
  --config research/lewm/configs/train_lewm_chapter2.yaml \
  --output models/lewm/chapter_2/dataset_inspection.json
```

Benchmark CPU/CUDA before serious training:

```bash
PYTHONPATH=research/lewm python research/lewm/scripts/benchmark_device.py \
  --config research/lewm/configs/train_lewm_chapter2.yaml \
  --output models/lewm/chapter_2/device_benchmark.json
```

Train Chapter 2:

```bash
PYTHONPATH=research/lewm python research/lewm/scripts/train.py \
  --config research/lewm/configs/train_lewm_chapter2.yaml
```

Evaluate a checkpoint:

```bash
PYTHONPATH=research/lewm python research/lewm/scripts/evaluate.py \
  --config research/lewm/configs/train_lewm_chapter2.yaml \
  --checkpoint models/lewm/chapter_2/checkpoints/best.pt \
  --output models/lewm/chapter_2/evaluation.json
```

## Research Notes

- This is not a pixel reconstruction model.
- The training loss combines latent prediction loss and Gaussian/covariance regularization.
- Training validation uses episode-safe splits by default to avoid near-frame leakage.
- Training uses `device: auto` and `precision: auto`, so CUDA + AMP is used when available.
- The model is intentionally small so it can be iterated locally.
- Planning and Godot sidecar integration are scaffolded but require a collected dataset and trained checkpoint before live use.
