# GiacMoCoTich

Godot 2D prototype for a stage-based fairy tale game using a local LeWorldModel ML sidecar with a GDScript rule fallback.

The prototype now uses a chapter-select flow with local progression, 1-3 star completion ratings, and sequential unlocks from Chapter 1 to Chapter 3.

## Run

Open the project in Godot 4.x and run `res://scenes/GameRoot.tscn`.

By default the game attempts to call the local LeWorldModel sidecar at `127.0.0.1:8765`. If the sidecar is not running or returns an unsafe reaction, gameplay falls back to the local rule-based guardrail.

To disable ML calls explicitly:

```powershell
D:\Godot\godot.exe --path . -- --lewm-no-ml
```

## LeWorldModel sidecar

The MVP sidecar lives in `ml_sidecar/` and uses the JEPA-style PyTorch model code in `research/lewm/`.
The LeWM documentation entry point is `docs/lewm/README.md`.

Install Python 3.10 and dependencies, then start:

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install -r .\ml_sidecar\requirements.txt
powershell -ExecutionPolicy Bypass -File .\tools\start_lewm_sidecar.ps1
```

Pass `-Checkpoint .\models\lewm\<chapter>\checkpoints\best.pt` after training to let ML control reactions. Without a checkpoint, prediction requests fall back to the GDScript guardrail unless `-AllowUntrained` is used for API smoke testing.

Use `--lewm-record` after Godot's `--` separator to record raw-pixel rollout episodes under `ml_data/lewm_raw/`.

Train a chapter checkpoint after collecting episodes:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\train_lewm_chapter.ps1 -Chapter chapter_2
```

## Headless test

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test_godot.ps1
powershell -ExecutionPolicy Bypass -File .\tools\test_ml_sidecar_schema.ps1
```

The test script uses `D:\Godot\godot_console.exe` by default and redirects Godot user data into `.codex_godot_user/` so the console runner can write logs inside the workspace.

## Prototype controls

- `F1`: Chapter 1 forest topdown prototype
- `F2`: Chapter 2 topdown boss prototype
- `F3`: Chapter 3 strict climbing prototype
- `ESC`: Back to chapter menu
- `R`: Restart current chapter
- `F9`: Toggle debug world-state text

Progress is saved to `user://progress.json`. Chapter 1 is unlocked by default; later chapters unlock after completing the previous chapter.

Chapter 1:
- `WASD`: Move
- `E`: Interact

Chapter 2:
- `WASD`: Move
- Mouse: Aim
- Left mouse: Attack / shoot
- `1`: Axe
- `2`: Bow
- `Space` or right mouse: Dash

Chapter 3:
- `A/D`: Move
- Hold `Space`: Charge jump
- Release `Space`: Jump
