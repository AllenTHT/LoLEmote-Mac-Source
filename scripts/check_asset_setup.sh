#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/asset-setup
python3 scripts/make_test_assets.py .build/asset-setup
ARCH="$(uname -m)"
MODULES="$PWD/.build/$ARCH-apple-macosx/release"
swiftc -module-cache-path "$PWD/.build/module-cache" -target "$ARCH-apple-macosx13.0" \
    -I "$MODULES/Modules" "$MODULES"/EmoteCore.build/*.o \
    Tests/AppLifecycleChecks/GlobalInputStub.swift \
    Sources/LoLEmote/AppModel.swift Sources/LoLEmote/Assets.swift \
    Sources/LoLEmote/Settings.swift Sources/LoLEmote/Overlay.swift Sources/LoLEmote/ControlView.swift \
    Tests/AssetSetupChecks/main.swift -o .build/asset-setup/AssetSetupChecks
for mode in empty image corrupt complete invalid; do
    LOLEMOTE_ASSET_ROOT="$PWD/.build/asset-setup/$mode" \
        .build/asset-setup/AssetSetupChecks "$mode" "$PWD/.build/asset-setup/$mode-ui.png"
done
