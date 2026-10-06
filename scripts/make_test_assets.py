#!/usr/bin/env python3
"""Generate original geometric PNGs/quiet WAVs for isolated tests, no game assets."""
import json
import math
from pathlib import Path
import struct
import sys
import wave
import zlib

ROOT = Path(__file__).resolve().parents[1]


def png():
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    pixels = b''.join(b'\x00' + b''.join(bytes((50, 180, 210, 255 if 12 < x < 52 and 12 < y < 52 else 0))
                    for x in range(64)) for y in range(64))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 64, 64, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')


def main():
    target = Path(sys.argv[1])
    catalog = json.loads((ROOT / 'Resources/emotes.json').read_text())
    for mode in ('empty', 'image', 'corrupt', 'complete', 'invalid'):
        folder = target / mode
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'emotes.json').write_text(json.dumps(catalog if mode != 'invalid' else catalog + [catalog[0]], ensure_ascii=False))
        if mode in ('image', 'corrupt', 'complete'):
            (folder / 'Emotes').mkdir(exist_ok=True)
            (folder / 'Emotes/3239.png').write_bytes(png())
        if mode == 'image':
            (folder / 'Emotes/1492.png').write_bytes(b'not a PNG')
        if mode in ('corrupt', 'complete'):
            (folder / 'Sounds').mkdir(exist_ok=True)
            (folder / 'Emotes/3277.png').write_bytes(png())
            (folder / 'Animations/3277').mkdir(parents=True, exist_ok=True)
            (folder / 'Animations/3277/0000.png').write_bytes(png())
            sequence = {'duration': 0.8, 'canvasScale': 1, 'frames': [
                {'time': 0, 'image': 'Animations/3277/0000.png'}, {'time': 0.4, 'image': 'Animations/3277/0001.png'}]}
            (folder / 'Animations/3277/sequence.json').write_text(json.dumps(sequence))
            if mode == 'corrupt':
                (folder / 'Sounds/3239.wav').write_bytes(b'not an audio file')
            else:
                (folder / 'Animations/3277/0001.png').write_bytes(png())
                for emote_id in (3239, 3277):
                    with wave.open(str(folder / f'Sounds/{emote_id}.wav'), 'wb') as audio:
                        audio.setparams((1, 2, 44100, 0, 'NONE', 'not compressed'))
                        audio.writeframes(b''.join(struct.pack('<h', round(32 * math.sin(2 * math.pi * 440 * t / 44100))) for t in range(44100)))
    print('Created geometric test fixtures; no downloaded or game-derived media.')


if __name__ == '__main__':
    main()
