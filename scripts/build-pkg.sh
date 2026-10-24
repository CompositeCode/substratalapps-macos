#!/usr/bin/env bash
# Builds the distributable installer: build/pkg/SubstratalHub-<version>.pkg
#
#   scripts/build-pkg.sh                  # version from project.yml, build number 1
#   VERSION=0.2.0 BUILD_NUMBER=7 scripts/build-pkg.sh
#
# Release-configuration archive → app installed to /Applications by a
# component package → product archive (.pkg). How far it goes depends on what's
# available, so the same script serves a laptop and the release workflow:
#
#   APP_IDENTITY        "Developer ID Application: …"  signs the app (hardened runtime, timestamp).
#                       Unset → ad-hoc signed: runs locally, Gatekeeper warns elsewhere.
#   INSTALLER_IDENTITY  "Developer ID Installer: …"    signs the .pkg. Unset → unsigned .pkg.
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID
#                       App Store Connect API key → notarize and staple the .pkg (CI).
#   NOTARY_PROFILE      Or a notarytool Keychain profile (on a Mac:
#                       xcrun notarytool store-credentials <name>).
#                       Either needs both identities. Neither → not notarized.
#
# Prints the .pkg path last, and writes <pkg>.sha256 next to it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-$(awk '/MARKETING_VERSION:/ {gsub(/"/, "", $2); print $2; exit}' project.yml)}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_IDENTITY="${APP_IDENTITY:-}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-}"
PKG_ID="com.substratalapps.hub.pkg"
OUT="$ROOT/build/pkg"
ARCHIVE="$OUT/SubstratalHub.xcarchive"
PKG="$OUT/SubstratalHub-$VERSION.pkg"

step() { echo "==> $*"; }

rm -rf "$OUT"
mkdir -p "$OUT"

step "Generating the Xcode project"
xcodegen generate --quiet

signing=(CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
if [[ -n "$APP_IDENTITY" ]]; then
  signing+=("CODE_SIGN_IDENTITY=$APP_IDENTITY" "OTHER_CODE_SIGN_FLAGS=--timestamp")
  # The team comes from the identity, e.g. "Developer ID Application: Name (TEAMID)".
  team="$(sed -n 's/.*(\([A-Z0-9]\{10\}\))$/\1/p' <<<"$APP_IDENTITY")"
  [[ -n "$team" ]] && signing+=("DEVELOPMENT_TEAM=$team")
  step "Archiving $VERSION ($BUILD_NUMBER), signed by $APP_IDENTITY"
else
  signing+=("CODE_SIGN_IDENTITY=-")
  step "Archiving $VERSION ($BUILD_NUMBER), ad-hoc signed (no APP_IDENTITY)"
fi

log="$OUT/archive.log"
if ! xcodebuild archive \
    -project SubstratalHub.xcodeproj -scheme SubstratalHub -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" \
    -derivedDataPath "$ROOT/build/DerivedData-Release" \
    -skipPackagePluginValidation -skipMacroValidation \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    "${signing[@]}" >"$log" 2>&1; then
  grep -E 'error:' "$log" | sort -u >&2 || true
  echo "build-pkg: archive failed; full log at $log" >&2
  exit 1
fi

APP="$ARCHIVE/Products/Applications/Substratal Hub.app"
[[ -d "$APP" ]] || { echo "build-pkg: $APP not found in the archive" >&2; exit 1; }
codesign --verify --strict --deep "$APP"
step "App signature: $(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1 || true)$( [[ -z "$APP_IDENTITY" ]] && echo 'ad-hoc')"

step "Building the component package"
root="$OUT/root"
mkdir -p "$root"
ditto "$APP" "$root/Substratal Hub.app"
plist="$OUT/component.plist"
pkgbuild --analyze --root "$root" "$plist" >/dev/null
# Always install to /Applications, never "update" a copy found elsewhere.
plutil -replace 0.BundleIsRelocatable -bool NO "$plist"
pkgbuild --root "$root" --component-plist "$plist" --install-location /Applications \
  --identifier "$PKG_ID" --version "$VERSION" "$OUT/component.pkg" >/dev/null

step "Building the installer"
dist="$OUT/distribution.xml"
productbuild --synthesize --package "$OUT/component.pkg" "$dist" >/dev/null
# Title, and the minimum macOS the app supports.
sed -i '' "s#<installer-gui-script minSpecVersion=\"[0-9]*\">#&\n    <title>Substratal Hub $VERSION</title>\n    <allowed-os-versions><os-version min=\"15.0\"/></allowed-os-versions>#" "$dist"
sign=()
[[ -n "$INSTALLER_IDENTITY" ]] && sign=(--sign "$INSTALLER_IDENTITY" --timestamp)
productbuild --distribution "$dist" --package-path "$OUT" ${sign[@]+"${sign[@]}"} "$PKG" >/dev/null

notary=()
if [[ -n "${NOTARY_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
  notary=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
elif [[ -n "${NOTARY_PROFILE:-}" ]]; then
  notary=(--keychain-profile "$NOTARY_PROFILE")
fi

if [[ ${#notary[@]} -gt 0 ]]; then
  [[ -n "$APP_IDENTITY" && -n "$INSTALLER_IDENTITY" ]] || { echo "build-pkg: notarizing needs APP_IDENTITY and INSTALLER_IDENTITY" >&2; exit 1; }
  step "Notarizing (this waits for Apple)"
  xcrun notarytool submit "$PKG" "${notary[@]}" --wait
  xcrun stapler staple "$PKG"
  spctl --assess --type install --verbose "$PKG"
  status="signed, notarized and stapled"
elif [[ -n "$INSTALLER_IDENTITY" ]]; then
  pkgutil --check-signature "$PKG" | head -3
  status="signed, not notarized"
else
  status="unsigned (for testing: right-click → Open, or allow it in System Settings → Privacy & Security)"
fi

rm -rf "$root" "$OUT/component.pkg" "$plist" "$dist"
(cd "$OUT" && shasum -a 256 "$(basename "$PKG")" >"$(basename "$PKG").sha256")
step "Built $(basename "$PKG"): $status"
echo "$PKG"
