#!/bin/bash
# Builds build/LiveSnip.app (universal, ad-hoc signed) and a zip of it for releases.
# Pass "install" to also copy the app to ~/Applications and relaunch it.
set -euo pipefail
cd "$(dirname "$0")"

version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
app=build/LiveSnip.app

rm -rf build
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/"
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -module-name LiveSnip -target "$arch-apple-macos26.0" \
    Sources/*.swift -o "build/LiveSnip-$arch"
done
lipo -create build/LiveSnip-arm64 build/LiveSnip-x86_64 -output "$app/Contents/MacOS/LiveSnip"
rm build/LiveSnip-arm64 build/LiveSnip-x86_64
codesign --force --sign - "$app"
ditto -c -k --keepParent "$app" "build/LiveSnip-$version.zip"
echo "Built $app and build/LiveSnip-$version.zip"

if [[ "${1:-}" == "install" ]]; then
  pkill -x LiveSnip || true
  rm -rf ~/Applications/LiveSnip.app
  ditto "$app" ~/Applications/LiveSnip.app
  open ~/Applications/LiveSnip.app
  echo "Installed and launched ~/Applications/LiveSnip.app"
fi
