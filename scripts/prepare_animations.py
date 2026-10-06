#!/usr/bin/env python3
"""Prepare transparent desktop frames from pinned game emitter definitions.

Uses the original texture atlas, lifetime curves, layer order and emission
timing. Stochastic particles use a reproducible seed for offline playback.
"""
import bisect
import json
import math
from pathlib import Path
import random

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
CANVAS = 768
PIXELS_PER_UNIT = 2
FPS = 60


def interpolate(times, values, t):
    i = bisect.bisect_right(times, t)
    if i == 0:
        return values[0]
    if i == len(times):
        return values[-1]
    amount = (t - times[i-1]) / (times[i] - times[i-1])
    a, b = values[i-1], values[i]
    if isinstance(a, list):
        return [x + (y-x)*amount for x, y in zip(a, b)]
    return a + (b-a)*amount


def value(definition, t=0, default=1, seed=0):
    if not isinstance(definition, dict):
        return default if definition is None else definition
    dynamics = definition.get("dynamics", {})
    # In a Value container the curve already contains the authored magnitude;
    # constantValue is the fallback rather than another multiplicative factor.
    times, values = dynamics.get("times", []), dynamics.get("values", [])
    result = interpolate(times, values, t) if times else definition.get("constantValue", default)
    tables = dynamics.get("probabilityTables", [])
    rng = random.Random(seed)
    if isinstance(result, list):
        result = list(result)
        for i, table in enumerate(tables[:len(result)]):
            if table.get("keyTimes"):
                result[i] *= interpolate(table["keyTimes"], table["keyValues"], rng.random())
    elif tables and tables[0].get("keyTimes"):
        result *= interpolate(tables[0]["keyTimes"], tables[0]["keyValues"], rng.random())
    return result


def integrate(definition, end, lifetime, default):
    if not definition or end <= 0:
        return [0, 0, 0]
    # Piecewise linear curves integrate exactly with the trapezoid rule at keys.
    keys = definition.get("dynamics", {}).get("times", [])
    times = sorted({0, end, *(key*lifetime for key in keys if 0 < key*lifetime < end)})
    result = [0, 0, 0]
    for left, right in zip(times, times[1:]):
        a = value(definition, left/lifetime, default)
        b = value(definition, right/lifetime, default)
        for i in range(3):
            result[i] += (a[i]+b[i])*(right-left)/2
    return result


def tint(image, color, additive):
    channels = image.split()
    rgb = [channels[i].point(lambda x, c=color[i]: max(0, min(255, round(x*c)))) for i in range(3)]
    alpha = channels[3].point(lambda x: max(0, min(255, round(x*color[3]))))
    return Image.merge("RGBA", (*rgb, alpha))


def composite_light(canvas, image, position):
    # Add premultiplied light without covering the underlying character. Alpha
    # outside the character is derived from emitted light for a portable PNG.
    light = Image.new("RGBA", canvas.size)
    light.alpha_composite(image, position)
    source = light.convert("RGBa").split()
    destination = canvas.convert("RGBa").split()
    brightness = ImageChops.lighter(ImageChops.lighter(source[0], source[1]), source[2])
    alpha = ImageChops.invert(ImageChops.multiply(ImageChops.invert(destination[3]), ImageChops.invert(brightness)))
    channels = [ImageChops.add(destination[i], source[i]) for i in range(3)]
    return Image.merge("RGBa", (*channels, alpha)).convert("RGBA")


def particles(emitter, layer_index):
    start = emitter.get("timeBeforeFirstEmission", 0)
    rate = value(emitter.get("rate"), default=1)
    if rate <= 0:
        return []
    if emitter.get("isSingleParticle"):
        births = [start]
    else:
        births = [start+i/rate for i in range(max(1, math.ceil(emitter.get("lifetime", 0.1)*rate)))]
    return [(birth, layer_index*1000+i) for i, birth in enumerate(births)]


def render_layer(emitter, texture, age, lifetime, seed):
    normalized = age/lifetime
    grid = emitter.get("texDiv", [1, 1])
    cols, rows = max(1, round(grid[0])), max(1, round(grid[1]))
    frames = emitter.get("numFrames", 1)
    frame = int(age*emitter.get("frameRate", 0))
    if emitter.get("isRandomStartFrame"):
        frame += random.Random(seed).randrange(frames)
    frame = min(frames-1, frame) % (cols*rows)
    w, h = texture.width//cols, texture.height//rows
    image = texture.crop(((frame%cols)*w, (frame//cols)*h, (frame%cols+1)*w, (frame//cols+1)*h))
    if "birthUvScrollRate" in emitter or "birthUVOffset" in emitter:
        speed = value(emitter.get("birthUvScrollRate"), default=[0, 0])
        initial = value(emitter.get("birthUVOffset"), default=[0, 0])
        shift = (-round((initial[0]+speed[0]*age)*w), -round((initial[1]+speed[1]*age)*h))
        if emitter.get("texAddressModeBase", 0) == 2 or emitter.get("uvScrollClamp"):
            shifted = Image.new("RGBA", image.size)
            shifted.alpha_composite(image, shift)
            image = shifted
        else:
            image = ImageChops.offset(image, *shift)
    born = value(emitter.get("birthColor"), default=[1, 1, 1, 1], seed=seed)
    color = value(emitter.get("Color", emitter.get("color")), normalized, [1, 1, 1, 1])
    color = [x*y for x, y in zip(born, color)]
    if color[3] <= 0:
        return None
    image = tint(image, color, emitter.get("blendMode", 0) in (0, 4))
    size = value(emitter.get("birthScale0"), default=[70, 70, 70], seed=seed)
    scale = value(emitter.get("scale0"), normalized, [1, 1, 1])
    uniform = emitter.get("isUniformScale", False)
    sx = abs(size[0]*scale[0])
    sy = sx if uniform else abs(size[1]*scale[1])
    width, height = round(sx*2*PIXELS_PER_UNIT), round(sy*2*PIXELS_PER_UNIT)
    if width < 1 or height < 1:
        return None
    image = image.resize((min(width, CANVAS*2), min(height, CANVAS*2)), Image.Resampling.LANCZOS)
    rotation = value(emitter.get("birthRotation0"), default=[0, 0, 0], seed=seed)[0]
    rotation += value(emitter.get("birthRotationalVelocity0"), default=[0, 0, 0], seed=seed)[0]*age
    rotation += integrate(emitter.get("rotation0"), age, lifetime, [0, 0, 0])[0]
    image = image.rotate(-rotation, Image.Resampling.BICUBIC, expand=True)
    shape = emitter.get("SpawnShape", emitter.get("spawnShape", {}))
    offset = value(shape.get("emitOffset"), default=[0, 0, 0], seed=seed)
    position = value(emitter.get("EmitterPosition"), default=[0, 0, 0], seed=seed)
    rng = random.Random(seed)
    if shape.get("__type") == "VfxShapeBox":
        dimensions = shape.get("Size", [0, 0, 0])
        offset = [a+rng.uniform(-b/2, b/2) for a, b in zip(offset, dimensions)]
    if shape.get("emitRotationAngles"):
        angle = math.radians(value(shape["emitRotationAngles"][0], seed=seed))
        offset = [offset[0]*math.cos(angle), offset[0]*math.sin(angle), offset[2]]
    velocity = value(emitter.get("birthVelocity"), default=[0, 0, 0], seed=seed)
    motion = integrate(emitter.get("velocity"), age, lifetime, [0, 0, 0])
    x = offset[0]+position[0]+velocity[0]*age+motion[0]
    y = offset[1]+position[1]+velocity[1]*age+motion[1]
    return image, (round(CANVAS/2+x*PIXELS_PER_UNIT-image.width/2),
                   round(CANVAS/2-y*PIXELS_PER_UNIT-image.height/2)), emitter.get("blendMode", 0) in (0, 4)


def main():
    sources = json.loads((ROOT / "research_assets/expansion-sources.json").read_text())
    textures = json.loads((ROOT / "research_assets/animation-textures.json").read_text())
    records = []
    for emote_id in [3277, 3278]:
        item = next(item for item in sources if item["id"] == emote_id)
        layers = []
        for system in item["systems"]:
            for emitter in system["data"].get("complexEmitterDefinitionData", []):
                if not emitter.get("texture") or emitter.get("disabled"):
                    continue
                image = Image.open(ROOT / textures[emitter["texture"]]).convert("RGBA")
                layers.append((emitter, image, particles(emitter, len(layers))))
        layers.sort(key=lambda layer: layer[0].get("pass", 0))
        duration = max(birth + value(e.get("particleLifetime"), default=2, seed=seed)
                       for e, _, births in layers for birth, seed in births)
        duration = math.ceil(duration*FPS)/FPS
        output = ROOT / "Resources/Animations" / str(emote_id)
        output.mkdir(parents=True, exist_ok=True)
        frames = []
        for index in range(math.ceil(duration*FPS)):
            t = index/FPS
            canvas = Image.new("RGBA", (CANVAS, CANVAS))
            for emitter, texture, births in layers:
                for birth, seed in births:
                    lifetime = value(emitter.get("particleLifetime"), default=2, seed=seed)
                    age = t-birth
                    if age < -1e-7 or age >= lifetime:
                        continue
                    rendered = render_layer(emitter, texture, max(0, age), lifetime, seed)
                    if rendered:
                        image, position, additive = rendered
                        if additive:
                            canvas = composite_light(canvas, image, position)
                        else:
                            canvas.alpha_composite(image, position)
            name = f"{index:04d}.png"
            canvas.save(output / name)
            frames.append({"time": t, "image": f"Animations/{emote_id}/{name}"})
        result = {"duration": duration, "canvasScale": CANVAS/(140*PIXELS_PER_UNIT), "frames": frames}
        (output / "sequence.json").write_text(json.dumps(result, indent=2) + "\n")
        records.append({"id": emote_id, "duration": duration, "frames": len(frames),
                        "resolution": [CANVAS, CANVAS], "fps": FPS,
                        "originalSystems": [s["source"] for s in item["systems"]],
                        "randomSeed": "stable emitter index + particle index",
                        "notes": "Original atlas and emitter curves; additive light textures converted to transparent alpha layers for desktop compositing."})
        print(emote_id, len(frames), "frames", duration, "seconds", flush=True)
    (ROOT / "research_assets/animation-build.json").write_text(json.dumps(records, indent=2) + "\n")


if __name__ == "__main__":
    main()
