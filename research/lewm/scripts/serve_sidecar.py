from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import uvicorn


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8765, type=int)
    parser.add_argument("--checkpoint", default="")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[3]
    sys.path.insert(0, str(root / "ml_sidecar"))
    sys.path.insert(0, str(root / "research" / "lewm"))
    if args.checkpoint:
        os.environ["LEWM_CHECKPOINT"] = args.checkpoint

    uvicorn.run("lewm_sidecar.app:app", host=args.host, port=args.port)


if __name__ == "__main__":
    main()
