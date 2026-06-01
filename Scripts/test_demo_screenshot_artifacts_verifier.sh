#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_fixture() {
  local dir="$1"
  mkdir -p "$dir/screenshots"
  cp Artifacts/AppStoreScreenshots/calpal-demo-home.png "$dir/screenshots/calpal-demo-home.png"
  cp Artifacts/AppStoreScreenshots/calpal-demo-home-dark.png "$dir/screenshots/calpal-demo-home-dark.png"
  cp AppStore/APP_STORE_CONNECT_SUBMISSION.md "$dir/submission.md"
}

valid_dir="$tmp_root/valid"
identical_dir="$tmp_root/identical"
missing_reference_dir="$tmp_root/missing-reference"
mismatched_dimensions_dir="$tmp_root/mismatched-dimensions"
not_png_dir="$tmp_root/not-png"

make_fixture "$valid_dir"
SCREENSHOT_DIR="$valid_dir/screenshots" SUBMISSION="$valid_dir/submission.md" bash Scripts/verify_demo_screenshot_artifacts.sh >/dev/null

make_fixture "$identical_dir"
cp "$identical_dir/screenshots/calpal-demo-home.png" "$identical_dir/screenshots/calpal-demo-home-dark.png"
if SCREENSHOT_DIR="$identical_dir/screenshots" SUBMISSION="$identical_dir/submission.md" bash Scripts/verify_demo_screenshot_artifacts.sh >/dev/null 2>&1; then
  echo "Expected demo screenshot verifier to reject identical Light/Dark screenshots." >&2
  exit 1
fi

make_fixture "$missing_reference_dir"
perl -0pi -e 's/Artifacts\/AppStoreScreenshots\/calpal-demo-home-dark\.png/Artifacts\/AppStoreScreenshots\/missing-dark.png/g' "$missing_reference_dir/submission.md"
if SCREENSHOT_DIR="$missing_reference_dir/screenshots" SUBMISSION="$missing_reference_dir/submission.md" bash Scripts/verify_demo_screenshot_artifacts.sh >/dev/null 2>&1; then
  echo "Expected demo screenshot verifier to reject missing App Store submission references." >&2
  exit 1
fi

make_fixture "$mismatched_dimensions_dir"
sips -z 900 400 "$mismatched_dimensions_dir/screenshots/calpal-demo-home-dark.png" >/dev/null
if SCREENSHOT_DIR="$mismatched_dimensions_dir/screenshots" SUBMISSION="$mismatched_dimensions_dir/submission.md" bash Scripts/verify_demo_screenshot_artifacts.sh >/dev/null 2>&1; then
  echo "Expected demo screenshot verifier to reject mismatched screenshot dimensions." >&2
  exit 1
fi

make_fixture "$not_png_dir"
printf 'not a png\n' >"$not_png_dir/screenshots/calpal-demo-home.png"
if SCREENSHOT_DIR="$not_png_dir/screenshots" SUBMISSION="$not_png_dir/submission.md" bash Scripts/verify_demo_screenshot_artifacts.sh >/dev/null 2>&1; then
  echo "Expected demo screenshot verifier to reject non-PNG artifacts." >&2
  exit 1
fi

echo "Demo screenshot artifact verifier self-test passed."
