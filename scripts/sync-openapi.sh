#!/usr/bin/env bash
# Vendors the Platform API's OpenAPI document into the app and the help site.
#
#   scripts/sync-openapi.sh [SOURCE]
#
# SOURCE is a path or URL to openapi.yaml. Default: the API repo's main branch,
# which is what production runs (main deploys on merge). The same file feeds:
#   - Packages/SubstratalKit/Sources/SubstratalAPI/openapi.yaml  (swift-openapi-generator input)
#   - help/api/openapi.yaml                                      (Swagger UI on the help site)
# Prints the spec's info.version. Exits 0 with "unchanged" when nothing moved,
# so the scheduled workflow can decide whether to open a pull request.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${1:-https://raw.githubusercontent.com/CompositeCode/substratalapps.com/main/docs/openapi.yaml}"
APP_COPY="$ROOT/Packages/SubstratalKit/Sources/SubstratalAPI/openapi.yaml"
HELP_COPY="$ROOT/help/api/openapi.yaml"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if [[ "$SOURCE" =~ ^https?:// ]]; then
  curl -fsSL "$SOURCE" -o "$tmp"
else
  cp "$SOURCE" "$tmp"
fi

grep -q '^openapi: 3' "$tmp" || { echo "sync-openapi: $SOURCE is not an OpenAPI 3 document" >&2; exit 1; }
version="$(awk '/^info:/{f=1} f && /^  version:/{gsub(/"/,"",$2); print $2; exit}' "$tmp")"

mkdir -p "$(dirname "$APP_COPY")" "$(dirname "$HELP_COPY")"
if [[ -f "$APP_COPY" ]] && cmp -s "$tmp" "$APP_COPY" && cmp -s "$tmp" "$HELP_COPY"; then
  echo "unchanged $version"
  exit 0
fi
cp "$tmp" "$APP_COPY"
cp "$tmp" "$HELP_COPY"
chmod 644 "$APP_COPY" "$HELP_COPY"
echo "updated $version"
