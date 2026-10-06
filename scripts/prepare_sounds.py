#!/usr/bin/env python3
"""Reproduce WAVs from the official banks and inspected Wwise event graph."""
import argparse
from array import array
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
BANKS = ROOT / ".asset-cache/audio-banks"
TOOLS = ROOT / ".asset-cache/tools"


def wwise_id(name):
    value = 2166136261
    for byte in name.lower().encode():
        value = ((value * 16777619) & 0xffffffff) ^ byte
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--expansion", action="store_true")
    options = parser.parse_args()
    if options.expansion:
        sources = json.loads((ROOT / "research_assets/expansion-sources.json").read_text())
        targets = []
        for item in sources:
            sound_events = [{"event": system["data"]["soundOnCreateDefault"],
                             "eventId": wwise_id(system["data"]["soundOnCreateDefault"]),
                             "source": system["source"]}
                            for system in item["systems"] if system["data"].get("soundOnCreateDefault")]
            if not sound_events:
                raise ValueError(f"No sound event for {item['id']}")
            # Some emotes have only a template sound. Preserve that actual graph.
            targets.append(dict(id=item["id"], name=item["title"],
                                source=item["systems"][0]["source"],
                                events=list({e["eventId"]: e for e in sound_events}.values())))
        (ROOT / "research_assets/expansion-events.json").write_text(json.dumps(targets, ensure_ascii=False, indent=2) + "\n")
    else:
        targets = json.loads((ROOT / "research_assets/target-events.json").read_text())
        for target in targets:
            target["events"] = [dict(eventId=target["eventId"])] + target["childSoundEvents"]
    ids = sorted({event["eventId"] for target in targets for event in target["events"]})
    subprocess.run([sys.executable, str(TOOLS / "wwiser.pyz"), "init.bnk", "misc_emotes_sfx_events.bnk",
                    "misc_emotes_sfx_audio.bnk", "-d", "none", "-g", "-go", "txtp", "-gw", "../wem",
                    "-gf", *map(str, ids), "-gwd", "-gv", "0dB"], cwd=BANKS, check=True)
    # wwiser logs 'ignored' for zero dB, but its parser sets volume_master_auto=False;
    # explicitly verify the resulting authored attenuation is retained below.
    events = {}
    for path in (BANKS / "txtp").glob("*.txtp"):
        content = path.read_text()
        event_id = int(re.search(r"CAkEvent\[\d+\] (\d+)", content)[1])
        if event_id not in ids:
            continue
        assert "master volume: auto" not in content
        if event_id in events:
            raise ValueError(f"Multiple event variants need explicit handling: {event_id}")
        events[event_id] = {"path": path, "content": content,
                            "media": re.findall(r"(\d+)\.wem", content)}
    assert set(events) == set(ids)
    wanted = {media for e in events.values() for media in e["media"]}
    wpk = (BANKS / "misc_emotes_sfx_audio.wpk").read_bytes()
    assert wpk[:4] == b"r3d2"
    (BANKS / "wem").mkdir(exist_ok=True)
    for index in range(struct.unpack_from("<I", wpk, 8)[0]):
        pointer = struct.unpack_from("<I", wpk, 12+4*index)[0]
        offset, size, chars = struct.unpack_from("<III", wpk, pointer)
        name = wpk[pointer+12:pointer+12+chars*2].decode("utf-16le")
        if name.removesuffix(".wem") in wanted:
            payload = wpk[offset:offset+size]
            assert payload[:4] == b"RIFF" and len(payload) == size
            (BANKS / "wem" / name).write_bytes(payload)
    decoded = BANKS / "decoded"
    decoded.mkdir(exist_ok=True)
    evidence = ROOT / "research_assets/audio-events"
    evidence.mkdir(parents=True, exist_ok=True)
    for event_id, event in events.items():
        output = decoded / f"{event_id}.wav"
        subprocess.run([str(TOOLS / "vgmstream-build/cli/vgmstream-cli"), "-i", "-o", str(output),
                        str(event["path"])], check=True, stdout=subprocess.DEVNULL)
        with wave.open(str(output)) as wav:
            assert wav.getnchannels() in (1, 2) and (wav.getsampwidth(), wav.getframerate()) == (2, 44100)
            event["channels"] = wav.getnchannels()
            event["samples"] = array("h", wav.readframes(wav.getnframes()))
        shutil.copyfile(event["path"], evidence / f"{event_id}.txtp")
    # Verify none of the requested SFX events has an additional Chinese VO event.
    vo = (BANKS / "misc_emotes_vo_events.bnk").read_bytes()
    at = vo.index(b"HIRC") + 8
    count = struct.unpack_from("<I", vo, at)[0]; at += 4
    voice_events = []
    for _ in range(count):
        kind, length = struct.unpack_from("<BI", vo, at)
        if kind == 4:
            voice_events.append(struct.unpack_from("<I", vo, at+5)[0])
        at += length + 5
    assert not set(ids).intersection(voice_events)
    sounds = ROOT / "Resources/Sounds"
    sounds.mkdir(parents=True, exist_ok=True)
    records = []
    for target in targets:
        event_ids = [e["eventId"] for e in target["events"]]
        channels = max(events[e]["channels"] for e in event_ids)
        layers = [events[e]["samples"] if events[e]["channels"] == channels else
                  array("h", (sample for sample in events[e]["samples"] for _ in range(channels)))
                  for e in event_ids]
        mixed = [sum(layer[i] if i < len(layer) else 0 for layer in layers)
                 for i in range(max(map(len, layers)))]
        peak = max(abs(s) for s in mixed)
        assert 50 < peak < 32767, (target["id"], peak)
        output = sounds / f"{target['id']}.wav"
        with wave.open(str(output), "wb") as wav:
            wav.setparams((channels, 2, 44100, 0, "NONE", "not compressed"))
            wav.writeframes(array("h", mixed).tobytes())
        records.append({"id": target["id"], "file": f"Sounds/{output.name}",
                        "events": event_ids, "mediaIDs": [events[e]["media"] for e in event_ids],
                        "duration": len(mixed)/44100/channels, "channels": channels, "peakPCM16": peak,
                        "mappingSource": target["source"].replace("15.24", "16.19")})
        print(f"{target['name']}: {len(mixed)/44100/channels:.3f}s, peak {peak}/32767, {event_ids}")
    manifest_path = ROOT / "Resources/asset-sources.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["audio"] = {"version": "16.19.8230722", "source": json.loads((BANKS / "source.json").read_text()),
                         "mix": "Original event attenuation and delays; default Wwise bus state; no peak normalization. Dedicated and template layers start together.",
                         "voiceCheck": {"locale": "zh_CN", "additionalEventsForTheseEmotes": []},
                         "files": records}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
