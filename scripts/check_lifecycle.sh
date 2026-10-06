#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/lifecycle
swiftc -module-cache-path "$PWD/.build/module-cache" -target arm64-apple-macosx13.0 \
 -I "$PWD/.build/arm64-apple-macosx/release/Modules" \
 "$PWD"/.build/arm64-apple-macosx/release/EmoteCore.build/*.o \
 "$PWD/Tests/AppLifecycleChecks/GlobalInputStub.swift" \
 "$PWD/Sources/LoLEmote/AppModel.swift" "$PWD/Sources/LoLEmote/Assets.swift" \
 "$PWD/Sources/LoLEmote/Settings.swift" "$PWD/Sources/LoLEmote/Overlay.swift" \
 "$PWD/Tests/AppLifecycleChecks/main.swift" -o .build/lifecycle/EmoteLifecycleChecks
.build/lifecycle/EmoteLifecycleChecks
