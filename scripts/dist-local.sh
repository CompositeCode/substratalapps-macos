#!/usr/bin/env bash
# Builds a distributable Substratal Hub installer on this Mac.
#
#   scripts/dist-local.sh                 # version from project.yml
#   scripts/dist-local.sh 0.2.0           # a specific version (build number: BUILD_NUMBER or a timestamp)
#   scripts/dist-local.sh --unsigned      # skip signing even if certificates are installed
#   scripts/dist-local.sh --open          # show the .pkg in Finder when done
#
# Finds your signing setup and uses as much of it as is there:
#   - "Developer ID Application" and "Developer ID Installer" certificates in your
#     Keychain sign the app and the .pkg. Override with APP_IDENTITY / INSTALLER_IDENTITY.
#   - A notarytool Keychain profile notarizes and staples it, so it opens on any Mac
#     without warnings. Create one once with:
#       xcrun notarytool store-credentials substratal-notary --team-id <TEAMID> --apple-id <you@example.com>
#     The profile name defaults to substratal-notary; override with NOTARY_PROFILE.
# With none of that, you get an unsigned .pkg that's fine for testing on Macs you control.
#
# The build itself is scripts/build-pkg.sh; this wraps it for a person at a Mac.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

unsigned=false
reveal=false
version=""
for arg in "$@"; do
  case "$arg" in
    --unsigned) unsigned=true ;;
    --open) reveal=true ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "dist-local: unknown option $arg (try --help)" >&2; exit 1 ;;
    *) version="$arg" ;;
  esac
done

command -v xcodegen >/dev/null || { echo "dist-local: XcodeGen is required: brew install xcodegen" >&2; exit 1; }

[[ -n "$version" ]] && export VERSION="$version"
export BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

find_identity() { # $1 = certificate kind, e.g. "Developer ID Application"
  security find-identity -v 2>/dev/null | sed -n "s/.*\"\($1: .*\)\"/\1/p" | head -1
}

if $unsigned; then
  export APP_IDENTITY="" INSTALLER_IDENTITY=""
else
  export APP_IDENTITY="${APP_IDENTITY:-$(find_identity "Developer ID Application")}"
  export INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-$(find_identity "Developer ID Installer")}"
fi

profile="${NOTARY_PROFILE:-substratal-notary}"
unset NOTARY_PROFILE
if [[ -n "$APP_IDENTITY" && -n "$INSTALLER_IDENTITY" ]]; then
  # Only notarize with a profile that actually exists.
  if xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1; then
    export NOTARY_PROFILE="$profile"
  fi
fi

echo "Substratal Hub installer"
echo "  App signing:       ${APP_IDENTITY:-none (ad-hoc)}"
echo "  Installer signing: ${INSTALLER_IDENTITY:-none (unsigned .pkg)}"
echo "  Notarization:      ${NOTARY_PROFILE:-none}"
if [[ -z "$APP_IDENTITY" || -z "$INSTALLER_IDENTITY" ]] && ! $unsigned; then
  echo "  (No Developer ID certificates found in your Keychain, so this build is for testing only.)"
fi
echo

pkg="$(scripts/build-pkg.sh | tee /dev/stderr | tail -1)"

echo
echo "Checks"
echo "  Package signature: $(pkgutil --check-signature "$pkg" 2>/dev/null | sed -n 's/^   Status: //p' | head -1 || true)"
if spctl --assess --type install "$pkg" >/dev/null 2>&1; then
  echo "  Gatekeeper:        accepted (opens on any Mac)"
else
  echo "  Gatekeeper:        not accepted; people must right-click → Open, or allow it in System Settings → Privacy & Security"
fi
echo "  SHA-256:           $(cut -d' ' -f1 "$pkg.sha256")"
echo
echo "Installer: $pkg"
echo "Install:   sudo installer -pkg \"$pkg\" -target /   (or double-click it)"

$reveal && open -R "$pkg"
exit 0
