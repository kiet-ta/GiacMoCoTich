# GiacMoCoTich

Godot 2D prototype for a stage-based fairy tale game using a LeWorldModel-inspired reaction layer.

The prototype now uses a chapter-select flow with local progression, 1-3 star completion ratings, and sequential unlocks from Chapter 1 to Chapter 3.

## Run

Open the project in Godot 4.x and run `res://scenes/GameRoot.tscn`.

## Headless test

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test_godot.ps1
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
