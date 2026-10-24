#!/usr/bin/env bash
# Builds Substratal Hub (Debug) and launches it for local testing.
#
#   scripts/run-local.sh                      # against the production API, https://api.substratalapps.com
#   scripts/run-local.sh http://localhost:8080   # against the API repo's local devserver (make run there)
#
# Generates the Xcode project when project.yml is newer (or it's missing),
# quits a running copy first, checks the API answers /health, then opens the
# app with -SubstratalAPIBaseURL so this run uses that API without changing
# the app's saved setting. Sign in with your own Substratal account.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="${1:-https://api.substratalapps.com}"
API="${API%/}"
DERIVED="$ROOT/build/DerivedData"
APP="$DERIVED/Build/Products/Debug/Substratal Hub.app"

cd "$ROOT"

command -v xcodegen >/dev/null || { echo "run-local: XcodeGen is required: brew install xcodegen" >&2; exit 1; }
if [[ ! -d SubstratalHub.xcodeproj || project.yml -nt SubstratalHub.xcodeproj ]]; then
  echo "==> Generating SubstratalHub.xcodeproj"
  xcodegen generate --quiet
fi

echo "==> Checking $API/health"
if ! curl -fsS -m 10 "$API/health" >/dev/null; then
  echo "run-local: $API/health didn't answer. Is the API running and the URL right? (No /v1: the version is a header now.)" >&2
  exit 1
fi

echo "==> Building (Debug). The first build takes a few minutes: it generates the API client."
log="$(mktemp -t substratal-build)"
if ! xcodebuild -project SubstratalHub.xcodeproj -scheme SubstratalHub -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath "$DERIVED" \
    -skipPackagePluginValidation -skipMacroValidation build >"$log" 2>&1; then
  grep -E 'error:' "$log" | sort -u >&2 || true
  echo "run-local: build failed; full log at $log" >&2
  exit 1
fi
rm -f "$log"

if pgrep -x "Substratal Hub" >/dev/null; then
  echo "==> Quitting the running copy"
  osascript -e 'quit app "Substratal Hub"' >/dev/null 2>&1 || pkill -x "Substratal Hub" || true
  for _ in {1..20}; do pgrep -x "Substratal Hub" >/dev/null || break; sleep 0.25; done
fi

echo "==> Launching against $API"
open -n "$APP" --args -SubstratalAPIBaseURL "$API"
echo "Done. App logs: log stream --predicate 'subsystem == \"com.substratalapps.hub\"'"
