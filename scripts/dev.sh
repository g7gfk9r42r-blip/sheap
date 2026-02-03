#!/usr/bin/env bash
set -e
(cd server && npm ci && npm run dev)