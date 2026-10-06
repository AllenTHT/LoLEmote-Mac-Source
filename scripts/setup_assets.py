#!/usr/bin/env python3
"""Local-only asset preparation. Requires the user's right to obtain/use assets.

--images needs only Python. --full additionally requires setup_tools.sh.
Download failures are reported, never replaced with invented media.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CATALOG = json.loads((ROOT / "research_assets/expansion-catalog.json").read_text())
VERSION = CATALOG["version"]
BASE = f"https://raw.communitydragon.org/{VERSION}/"
CACHE = ROOT / ".asset-cache/expansion"


def fetch(url, destination):
    if destination.exists():
        return
    request = urllib.request.Request(url, headers={"User-Agent": "LoLEmote-local-asset-setup"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".download")
    temporary.write_bytes(data)
    temporary.replace(destination)


def run(script, *arguments):
    print(f"\nPreparing: {script}", flush=True)
    return subprocess.run([sys.executable, str(ROOT / "scripts" / script), *arguments], cwd=ROOT).returncode == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--images", action="store_true", help="Static PNGs only (default)")
    modes.add_argument("--full", action="store_true", help="All 30 PNGs, original WAVs and two frame animations")
    parser.add_argument("--ids", nargs="+", type=int, help="Subset for image mode")
    parser.add_argument("--plan", action="store_true", help="Show sources/steps without network or file writes")
    options = parser.parse_args()
    known = {item["id"] for item in CATALOG["items"]}
    if options.ids and (set(options.ids) - known):
        parser.error(f"Unknown IDs: {sorted(set(options.ids) - known)}")
    if options.full and options.ids:
        parser.error("--full prepares the whole catalog; use --images --ids for a subset")
    if options.plan:
        print(f"Pinned version: {VERSION}; CommunityDragon is NOT an official Riot CDN.")
        print(f"Image index: {BASE}plugins/rcp-be-lol-game-data/global/default/v1/summoner-emotes.json")
        print("IDs:", sorted(options.ids or known))
        if options.full:
            print("Steps: images → indices/VFX graphs → audio banks → WAVs → textures → PNG frames → provenance")
            print("Official patch manifest:", json.loads((ROOT / "research_assets/audio-release.json").read_text())["download"]["url"])
        print("No license is granted by this script. Nothing has been downloaded or written.")
        return 0
    if options.full:
        try:
            import PIL
            import cdtb
            import xxhash
        except ImportError as error:
            raise RuntimeError(f"Missing full-mode dependency ({error}); run zsh scripts/setup_tools.sh, then use .venv/bin/python")
        for path in ("wwiser.pyz", "vgmstream-build/cli/vgmstream-cli"):
            if not (ROOT / ".asset-cache/tools" / path).is_file():
                raise RuntimeError(f"Missing tool: {path}; run zsh scripts/setup_tools.sh")
    manifest = ROOT / "Resources/asset-sources.json"
    if not manifest.exists():
        manifest.write_text("{}\n")
    arguments = ["--ids", *map(str, options.ids)] if options.ids else []
    images_ok = run("fetch_images.py", *arguments)
    failures = [] if images_ok else ["some images could not be prepared"]
    if options.full:
        try:
            CACHE.mkdir(parents=True, exist_ok=True)
            fetch(BASE + "plugins/rcp-be-lol-game-data/global/default/v1/summoner-emotes.json", CACHE / "summoner-emotes.json")
            fetch(BASE + "plugins/rcp-be-lol-game-data/global/zh_cn/v1/summoner-emotes.json", CACHE / "zh_cn.json")
            fetch(BASE + "game/loadouts/summoneremotes.cdtb.bin.json", CACHE / "summoneremotes.cdtb.bin.json")
            if not run("fetch_catalog_sources.py"):
                raise RuntimeError("Cannot prepare VFX/event graphs")
        except Exception as error:
            failures.append(f"full-mode indices/graphs: {error}")
        else:
            try:
                if not run("fetch_audio_banks.py") or not run("prepare_sounds.py", "--expansion"):
                    failures.append("original audio preparation failed")
            except Exception as error:
                failures.append(f"original audio: {error}")
            try:
                textures = json.loads((ROOT / "research_assets/animation-textures.json").read_text())
                texture_records = []
                for texture, relative in textures.items():
                    url = BASE + "game/" + texture.lower().removesuffix(".tex") + ".png"
                    fetch(url, ROOT / relative)
                    texture_records.append({"originalPath": texture, "url": url, "localFile": relative})
                (CACHE / "texture-sources.json").write_text(json.dumps(texture_records, indent=2) + "\n")
                if not run("prepare_animations.py"):
                    failures.append("animation frame preparation failed")
            except Exception as error:
                failures.append(f"animation textures/frames: {error}")
            if not run("publish_catalog.py"):
                failures.append("provenance update failed")
    report = {"mode": "full" if options.full else "images", "version": VERSION,
              "readyImages": [item["id"] for item in CATALOG["items"] if (ROOT / f"Resources/Emotes/{item['id']}.png").exists()],
              "failures": failures, "note": "Downloaded/generated assets are local, ignored by Git; availability is not a license."}
    report_path = ROOT / ".asset-cache/setup-report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"\nReady image files: {len(report['readyImages'])}/30. Report: {report_path}")
    for failure in failures:
        print("MISSING:", failure)
    print("Build with zsh scripts/build.sh. Missing sounds/animations fall back to static silent playback.")
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        raise SystemExit(f"Asset preparation failed: {error}. No upload was performed; existing local assets remain available.")
