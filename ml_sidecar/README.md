# LeWorldModel MVP Sidecar

Local inference service for the Godot MVP.

The sidecar runs a PyTorch JEPA-style LeWorldModel core from `research/lewm`
and maps latent predictions into the Godot reaction contract. It is intended
for PC Windows prototype runs on `127.0.0.1`; Godot keeps the existing
rule-based system as a safety fallback when the sidecar is unavailable.

## Setup

Python is not vendored in this repository. Install Python 3.10, then:

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install -r .\ml_sidecar\requirements.txt
```

Start the service with a trained checkpoint:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\start_lewm_sidecar.ps1 -Checkpoint .\models\lewm\chapter_2\checkpoints\best.pt
```

Without a checkpoint the sidecar can still answer `/health`, but prediction
requests are rejected so Godot falls back to the rule guardrail. For a local
API smoke test without trained weights, pass `-AllowUntrained`.

Run Godot with ML enabled by default. To force fallback only:

```powershell
D:\Godot\godot.exe --path . -- --lewm-no-ml
```

Runtime selection defaults to `--lewm-mode=auto`: Godot accepts ML only when
the sidecar response passes confidence and latency gates, otherwise it uses
the rule fallback. Use `--lewm-mode=ml` for forced ML review or
`--lewm-mode=fallback` for baseline runs.

Headless test runs disable ML requests by default to avoid noisy sidecar
connection attempts. To test sidecar calls in headless mode, pass
`--lewm-force-ml`.

## API

- `GET /health`
- `POST /v1/session/start`
- `POST /v1/predict_reaction`
- `POST /v1/session/end`

`/v1/predict_reaction` expects a downscaled PNG frame, an action vector,
scalar context, and candidate reactions. It returns one safe reaction with:

```text
intent, severity, effects, ui, confidence, model_version, latency_ms, source=ml
```

Large data/checkpoints stay outside git under `ml_data/lewm_raw/` and
`models/lewm/`.
