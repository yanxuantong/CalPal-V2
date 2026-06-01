#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_fixture() {
  local dir="$1"
  mkdir -p "$dir/AppStore/ProductionPolish/2026-05-28" "$dir/CalPal" "$dir/CalPalTests"
  cat >"$dir/AppStore/ProductionPolish/2026-05-28/SMOKE_AUTOMATION_CONTRACT.md" <<'EOF'
# Smoke Automation Contract

- id: `commandHomeSettings`
  purpose: Open Settings.
- id: `agendaTimeline`
  purpose: Confirm agenda rendered.
EOF

  cat >"$dir/CalPal/CommandHomeView.swift" <<'EOF'
let settingsID = "commandHomeSettings"
EOF

  cat >"$dir/CalPalTests/SmokeContractTests.swift" <<'EOF'
let agendaID = "agendaTimeline"
EOF
}

valid_dir="$tmp_root/valid"
missing_id_dir="$tmp_root/missing-id"
empty_contract_dir="$tmp_root/empty-contract"
missing_contract_dir="$tmp_root/missing-contract"

make_fixture "$valid_dir"
SOURCE_ROOT="$valid_dir" bash Scripts/verify_smoke_automation_contract.sh >/dev/null

make_fixture "$missing_id_dir"
cat >>"$missing_id_dir/AppStore/ProductionPolish/2026-05-28/SMOKE_AUTOMATION_CONTRACT.md" <<'EOF'
- id: `missingAutomationID`
  purpose: This id is not implemented.
EOF
if SOURCE_ROOT="$missing_id_dir" bash Scripts/verify_smoke_automation_contract.sh >/dev/null 2>&1; then
  echo "Expected smoke automation contract verifier to reject documented IDs missing from source/tests." >&2
  exit 1
fi

make_fixture "$empty_contract_dir"
cat >"$empty_contract_dir/AppStore/ProductionPolish/2026-05-28/SMOKE_AUTOMATION_CONTRACT.md" <<'EOF'
# Smoke Automation Contract

No stable identifiers documented here.
EOF
if SOURCE_ROOT="$empty_contract_dir" bash Scripts/verify_smoke_automation_contract.sh >/dev/null 2>&1; then
  echo "Expected smoke automation contract verifier to reject a contract with no IDs." >&2
  exit 1
fi

make_fixture "$missing_contract_dir"
rm "$missing_contract_dir/AppStore/ProductionPolish/2026-05-28/SMOKE_AUTOMATION_CONTRACT.md"
if SOURCE_ROOT="$missing_contract_dir" bash Scripts/verify_smoke_automation_contract.sh >/dev/null 2>&1; then
  echo "Expected smoke automation contract verifier to reject a missing contract file." >&2
  exit 1
fi

echo "Smoke automation contract verifier self-test passed."
