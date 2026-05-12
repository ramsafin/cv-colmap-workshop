#!/usr/bin/env bash
set -euo pipefail

mkdir -p /workspace/data/video
mkdir -p /workspace/data/images
mkdir -p /workspace/data/workspace
mkdir -p /workspace/data/workspace/logs
mkdir -p /workspace/data/workspace/sparse
mkdir -p /workspace/data/workspace/text
mkdir -p /workspace/data/workspace/ply

echo "[entrypoint] Workspace: /workspace"
echo "[entrypoint] Ready."

exec "$@"