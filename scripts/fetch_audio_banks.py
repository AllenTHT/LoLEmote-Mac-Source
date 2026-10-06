#!/usr/bin/env python3
"""Read only the required WAD entries from Riot's public patch bundles.

Requires the project asset-maintenance environment (cdtb). Does not install or
launch the game. The selected release is cached for reproducibility.
"""
import bisect
import io
import json
from pathlib import Path
import struct
import urllib.request

from cdtb.patcher import PatcherManifest
from cdtb.tools import zstd_decompress
from cdtb.wad import WadFileHeader
from xxhash import xxh64_intdigest

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".asset-cache" / "patch"
OUTPUT = ROOT / ".asset-cache" / "audio-banks"
RELEASE_FILE = ROOT / "research_assets/audio-release.json"


def read_url(url, start=None, size=None):
    headers = {"User-Agent": "Mozilla/5.0"}
    if start is not None:
        headers["Range"] = f"bytes={start}-{start+size-1}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=90) as response:
        if start is None:
            return response.read()
        if response.status == 206:
            result = response.read()
            if len(result) != size:
                raise ValueError("Incomplete range response")
            return result
        # Some CDN nodes serve the entire bundle. Retain only the requested part.
        result = response.read()
        if len(result) < start + size:
            raise ValueError("Incomplete bundle response")
        return result[start:start+size]


class RemoteFile:
    def __init__(self, file, base):
        self.file, self.base, self.position = file, base, 0
        self.starts = []
        total = 0
        for chunk in file.chunks:
            self.starts.append(total)
            total += chunk.target_size
        self.memory = {}

    def seek(self, position, whence=0):
        self.position = position if whence == 0 else self.position + position

    def read(self, count):
        end = min(self.position + count, self.file.size)
        result = bytearray()
        while self.position < end:
            index = bisect.bisect_right(self.starts, self.position) - 1
            chunk = self.file.chunks[index]
            if index not in self.memory:
                path = CACHE / "chunks" / f"{chunk.chunk_id:016X}"
                if not path.exists():
                    url = self.base + f"bundles/{chunk.bundle.bundle_id:016X}.bundle"
                    compressed = read_url(url, chunk.offset, chunk.size)
                    decoded = zstd_decompress(compressed)
                    if len(decoded) != chunk.target_size:
                        raise ValueError("Unexpected decoded chunk size")
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(decoded)
                self.memory[index] = path.read_bytes()
            offset = self.position - self.starts[index]
            take = min(end - self.position, chunk.target_size - offset)
            result.extend(self.memory[index][offset:offset+take])
            self.position += take
        return bytes(result)


def headers(remote):
    remote.seek(0)
    magic, major, minor = struct.unpack("<2sBB", remote.read(4))
    if magic != b"RW" or major != 3:
        raise ValueError(f"Unsupported WAD: {magic}, {major}.{minor}")
    remote.seek(268)
    count, = struct.unpack("<I", remote.read(4))
    table = io.BytesIO(remote.read(count * 32))
    entries = {}
    for _ in range(count):
        values = struct.unpack("<QIIIBBHQ", table.read(32))
        path_hash, offset, compressed, size, kind, hi, lo, checksum = values
        subchunk = lo + (hi << 16) if minor > 3 else lo
        entry = WadFileHeader(path_hash, offset, compressed, size, kind, False, subchunk, checksum)
        entries[path_hash] = entry
    return entries


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    release = json.loads(RELEASE_FILE.read_text())
    manifest_url = release["download"]["url"]
    manifest_path = CACHE / "game.manifest"
    if not manifest_path.exists():
        manifest_path.write_bytes(read_url(manifest_url))
    manifest = PatcherManifest(str(manifest_path))
    base = manifest_url.split("releases/")[0]
    original_paths = [
        "assets/sounds/wwise2016/sfx/shared/misc_emotes_sfx_audio.wpk",
        "assets/sounds/wwise2016/sfx/shared/misc_emotes_sfx_audio.bnk",
        "assets/sounds/wwise2016/sfx/shared/misc_emotes_sfx_events.bnk",
        "data/maps/shipping/common/common.bin",
        "assets/sounds/wwise2016/sfx/shared/init.bnk",
        # Localized WADs retain en_us logical paths even for Chinese payloads.
        "assets/sounds/wwise2016/vo/en_us/shared/misc_emotes_vo_events.bnk",
    ]
    records = []
    for wad_path in ["DATA/FINAL/Maps/Shipping/Common.wad.client", "DATA/FINAL/Maps/Shipping/Common.zh_CN.wad.client", "DATA/FINAL/Global.wad.client"]:
        remote = RemoteFile(manifest.files[wad_path], base)
        entries = headers(remote)
        print(f"Inspecting {wad_path}: {len(entries)} entries", flush=True)
        for original_path in original_paths:
            entry = entries.get(xxh64_intdigest(original_path.encode()))
            if not entry:
                continue
            destination = OUTPUT / Path(original_path).name
            if not destination.exists():
                payload = entry.read_data(remote)
                if payload is None or len(payload) != entry.size:
                    raise ValueError(f"Unable to extract {original_path}")
                destination.write_bytes(payload)
            print(f"Saved {destination.name}: {destination.stat().st_size} bytes", flush=True)
            records.append({"originalPath": original_path, "wad": wad_path, "file": destination.name,
                            "size": entry.size, "pathHash": f"{entry.path_hash:016x}"})
        if len(records) == len(original_paths):
            break
    result = {"release": release, "manifestURL": manifest_url, "files": records}
    (OUTPUT / "source.json").write_text(json.dumps(result, indent=2) + "\n")
    if len(records) < len(original_paths):
        raise RuntimeError(f"Found {len(records)}/{len(original_paths)} required entries")


if __name__ == "__main__":
    main()
