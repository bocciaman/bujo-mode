#!/bin/bash
# Build BuJoMode and assemble a proper .app bundle (needed for a menu-bar agent
# and for Accessibility permission to stick to a stable code identity).
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP_NAME="BuJo Mode"
EXECUTABLE="BuJoMode"
BUNDLE="build/${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${EXECUTABLE}"

echo "==> Assembling ${BUNDLE}"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${BUNDLE}/Contents/MacOS/${EXECUTABLE}"
cp "Resources/Info.plist" "${BUNDLE}/Contents/Info.plist"

# App icon (Finder / Launchpad / Spotlight), if present.
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"
    echo "==> Bundled app icon"
fi

# Sign with a STABLE identity so Accessibility permission survives rebuilds.
# TCC keys the grant to the code signature's identity; an ad-hoc signature has
# no stable identity, so every rebuild would look like a new app and re-prompt.
# Order of preference: $SIGN_IDENTITY env var, then a Developer ID / Apple
# Development cert from the keychain, then ad-hoc as a last resort.
IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "${IDENTITY}" ]; then
    IDENTITY="$(security find-identity -v -p codesigning \
        | awk -F'"' '/Developer ID Application|Apple Development/ {print $2; exit}')"
fi
if [ -z "${IDENTITY}" ]; then
    echo "!! No Developer ID / Apple Development identity found."
    echo "!! Falling back to ad-hoc — Accessibility permission will reset on every rebuild."
    IDENTITY="-"
fi

echo "==> Code signing as: ${IDENTITY}"
codesign --force --sign "${IDENTITY}" "${BUNDLE}"

echo "==> Done: ${BUNDLE}"

# Optional in-place install to /Applications.
#   ./build_app.sh release install   (or:  INSTALL=1 ./build_app.sh)
# IMPORTANT: we overwrite the installed bundle in place (ditto) rather than
# deleting it first. Deleting an app removes its Accessibility grant from macOS,
# which forces a re-authorization every time. Overwriting keeps the grant,
# because it's keyed to the (stable) code-signing identity, not the files.
if [ "${2:-}" = "install" ] || [ "${INSTALL:-}" = "1" ]; then
    DEST="/Applications"
    [ -w "${DEST}" ] || DEST="${HOME}/Applications"
    mkdir -p "${DEST}"
    echo "==> Installing in place to ${DEST}/${APP_NAME}.app"
    osascript -e "quit app \"${APP_NAME}\"" 2>/dev/null || true
    sleep 1
    ditto "${BUNDLE}" "${DEST}/${APP_NAME}.app"
    echo "==> Installed (Accessibility grant preserved). Launch it:"
    echo "    open \"${DEST}/${APP_NAME}.app\""
else
    echo "    Run it:   open \"${BUNDLE}\""
    echo "    Install:  ./build_app.sh ${CONFIG} install"
fi
