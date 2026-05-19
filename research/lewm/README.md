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
    train_lewm_chapter2.yaml
    planner_chapter2.yaml
  lewm/
    datasets.py
    losses.py
    models.py
    planning.py
  scripts/
    train.py
    evaluate.py
    serve_sidecar.py
```

Expected dataset layout:

```text
data/lewm_raw/chapter2/
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

## Quick Commands

```bash
PYTHONPATH=research/lewm python research/lewm/scripts/train.py \
  --config research/lewm/configs/train_lewm_chapter2.yaml
```

```bash
PYTHONPATH=research/lewm python research/lewm/scripts/evaluate.py \
  --config research/lewm/configs/train_lewm_chapter2.yaml \
  --checkpoint models/lewm/chapter2/checkpoints/best.pt
```

## Research Notes

- This is not a pixel reconstruction model.
- The training loss combines latent prediction loss and Gaussian/covariance regularization.
- The model is intentionally small so it can be iterated locally.
- Planning and Godot sidecar integration are scaffolded but require a collected dataset and trained checkpoint before live use.
