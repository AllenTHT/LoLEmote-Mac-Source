#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift run --disable-sandbox --cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security" EmoteCoreChecks
if [[ ! -x dist/LoLEmote.app/Contents/MacOS/LoLEmote ]]; then
    print 'Build first: zsh scripts/build.sh' >&2
    exit 1
fi
dist/LoLEmote.app/Contents/MacOS/LoLEmote --self-check
zsh scripts/check_asset_setup.sh
python3 scripts/check_public_source.py
