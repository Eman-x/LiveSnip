#!/bin/bash
# Builds build/LiveSnip.app (universal) and a zip of it for releases.
# Pass "install" to also copy the app to ~/Applications and relaunch it.
#
# Signs with the self-signed "LiveSnip Signing" certificate when it's in your keychain. Keeping the
# same certificate lets macOS keep LiveSnip's Screen Recording permission across updates, and the
# built-in updater only installs versions signed with it. Without it, the build is ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")"

version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
app=build/LiveSnip.app

rm -rf build
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/"
mkdir -p "$app/Contents/Resources"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -module-name LiveSnip -target "$arch-apple-macos26.0" \
    Sources/*.swift -o "build/LiveSnip-$arch"
done
lipo -create build/LiveSnip-arm64 build/LiveSnip-x86_64 -output "$app/Contents/MacOS/LiveSnip"
rm build/LiveSnip-arm64 build/LiveSnip-x86_64
identity="LiveSnip Signing"
if security find-identity -p codesigning | grep -q "\"$identity\""; then
  codesign --force --sign "$identity" "$app"
  echo "Signed with \"$identity\" ($(security find-certificate -c "$identity" -Z | awk '/SHA-1/ {print $3}'))"
else
  echo "warning: no \"$identity\" certificate in your keychain, so this build is ad-hoc signed and can't update itself" >&2
  codesign --force --sign - "$app"
fi
ditto -c -k --keepParent "$app" "build/LiveSnip-$version.zip"
echo "Built $app and build/LiveSnip-$version.zip"

if [[ "${1:-}" == "install" ]]; then
  pkill -x LiveSnip || true
  rm -rf ~/Applications/LiveSnip.app
  ditto "$app" ~/Applications/LiveSnip.app
  open ~/Applications/LiveSnip.app
  echo "Installed and launched ~/Applications/LiveSnip.app"
fi
