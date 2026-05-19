from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class PlannerHandler(BaseHTTPRequestHandler):
    """Minimal sidecar scaffold.

    This server intentionally returns fallback actions until a trained planner
    checkpoint and scoring probe are connected.
    """

    def do_GET(self) -> None:
        if self.path != "/health":
            self.send_response(404)
            self.end_headers()
            return
        self._send_json({"ok": True, "mode": "fallback_scaffold"})

    def do_POST(self) -> None:
        if self.path != "/plan":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", "0"))
        _payload = self.rfile.read(length)
        self._send_json({
            "ok": True,
            "source": "fallback_scaffold",
            "boss_action_id": 0,
            "confidence": 0.0,
            "reason": "LeWM planner checkpoint is not connected yet.",
        })

    def _send_json(self, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8765, type=int)
    args = parser.parse_args()
    server = HTTPServer((args.host, args.port), PlannerHandler)
    print(f"LeWM sidecar scaffold listening on http://{args.host}:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
