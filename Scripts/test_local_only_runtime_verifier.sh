#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_fixture() {
  local dir="$1"
  mkdir -p "$dir/CalPal/App" "$dir/CalPal/Services" "$dir/CalPal.xcodeproj"
  cat >"$dir/CalPal/App/DependencyContainer.swift" <<'EOF'
struct DependencyContainer {
    static var live: DependencyContainer {
        DependencyContainer(privacyConfiguration: .appStoreLocalOnly)
    }

    let privacyConfiguration: ProductionPrivacyConfiguration
}
EOF

  cat >"$dir/CalPal/Services/RemoteAIProvider.swift" <<'EOF'
enum RemoteCalendarAIPolicy {
    case localOnly
}

struct ProductionPrivacyConfiguration {
    static let appStoreLocalOnly = ProductionPrivacyConfiguration(
        remoteAIPolicy: .localOnly,
        allowsTelemetryExport: false
    )

    let remoteAIPolicy: RemoteCalendarAIPolicy
    let allowsTelemetryExport: Bool
}
EOF

  cat >"$dir/CalPal.xcodeproj/project.pbxproj" <<'EOF'
// Minimal project fixture without package dependencies.
EOF
}

valid_dir="$tmp_root/valid"
remote_policy_dir="$tmp_root/remote-policy"
endpoint_dir="$tmp_root/endpoint"
urlsession_dir="$tmp_root/urlsession"
package_dir="$tmp_root/package"
sdk_dir="$tmp_root/sdk"

make_fixture "$valid_dir"
SOURCE_ROOT="$valid_dir" bash Scripts/verify_local_only_runtime.sh >/dev/null

make_fixture "$remote_policy_dir"
perl -0pi -e 's/remoteAIPolicy: \.localOnly/remoteAIPolicy: .remoteAllowed/g' "$remote_policy_dir/CalPal/Services/RemoteAIProvider.swift"
if SOURCE_ROOT="$remote_policy_dir" bash Scripts/verify_local_only_runtime.sh >/dev/null 2>&1; then
  echo "Expected local-only runtime verifier to reject a non-local remote AI policy." >&2
  exit 1
fi

make_fixture "$endpoint_dir"
printf '\nlet endpoint = "https://api.example.invalid"\n' >>"$endpoint_dir/CalPal/Services/RemoteAIProvider.swift"
if SOURCE_ROOT="$endpoint_dir" bash Scripts/verify_local_only_runtime.sh >/dev/null 2>&1; then
  echo "Expected local-only runtime verifier to reject default HTTP(S) endpoints." >&2
  exit 1
fi

make_fixture "$urlsession_dir"
printf '\nlet session = URLSession.shared\n' >>"$urlsession_dir/CalPal/Services/RemoteAIProvider.swift"
if SOURCE_ROOT="$urlsession_dir" bash Scripts/verify_local_only_runtime.sh >/dev/null 2>&1; then
  echo "Expected local-only runtime verifier to reject URLSession networking." >&2
  exit 1
fi

make_fixture "$package_dir"
printf '\nXCRemoteSwiftPackageReference /* remote package */\n' >>"$package_dir/CalPal.xcodeproj/project.pbxproj"
if SOURCE_ROOT="$package_dir" bash Scripts/verify_local_only_runtime.sh >/dev/null 2>&1; then
  echo "Expected local-only runtime verifier to reject Swift package dependencies." >&2
  exit 1
fi

make_fixture "$sdk_dir"
printf '\nlet analytics = "Firebase"\n' >>"$sdk_dir/CalPal/App/DependencyContainer.swift"
if SOURCE_ROOT="$sdk_dir" bash Scripts/verify_local_only_runtime.sh >/dev/null 2>&1; then
  echo "Expected local-only runtime verifier to reject analytics/crash SDK markers." >&2
  exit 1
fi

echo "Local-only runtime verifier self-test passed."
