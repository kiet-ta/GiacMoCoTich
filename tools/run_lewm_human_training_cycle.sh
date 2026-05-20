#!/usr/bin/env bash
set -euo pipefail

CHAPTER="chapter_2"
GODOT_BIN="${GODOT_BIN:-godot}"
PYTHON_BIN=""
IMAGE_SIZE="128"
CAPTURE_INTERVAL="0.10"
BENCHMARK_BATCH_SIZE="32"
BENCHMARK_STEPS="30"
SIDECAR_HOST="127.0.0.1"
SIDECAR_PORT="8765"
COLLECT_WITH_ML="0"
SKIP_GAMEPLAY="0"
SKIP_TRAIN="0"
SKIP_BENCHMARK="0"
NO_SIDECAR_RESTART="0"
KEEP_EXISTING_SIDECAR="0"

usage() {
  cat <<'EOF'
Usage:
  bash tools/run_lewm_human_training_cycle.sh [options]

Options:
  --chapter <chapter_1|chapter_2|chapter_3>
  --godot-bin <path-or-command>       Default: godot or $GODOT_BIN
  --python <path-or-command>          Default: .venv/bin/python, then python3
  --image-size <pixels>               Default: 128
  --capture-interval <seconds>        Default: 0.10
  --benchmark-batch-size <n>          Default: 32
  --benchmark-steps <n>               Default: 30
  --sidecar-host <host>               Default: 127.0.0.1
  --sidecar-port <port>               Default: 8765
  --collect-with-ml                   Do not pass --lewm-no-ml during collection
  --skip-gameplay                     Use existing dataset; do not open Godot
  --skip-train                        Inspect/evaluate without training
  --skip-benchmark                    Skip device benchmark
  --no-sidecar-restart                Do not restart sidecar after evaluation
  --keep-existing-sidecar             Start sidecar without stopping an existing listener
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chapter|-Chapter)
      CHAPTER="$2"
      shift 2
      ;;
    --godot-bin|--godot-path)
      GODOT_BIN="$2"
      shift 2
      ;;
    --python)
      PYTHON_BIN="$2"
      shift 2
      ;;
    --image-size)
      IMAGE_SIZE="$2"
      shift 2
      ;;
    --capture-interval)
      CAPTURE_INTERVAL="$2"
      shift 2
      ;;
    --benchmark-batch-size)
      BENCHMARK_BATCH_SIZE="$2"
      shift 2
      ;;
    --benchmark-steps)
      BENCHMARK_STEPS="$2"
      shift 2
      ;;
    --sidecar-host)
      SIDECAR_HOST="$2"
      shift 2
      ;;
    --sidecar-port)
      SIDECAR_PORT="$2"
      shift 2
      ;;
    --collect-with-ml)
      COLLECT_WITH_ML="1"
      shift
      ;;
    --skip-gameplay)
      SKIP_GAMEPLAY="1"
      shift
      ;;
    --skip-train)
      SKIP_TRAIN="1"
      shift
      ;;
    --skip-benchmark)
      SKIP_BENCHMARK="1"
      shift
      ;;
    --no-sidecar-restart)
      NO_SIDECAR_RESTART="1"
      shift
      ;;
    --keep-existing-sidecar)
      KEEP_EXISTING_SIDECAR="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

case "$CHAPTER" in
  chapter_1)
    CONFIG="$ROOT/research/lewm/configs/train_lewm_chapter1.yaml"
    ;;
  chapter_2)
    CONFIG="$ROOT/research/lewm/configs/train_lewm_chapter2.yaml"
    ;;
  chapter_3)
    CONFIG="$ROOT/research/lewm/configs/train_lewm_chapter3.yaml"
    ;;
  *)
    echo "Invalid chapter: $CHAPTER" >&2
    exit 2
    ;;
esac

if [[ -z "$PYTHON_BIN" ]]; then
  if [[ -x "$ROOT/.venv/bin/python" ]]; then
    PYTHON_BIN="$ROOT/.venv/bin/python"
  else
    PYTHON_BIN="python3"
  fi
fi

step() {
  echo
  echo "==> $1"
}

find_pids_on_port() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
  elif command -v fuser >/dev/null 2>&1; then
    fuser -n tcp "$port" 2>/dev/null || true
  elif command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :$port" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 || true
  else
    true
  fi
}

stop_sidecar_on_port() {
  local port="$1"
  local pids
  local stopped="0"
  pids="$(find_pids_on_port "$port" | tr ' ' '\n' | sed '/^$/d' | sort -u || true)"
  for pid in $pids; do
    echo "Stopping existing sidecar process on port ${port}: PID ${pid}"
    kill "$pid" 2>/dev/null || true
    stopped="1"
  done
  if [[ "$stopped" == "1" ]]; then
    sleep 1
  fi
}

if [[ "$SKIP_GAMEPLAY" != "1" ]]; then
  step "Open Godot and record human gameplay"
  if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
    echo "Godot executable was not found: $GODOT_BIN" >&2
    echo "Pass --godot-bin /path/to/godot or set GODOT_BIN." >&2
    exit 1
  fi

  godot_args=(
    "--path" "$ROOT"
    "--"
    "--lewm-record"
    "--lewm-image-size=$IMAGE_SIZE"
    "--lewm-capture-interval=$CAPTURE_INTERVAL"
  )
  if [[ "$COLLECT_WITH_ML" != "1" ]]; then
    godot_args+=("--lewm-no-ml")
  fi

  "$GODOT_BIN" "${godot_args[@]}" &
  game_pid="$!"
  echo "Godot started with PID ${game_pid}. Play the game, then close the Godot game window to continue training."
  wait "$game_pid"
  echo "Godot closed. Continuing LeWM pipeline."
fi

mkdir -p "$ROOT/models/lewm/$CHAPTER"

step "Inspect LeWM dataset"
PYTHONPATH="$ROOT/research/lewm" "$PYTHON_BIN" "$ROOT/research/lewm/scripts/inspect_dataset.py" \
  --config "$CONFIG" \
  --output "$ROOT/models/lewm/$CHAPTER/dataset_inspection.json"

if [[ "$SKIP_TRAIN" != "1" ]]; then
  step "Train LeWM checkpoint"
  PYTHONPATH="$ROOT/research/lewm" "$PYTHON_BIN" "$ROOT/research/lewm/scripts/train.py" \
    --config "$CONFIG"
fi

step "Evaluate LeWM checkpoint"
CHECKPOINT="$ROOT/models/lewm/$CHAPTER/checkpoints/best.pt"
PYTHONPATH="$ROOT/research/lewm" "$PYTHON_BIN" "$ROOT/research/lewm/scripts/evaluate.py" \
  --config "$CONFIG" \
  --checkpoint "$CHECKPOINT" \
  --output "$ROOT/models/lewm/$CHAPTER/evaluation.json"

if [[ "$SKIP_BENCHMARK" != "1" ]]; then
  step "Benchmark LeWM training device"
  PYTHONPATH="$ROOT/research/lewm" "$PYTHON_BIN" "$ROOT/research/lewm/scripts/benchmark_device.py" \
    --config "$CONFIG" \
    --batch-size "$BENCHMARK_BATCH_SIZE" \
    --steps "$BENCHMARK_STEPS" \
    --output "$ROOT/models/lewm/$CHAPTER/device_benchmark.json"
fi

if [[ "$NO_SIDECAR_RESTART" != "1" ]]; then
  step "Restart LeWM sidecar with latest checkpoint"
  if [[ ! -f "$CHECKPOINT" ]]; then
    echo "Checkpoint was not found: $CHECKPOINT" >&2
    exit 1
  fi

  if [[ "$KEEP_EXISTING_SIDECAR" != "1" ]]; then
    stop_sidecar_on_port "$SIDECAR_PORT"
  fi

  sidecar_log="$ROOT/models/lewm/$CHAPTER/sidecar.log"
  PYTHONPATH="$ROOT/ml_sidecar:$ROOT/research/lewm" \
  LEWM_ACTION_DIM="8" \
  LEWM_CHECKPOINT="$CHECKPOINT" \
  "$PYTHON_BIN" -m uvicorn lewm_sidecar.app:app \
    --host "$SIDECAR_HOST" \
    --port "$SIDECAR_PORT" \
    > "$sidecar_log" 2>&1 &
  sidecar_pid="$!"
  echo "Sidecar started with PID ${sidecar_pid}. Log: ${sidecar_log}"

  health=""
  health_url="http://${SIDECAR_HOST}:${SIDECAR_PORT}/health"
  for _ in $(seq 1 20); do
    if health="$("$PYTHON_BIN" -c 'import sys, urllib.request; print(urllib.request.urlopen(sys.argv[1], timeout=3).read().decode())' "$health_url" 2>/dev/null)"; then
      break
    fi
    sleep 1
  done

  if [[ -z "$health" ]]; then
    echo "Sidecar did not become healthy on ${health_url}" >&2
    tail -n 40 "$sidecar_log" >&2 || true
    exit 1
  fi
  echo "$health"
fi

echo
echo "LeWM human training cycle completed."
