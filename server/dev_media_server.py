#!/usr/bin/env python3
"""
Tiny CORS-enabled static server for Flutter Web dev.

Serves ./media/ at:
  http://localhost:<port>/media/...

This matches the app's default:
  API_BASE_URL=http://localhost:3000

Why needed:
- Flutter Web uses browser fetch() -> requires CORS headers for cross-origin (dev server port != 3000).
- Python's default http.server has no CORS.
"""

from __future__ import annotations

import argparse
import http.server
import socketserver
import functools
from pathlib import Path
import errno


ROOT = Path(__file__).resolve().parent  # roman_app/server


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        # CORS for dev
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,HEAD,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.end_headers()

    def log_message(self, format: str, *args) -> None:
        # keep console clean
        return


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main() -> None:
    if not (ROOT / "media").exists():
        raise SystemExit(f"Missing server media folder: {ROOT / 'media'}")

    parser = argparse.ArgumentParser(description="CORS-enabled static server for roman_app/server/media")
    parser.add_argument(
        "--port",
        type=int,
        default=3000,
        help="Port to listen on (default: 3000). Use 0 to auto-pick a free port.",
    )
    parser.add_argument("--host", type=str, default="localhost", help="Host to bind for display (default: localhost)")
    args = parser.parse_args()

    # Important: serve files from roman_app/server (so /media/... resolves)
    handler = functools.partial(Handler, directory=str(ROOT))
    try:
        with ReusableTCPServer(("", args.port), handler) as httpd:
            actual_port = httpd.server_address[1]
            base = f"http://{args.host}:{actual_port}"
            print(f"✅ dev_media_server: serving {ROOT} on {base}/")
            print(f"   - media JSON:   {base}/media/prospekte/<market>/<market>_recipes.json")
            print(f"   - media images: {base}/media/recipe_images/<market>/R001.png")
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                print("\n🛑 dev_media_server: stopped")
    except OSError as e:
        if e.errno in (errno.EADDRINUSE, 48):
            raise SystemExit(
                f"Port {args.port} is already in use.\n"
                f"- If the server is already running, you don't need to start it again.\n"
                f"- Or pick another port: `python3 server/dev_media_server.py --port 3002`\n"
                f"- Or auto-pick: `python3 server/dev_media_server.py --port 0`"
            )
        raise


if __name__ == "__main__":
    main()


