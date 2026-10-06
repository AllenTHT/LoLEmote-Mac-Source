#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/module-cache .build/cache .build/config .build/security
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build -c release --product LoLEmote --disable-sandbox --cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security"
APP="$PWD/dist/LoLEmote.app"
RESOURCE_SOURCE="${LOLEMOTE_ASSET_ROOT:-$PWD/Resources}"
# Recreate only this generated bundle, so removed media cannot survive a rebuild.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/LoLEmote "$APP/Contents/MacOS/LoLEmote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$RESOURCE_SOURCE/emotes.json" "$APP/Contents/Resources/"
for directory in Emotes Sounds Animations; do
    if [[ -d "$RESOURCE_SOURCE/$directory" ]]; then
        cp -R "$RESOURCE_SOURCE/$directory" "$APP/Contents/Resources/"
    fi
done
if [[ -f "$RESOURCE_SOURCE/asset-sources.json" ]]; then
    cp "$RESOURCE_SOURCE/asset-sources.json" "$APP/Contents/Resources/"
fi
swift scripts/make_icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier local.allentu.LoLEmote "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/LoLEmote" --check-assets
print "Built: $APP"
