#!/bin/sh
# Builds an unsigned Rupor.ipa (sign it yourself with AltStore / Sideloadly / TrollStore etc.)
set -e
cd "$(dirname "$0")"
xcodegen generate -q
xcodebuild -project Rupor.xcodeproj -scheme Rupor -configuration Release -sdk iphoneos \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build -quiet
rm -rf build/Payload Rupor.ipa
mkdir -p build/Payload
cp -R build/Build/Products/Release-iphoneos/Rupor.app build/Payload/
(cd build && zip -qry ../Rupor.ipa Payload)
echo "Done: $(pwd)/Rupor.ipa"
