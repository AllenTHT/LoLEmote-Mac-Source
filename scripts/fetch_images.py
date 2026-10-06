#!/usr/bin/env python3
"""Prepare selected catalog PNGs locally; never uploads assets."""
import argparse
import concurrent.futures
import json
from pathlib import Path
import struct
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CATALOG = json.loads((ROOT / "research_assets/expansion-catalog.json").read_text())
VERSION = CATALOG["version"]
BASE = f"https://raw.communitydragon.org/{VERSION}/plugins/rcp-be-lol-game-data/global/default/"
INDEX_URL = BASE + "v1/summoner-emotes.json"


def read(url):
    request = urllib.request.Request(url, headers={"User-Agent": "LoLEmote-local-asset-setup"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ids", nargs="+", type=int, help="Selected catalog IDs; default: all 30")
    parser.add_argument("--force", action="store_true", help="Replace existing local PNGs")
    options = parser.parse_args()
    wanted = set(options.ids) if options.ids else {item["id"] for item in CATALOG["items"]}
    unknown = wanted - {item["id"] for item in CATALOG["items"]}
    if unknown:
        parser.error(f"Unknown catalog IDs: {sorted(unknown)}")
    cache = ROOT / ".asset-cache"
    cache.mkdir(exist_ok=True)
    index_path = cache / f"emotes-{VERSION}.json"
    if not index_path.exists():
        prepared = cache / "expansion/summoner-emotes.json"
        index_path.write_bytes(prepared.read_bytes() if prepared.exists() else read(INDEX_URL))
    entries = {entry["id"]: entry for entry in json.loads(index_path.read_bytes())}
    images = ROOT / "Resources" / "Emotes"
    images.mkdir(parents=True, exist_ok=True)

    def fetch(item):
        emote_id = item["id"]
        entry = entries[emote_id]
        original_path = entry["inventoryIcon"]
        url = BASE + original_path.removeprefix("/lol-game-data/assets/").lower()
        destination = images / f"{emote_id}.png"
        existing = destination.exists() and not options.force
        payload = destination.read_bytes() if existing else read(url)
        if len(payload) < 26 or payload[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Not a PNG: {emote_id}")
        width, height, depth, color = struct.unpack(">IIBB", payload[16:26])
        if min(width, height) < 64 or (depth, color) != (8, 6):
            raise ValueError(f"Expected an 8-bit RGBA PNG, at least 64px: {emote_id}")
        if not existing:
            temporary = destination.with_suffix(".download")
            temporary.write_bytes(payload)
            temporary.replace(destination)
        return {"id": emote_id, "title": item["title"], "gameName": entry["name"],
                "file": f"Emotes/{emote_id}.png", "url": None if existing else url,
                "source": "existing local file; origin unverified" if existing else "CommunityDragon community mirror",
                "originalPath": original_path, "width": width, "height": height}

    records, failures = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        pending = {pool.submit(fetch, item): item for item in CATALOG["items"] if item["id"] in wanted}
        for future in concurrent.futures.as_completed(pending):
            item = pending[future]
            try:
                records.append(future.result())
                print(f"Ready: {item['id']} {item['title']}")
            except Exception as error:
                failures.append({"id": item["id"], "error": str(error)})
                print(f"MISSING: {item['id']} {item['title']}: {error}")
    manifest_path = ROOT / "Resources/asset-sources.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    merged = {r["id"]: r for r in manifest.get("images", [])}
    merged.update({r["id"]: r for r in records})
    manifest.update(imageVersion=VERSION, imageSource="CommunityDragon is a community mirror, not an official Riot CDN",
                    imageIndex=INDEX_URL, images=sorted(merged.values(), key=lambda r: r["id"]), imageFailures=failures)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Ready: {len(records)} selected PNGs; missing: {len(failures)}. Assets remain local.")
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        raise SystemExit(f"Image preparation failed: {error}. Existing files were retained; try manual configuration.")
