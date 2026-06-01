#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Scripts/run_v03_release_gate.sh is deprecated. Running the canonical 1.0 gate: Scripts/run_v10_release_gate.sh" >&2
exec "$ROOT_DIR/Scripts/run_v10_release_gate.sh" "$@"
