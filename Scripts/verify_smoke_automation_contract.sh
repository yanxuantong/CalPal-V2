#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT_PATH="$ROOT_DIR/AppStore/ProductionPolish/2026-05-28/SMOKE_AUTOMATION_CONTRACT.md"

cd "$ROOT_DIR"

if [[ ! -s "$CONTRACT_PATH" ]]; then
  echo "Missing smoke automation contract: $CONTRACT_PATH" >&2
  exit 1
fi

missing=0
while IFS= read -r identifier; do
  [[ -z "$identifier" ]] && continue
  if ! grep -R --include='*.swift' -Fq "$identifier" CalPal CalPalTests; then
    echo "Smoke automation identifier is documented but not present in source/tests: $identifier" >&2
    missing=1
  fi
done < <(awk -F'`' '/^- id: `/ { print $2 }' "$CONTRACT_PATH")

if (( missing != 0 )); then
  exit 1
fi

echo "Smoke automation contract passed."
