#!/usr/bin/env python3
"""
Package and upload weekly media (recipes + images) to the public server.

This uploads a tar.gz containing:
  - prospekte/<market>/<market>_recipes.json
  - recipe_images/<market>/R###.png

Endpoint (server):
  POST /admin/upload-media-tar
  Headers:
    x-admin-secret: <ADMIN_SECRET>
    Content-Type: application/gzip
"""

from __future__ import annotations

import argparse
import os
import tarfile
import tempfile
import urllib.request
from pathlib import Path


def _die(msg: str) -> None:
    raise SystemExit(f"❌ {msg}")


def _make_bundle(media_dir: Path, out_path: Path) -> None:
    prospekte = media_dir / "prospekte"
    images = media_dir / "recipe_images"
    if not prospekte.exists():
        _die(f"Missing folder: {prospekte}")
    if not images.exists():
        _die(f"Missing folder: {images}")

    with tarfile.open(out_path, "w:gz") as tf:
        tf.add(str(prospekte), arcname="prospekte")
        tf.add(str(images), arcname="recipe_images")


def _upload(base_url: str, admin_secret: str, bundle_path: Path) -> None:
    base = base_url.strip().rstrip("/")
    if not base.startswith("http://") and not base.startswith("https://"):
        _die("BASE_URL must start with http:// or https://")
    url = f"{base}/admin/upload-media-tar"

    data = bundle_path.read_bytes()
    req = urllib.request.Request(
        url=url,
        data=data,
        method="POST",
        headers={
            "x-admin-secret": admin_secret,
            "Content-Type": "application/gzip",
        },
    )

    with urllib.request.urlopen(req, timeout=60) as resp:
        body = resp.read().decode("utf-8", errors="replace")
        if resp.status < 200 or resp.status >= 300:
            _die(f"Upload failed: HTTP {resp.status} body={body[:400]}")
        print("✅ Upload OK")
        if body.strip():
            print(body)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", required=True, help="e.g. https://<service>.onrender.com")
    ap.add_argument(
        "--admin-secret",
        default=os.environ.get("ADMIN_SECRET", ""),
        help="Admin secret (or set env ADMIN_SECRET)",
    )
    ap.add_argument(
        "--media-dir",
        default=str(Path(__file__).resolve().parents[1] / "server" / "media"),
        help="Path to roman_app/server/media",
    )
    args = ap.parse_args()

    admin_secret = (args.admin_secret or "").strip()
    if not admin_secret:
        _die("Missing ADMIN_SECRET (pass --admin-secret or set env ADMIN_SECRET)")

    media_dir = Path(args.media_dir).resolve()
    if not media_dir.exists():
        _die(f"media dir not found: {media_dir}")

    with tempfile.TemporaryDirectory() as td:
        bundle = Path(td) / "media_bundle.tar.gz"
        print(f"📦 Packing media from: {media_dir}")
        _make_bundle(media_dir, bundle)
        print(f"⬆️ Uploading to: {args.base_url.strip().rstrip('/')}/admin/upload-media-tar")
        _upload(args.base_url, admin_secret, bundle)


if __name__ == "__main__":
    main()


