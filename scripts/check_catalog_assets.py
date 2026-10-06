#!/usr/bin/env python3
"""Verify the packaged expansion against the requested catalog and provenance."""
from array import array
import json
from pathlib import Path
import wave

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    planned = json.loads((ROOT / "research_assets/expansion-catalog.json").read_text())
    resources = ROOT / "dist/LoLEmote.app/Contents/Resources"
    catalog = json.loads((resources / "emotes.json").read_text())
    manifest = json.loads((resources / "asset-sources.json").read_text())
    source = {i["id"]: i for i in json.loads((ROOT / "research_assets/expansion-sources.json").read_text())}
    assert len(catalog) == len({i["id"] for i in catalog})
    assert {i["id"] for i in catalog} == {i["id"] for i in planned["items"]}
    assert {i["id"] for i in manifest["audio"]["files"]} == {i["id"] for i in catalog}
    records = []
    for item in catalog:
        assert item["gameName"] == source[item["id"]]["gameName"]
        with Image.open(resources / item["image"]) as image:
            image.load()
            assert image.mode == "RGBA" and image.getchannel("A").getextrema()[0] == 0
            dimensions = list(image.size)
        with wave.open(str(resources / item["sound"])) as audio:
            assert audio.getsampwidth() == 2 and audio.getframerate() == 44100
            samples = array("h", audio.readframes(audio.getnframes()))
            peak = max(abs(sample) for sample in samples)
            assert 0 < peak < 32767
            duration = audio.getnframes()/audio.getframerate()
        frames = 0
        if item.get("animation"):
            sequence = json.loads((resources / item["animation"]).read_text())
            times = [frame["time"] for frame in sequence["frames"]]
            assert times[0] == 0 and all(a < b for a, b in zip(times, times[1:]))
            assert times[-1] < sequence["duration"]
            for frame in sequence["frames"]:
                with Image.open(resources / frame["image"]) as image:
                    image.load()
                    assert image.mode == "RGBA" and image.size == (768, 768)
                    assert image.getchannel("A").getextrema()[0] == 0
                assert (resources / frame["image"]).read_bytes() == (ROOT / "Resources" / frame["image"]).read_bytes()
                frames += 1
        records.append(dict(id=item["id"], title=item["title"], dimensions=dimensions,
                            audioDuration=duration, peakPCM16=peak, animationFrames=frames))
    unresolved = []
    indices = [(planned["version"], ROOT / ".asset-cache/expansion/summoner-emotes.json")]
    legacy = ROOT / ".asset-cache/emotes-15.24.json"
    if legacy.exists():
        indices.append(("15.24", legacy))
    for version, path in indices:
        entries = json.loads(path.read_text())
        candidates = [e for e in entries if 31 in e.get("taggedChampionsIds", []) or
                      any(word in (e.get("name", "")+" "+e.get("inventoryIcon", "")).lower()
                          for word in ["chogath", "cho'gath", "cho’gath"])]
        unresolved.append(dict(version=version, searchedEntries=len(entries), choGathCandidates=candidates))
    report = dict(status="passed", packagedEmotes=len(catalog), animatedEmotes=sum(bool(i.get("animation")) for i in catalog),
                  decodedAnimationFrames=sum(r["animationFrames"] for r in records), records=records,
                  unresolved=planned["unresolved"], choGathIndexEvidence=unresolved)
    target = ROOT / "Verification/Expansion/catalog-assets.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"PASS {len(catalog)} original images and sounds, {report['decodedAnimationFrames']} packaged transparent animation frames.")


if __name__ == "__main__":
    main()
