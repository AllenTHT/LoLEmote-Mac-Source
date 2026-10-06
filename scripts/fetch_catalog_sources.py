#!/usr/bin/env python3
"""Cache the pinned originals and event graphs for the expansion catalog."""
import concurrent.futures
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CATALOG = json.loads((ROOT / "research_assets/expansion-catalog.json").read_text())
BASE = f"https://raw.communitydragon.org/{CATALOG['version']}/"
CACHE = ROOT / ".asset-cache/expansion"


def fnv1a(value):
    result = 2166136261
    for byte in value.lower().encode():
        result = ((result ^ byte) * 16777619) & 0xffffffff
    return result


def fetch(relative, destination):
    if not destination.exists():
        request = urllib.request.Request(BASE + relative.lower(), headers={"User-Agent": "Mozilla/5.0"})
        payload = urllib.request.urlopen(request, timeout=60).read()
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(payload)
    return destination


def graph(system):
    name = f"summoneremotes.{fnv1a(system):08x}.bin.json"
    path = fetch("game/loadouts/" + name, CACHE / name)
    entries = json.loads(path.read_text())
    for key, value in entries.items():
        if key.lower() == system.lower():
            return value, BASE + "game/loadouts/" + name
    raise ValueError(f"System not found: {system}")


def children(value):
    if isinstance(value, dict):
        if value.get("__type") == "VfxChildIdentifier" and "effect" in value:
            yield value["effect"]
        for child in value.values():
            yield from children(child)
    elif isinstance(value, list):
        for child in value:
            yield from children(child)


def main():
    index = {e["id"]: e for e in json.loads((CACHE / "summoner-emotes.json").read_text())}
    zh = {e["id"]: e for e in json.loads((CACHE / "zh_cn.json").read_text())}
    mapping = json.loads((CACHE / "summoneremotes.cdtb.bin.json").read_text())

    def process(item):
        entry = index[item["id"]]
        image_path = entry["inventoryIcon"].removeprefix("/lol-game-data/assets/").lower()
        image_url = "plugins/rcp-be-lol-game-data/global/default/" + image_path
        fetch(image_url, CACHE / "images" / f"{item['id']}.png")
        system = mapping[f"Loadouts/SummonerEmotes/{item['id']}"]["VfxSystem"]
        pending, seen, systems = [system], set(), []
        while pending:
            name = pending.pop()
            if name.lower() in seen:
                continue
            seen.add(name.lower())
            data, source = graph(name)
            systems.append({"name": name, "source": source, "data": data})
            pending.extend(children(data))
        return dict(item, gameName=entry["name"], officialTitle=zh[item["id"]]["name"],
                    imageURL=BASE + image_url, originalImagePath=entry["inventoryIcon"], systems=systems)

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(process, CATALOG["items"]))
    output = ROOT / "research_assets/expansion-sources.json"
    output.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    for item in results:
        events = [s["data"].get("soundOnCreateDefault") for s in item["systems"]]
        print(item["id"], item["title"], item["officialTitle"], [e for e in events if e])


if __name__ == "__main__":
    main()
