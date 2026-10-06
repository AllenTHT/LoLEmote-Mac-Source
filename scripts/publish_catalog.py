#!/usr/bin/env python3
"""Update local provenance after preparation, without rewriting public configuration."""
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def main():
    path = ROOT / "Resources/asset-sources.json"
    manifest = json.loads(path.read_text()) if path.exists() else {}
    sources_path = ROOT / "research_assets/expansion-sources.json"
    sources = json.loads(sources_path.read_text()) if sources_path.exists() else []
    for item in sources:
        image = ROOT / f".asset-cache/expansion/images/{item['id']}.png"
        target = ROOT / f"Resources/Emotes/{item['id']}.png"
        if image.exists() and not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(image, target)
    animations = ROOT / "research_assets/animation-build.json"
    if animations.exists():
        manifest["animations"] = json.loads(animations.read_text())
    manifest["gameSources"] = [{"id": item["id"], "imageURL": item["imageURL"],
                                "systems": [system["source"] for system in item["systems"]]} for item in sources]
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print("Updated local provenance. Resources/emotes.json was preserved.")


if __name__ == "__main__":
    main()
