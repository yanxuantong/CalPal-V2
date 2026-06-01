#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="${SOURCE_ROOT:-$ROOT_DIR}"
cd "$ROOT_DIR"

fail() {
  echo "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "$path" ]] || fail "Missing required file: $path"
}

DEPENDENCY_CONTAINER="$SOURCE_ROOT/CalPal/App/DependencyContainer.swift"
REMOTE_AI_PROVIDER="$SOURCE_ROOT/CalPal/Services/RemoteAIProvider.swift"
PROJECT_FILE="$SOURCE_ROOT/CalPal.xcodeproj/project.pbxproj"
APP_SOURCE_DIR="$SOURCE_ROOT/CalPal"

require_file "$DEPENDENCY_CONTAINER"
require_file "$REMOTE_AI_PROVIDER"
require_file "$PROJECT_FILE"

if ! grep -Fq "static var live: DependencyContainer" "$DEPENDENCY_CONTAINER"; then
  fail "DependencyContainer.live is missing; cannot verify the production runtime graph."
fi

if ! grep -Fq "privacyConfiguration: .appStoreLocalOnly" "$DEPENDENCY_CONTAINER"; then
  fail "DependencyContainer must inject .appStoreLocalOnly for the 1.0 runtime."
fi

if ! grep -Fq "static let appStoreLocalOnly = ProductionPrivacyConfiguration" "$REMOTE_AI_PROVIDER"; then
  fail "ProductionPrivacyConfiguration.appStoreLocalOnly is missing."
fi

if ! grep -Fq "remoteAIPolicy: .localOnly" "$REMOTE_AI_PROVIDER"; then
  fail "appStoreLocalOnly must use RemoteCalendarAIPolicy.localOnly."
fi

if ! grep -Fq "allowsTelemetryExport: false" "$REMOTE_AI_PROVIDER"; then
  fail "appStoreLocalOnly must disable telemetry export."
fi

if grep -R --include='*.swift' -nE 'https?://' "$APP_SOURCE_DIR"; then
  fail "App source must not contain a default remote endpoint for the 1.0 local-only runtime."
fi

if grep -R --include='*.swift' -nE '\bURLSession\b' "$APP_SOURCE_DIR"; then
  fail "App source must not ship a URLSession-backed network path while 1.0 is documented as local-only."
fi

if grep -nE 'XCRemoteSwiftPackageReference|XCSwiftPackageProductDependency' "$PROJECT_FILE"; then
  fail "Project includes Swift package dependencies; review App Store privacy answers before shipping 1.0."
fi

prohibited_sdk_pattern='Firebase|Amplitude|Mixpanel|Sentry|Segment|PostHog|AppCenter|GoogleAnalytics|Datadog|Bugsnag|Crashlytics|RevenueCat|Adjust|AppsFlyer|OneSignal'
if grep -R --include='*.swift' --include='*.pbxproj' -nE "$prohibited_sdk_pattern" "$APP_SOURCE_DIR" "$PROJECT_FILE"; then
  fail "Potential analytics/crash/attribution/subscription SDK reference found in app source or project."
fi

echo "Local-only runtime verified."
