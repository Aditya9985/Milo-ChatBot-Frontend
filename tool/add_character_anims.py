#!/usr/bin/env python3
"""Add dance, listen, spin, and talk (lip) clips to the cozy character GLB."""

from __future__ import annotations

import json
import math
import shutil
import struct
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / "assets" / "grab3d-cozy-character.glb"


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return (
        w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
        w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
        w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
        w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
    )


def qaxis(ax, ay, az, radians):
    s = math.sin(radians * 0.5)
    return (ax * s, ay * s, az * s, math.cos(radians * 0.5))


def qn(q):
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    return (x / n, y / n, z / n, w / n)


def slerp(q0, q1, t):
    x0, y0, z0, w0 = q0
    x1, y1, z1, w1 = q1
    dot = x0 * x1 + y0 * y1 + z0 * z1 + w0 * w1
    if dot < 0:
        x1, y1, z1, w1, dot = -x1, -y1, -z1, -w1, -dot
    if dot > 0.9995:
        return qn((x0 + t * (x1 - x0), y0 + t * (y1 - y0), z0 + t * (z1 - z0), w0 + t * (w1 - w0)))
    theta = math.acos(max(-1.0, min(1.0, dot)))
    s0 = math.sin((1 - t) * theta) / math.sin(theta)
    s1 = math.sin(t * theta) / math.sin(theta)
    return qn((x0 * s0 + x1 * s1, y0 * s0 + y1 * s1, z0 * s0 + z1 * s1, w0 * s0 + w1 * s1))


def load_glb(path: Path):
    data = path.read_bytes()
    offset = 12
    gltf = None
    bin_data = bytearray()
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_type == b"JSON":
            gltf = json.loads(chunk.decode("utf-8"))
        elif chunk_type == b"BIN\x00":
            bin_data = bytearray(chunk)
    return gltf, bin_data


def write_glb(path: Path, gltf, bin_data: bytearray):
    while len(bin_data) % 4:
        bin_data.append(0)
    gltf["buffers"][0]["byteLength"] = len(bin_data)
    json_bytes = bytearray(json.dumps(gltf, separators=(",", ":")).encode("utf-8"))
    while len(json_bytes) % 4:
        json_bytes.append(0x20)
    length = 12 + 8 + len(json_bytes) + 8 + len(bin_data)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, length)
    out += struct.pack("<I4s", len(json_bytes), b"JSON")
    out += json_bytes
    out += struct.pack("<I4s", len(bin_data), b"BIN\x00")
    out += bin_data
    path.write_bytes(out)


def add_buffer_view(gltf, bin_data: bytearray, blob: bytes, target=None):
    while len(bin_data) % 4:
        bin_data.append(0)
    offset = len(bin_data)
    bin_data.extend(blob)
    view = {"buffer": 0, "byteOffset": offset, "byteLength": len(blob)}
    if target is not None:
        view["target"] = target
    gltf["bufferViews"].append(view)
    return len(gltf["bufferViews"]) - 1


def add_accessor(gltf, view, count, type_name, component_type, values, extras=None):
    acc = {
        "bufferView": view,
        "componentType": component_type,
        "count": count,
        "type": type_name,
    }
    if extras:
        acc.update(extras)
    if type_name == "SCALAR" and values:
        acc["min"] = [float(min(values))]
        acc["max"] = [float(max(values))]
    elif type_name == "VEC3" and values:
        acc["min"] = [float(min(v[i] for v in values)) for i in range(3)]
        acc["max"] = [float(max(v[i] for v in values)) for i in range(3)]
    elif type_name == "VEC4" and values:
        acc["min"] = [float(min(v[i] for v in values)) for i in range(4)]
        acc["max"] = [float(max(v[i] for v in values)) for i in range(4)]
    gltf["accessors"].append(acc)
    return len(gltf["accessors"]) - 1


def pack_f32(values, ncomp):
    blob = bytearray()
    for v in values:
        if ncomp == 1:
            blob += struct.pack("<f", float(v))
        else:
            blob += struct.pack("<" + "f" * ncomp, *[float(x) for x in v])
    return bytes(blob)


def read_accessor(gltf, bin_data, index):
    a = gltf["accessors"][index]
    bv = gltf["bufferViews"][a["bufferView"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    fmt = {5126: "f", 5123: "H", 5121: "B"}[a["componentType"]]
    size = struct.calcsize("<" + fmt)
    stride = bv.get("byteStride", size * ncomp)
    out = []
    for k in range(a["count"]):
        vals = struct.unpack_from("<" + fmt * ncomp, bin_data, start + k * stride)
        out.append(vals if ncomp > 1 else vals[0])
    return out


def anim_lookup(gltf, bin_data, name):
    anim = next(a for a in gltf["animations"] if a["name"] == name)
    table = {}
    for ch in anim["channels"]:
        samp = anim["samplers"][ch["sampler"]]
        table[(ch["target"]["node"], ch["target"]["path"])] = {
            "times": read_accessor(gltf, bin_data, samp["input"]),
            "values": read_accessor(gltf, bin_data, samp["output"]),
            "interp": samp.get("interpolation", "LINEAR"),
        }
    return table


def build_clip(gltf, bin_data, name, times, tracks):
    """tracks: list of (node, path, values) where values matches len(times)."""
    time_view = add_buffer_view(gltf, bin_data, pack_f32(times, 1))
    time_acc = add_accessor(gltf, time_view, len(times), "SCALAR", 5126, times)
    samplers = []
    channels = []
    for node, path, values in tracks:
        ncomp = 1 if path == "weights" else (3 if path in ("translation", "scale") else 4)
        # weights are a flat list of (len(times) * weight_count)
        if path == "weights":
            blob = pack_f32(values, 1)
            view = add_buffer_view(gltf, bin_data, blob)
            acc = add_accessor(gltf, view, len(values), "SCALAR", 5126, values)
        else:
            blob = pack_f32(values, ncomp)
            view = add_buffer_view(gltf, bin_data, blob)
            acc = add_accessor(
                gltf,
                view,
                len(values),
                "VEC3" if ncomp == 3 else "VEC4",
                5126,
                values,
            )
        samplers.append({"input": time_acc, "output": acc, "interpolation": "LINEAR"})
        channels.append(
            {"sampler": len(samplers) - 1, "target": {"node": node, "path": path}}
        )
    gltf["animations"].append({"name": name, "samplers": samplers, "channels": channels})


def mouth_open_delta(v):
    x, y, z = v
    mid = 0.7305
    if y < mid:
        open_t = min(1.0, (mid - y) / 0.012)
        return (x * 0.12, -0.016 * (0.4 + 0.6 * open_t), 0.012 * (0.4 + 0.6 * open_t))
    open_t = min(1.0, (y - mid) / 0.01)
    return (x * 0.06, 0.005 * open_t, 0.006)


def smile_delta(v):
    x, y, z = v
    side = 1.0 if x >= 0 else -1.0
    corner = min(1.0, abs(x) / 0.03)
    return (side * 0.01 * corner, 0.009 * (0.25 + 0.75 * corner), 0.003 * corner)


def blink_delta(v):
    x, y, z = v
    mid_y = 0.808
    return (0.0, (mid_y - y) * 0.92, 0.0)


def in_mouth_region(v):
    x, y, z = v
    return abs(x) < 0.05 and 0.715 <= y <= 0.745 and z > 0.155


def add_shape_target(gltf, bin_data, prim, deltas, name):
    view = add_buffer_view(gltf, bin_data, pack_f32(deltas, 3), target=34962)
    acc = add_accessor(gltf, view, len(deltas), "VEC3", 5126, deltas)
    targets = prim.setdefault("targets", [])
    targets.append({"POSITION": acc})
    extras = prim.setdefault("extras", {})
    names = extras.setdefault("targetNames", [])
    names.append(name)


def add_morphs(gltf, bin_data):
    mesh = gltf["meshes"][0]
    primitives = mesh["primitives"]
    for prim_index, names in (
        (0, ("open", "smile")),
        (3, ("blink",)),
        (4, ("blink",)),
        (5, ("open", "smile")),
    ):
        prim = primitives[prim_index]
        positions = read_accessor(gltf, bin_data, prim["attributes"]["POSITION"])
        for name in names:
            deltas = []
            for v in positions:
                if name == "open" and (prim_index == 5 or in_mouth_region(v)):
                    deltas.append(mouth_open_delta(v))
                elif name == "smile" and (prim_index == 5 or in_mouth_region(v)):
                    deltas.append(smile_delta(v))
                elif name == "blink":
                    deltas.append(blink_delta(v))
                else:
                    deltas.append((0.0, 0.0, 0.0))
            add_shape_target(gltf, bin_data, prim, deltas, name)
    weight_count = sum(len(p.get("targets") or []) for p in primitives)
    mesh["weights"] = [0.0] * weight_count
    return weight_count


def sample_at(src_times, src_vals, t, path):
    if not src_times:
        return src_vals[0]
    duration = src_times[-1] or 1.0
    while t > duration:
        t -= duration
    if t <= src_times[0]:
        return src_vals[0]
    i = 1
    while i < len(src_times) and src_times[i] < t:
        i += 1
    if i >= len(src_times):
        return src_vals[-1]
    t0, t1 = src_times[i - 1], src_times[i]
    u = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
    a, b = src_vals[i - 1], src_vals[i]
    if path == "rotation":
        return slerp(a, b, u)
    if isinstance(a, tuple):
        return tuple(a[k] + (b[k] - a[k]) * u for k in range(len(a)))
    return a + (b - a) * u


def copy_idle_tracks(idle, times):
    tracks = []
    for (node, path), data in idle.items():
        vals = [
            sample_at(data["times"], data["values"], t, path) for t in times
        ]
        tracks.append((node, path, vals))
    return tracks


def overlay_rotation(idle, node, times, pose_fn):
    base = idle[(node, "rotation")]["values"]
    idle_times = idle[(node, "rotation")]["times"]
    out = []
    for i, t in enumerate(times):
        # idle is 0..2 with 61 keys; sample nearest idle frame
        idx = min(len(base) - 1, int(round((t / idle_times[-1]) * (len(base) - 1))))
        out.append(qn(pose_fn(base[idx], t, i)))
    return out


def overlay_translation(idle, node, times, pose_fn):
    base = idle[(node, "translation")]["values"]
    idle_times = idle[(node, "translation")]["times"]
    out = []
    for i, t in enumerate(times):
        idx = min(len(base) - 1, int(round((t / idle_times[-1]) * (len(base) - 1))))
        b = base[idx]
        d = pose_fn(b, t, i)
        out.append((b[0] + d[0], b[1] + d[1], b[2] + d[2]))
    return out


def replace_track(tracks, node, path, values):
    for i, (n, p, _) in enumerate(tracks):
        if n == node and p == path:
            tracks[i] = (n, p, values)
            return
    tracks.append((node, path, values))


def main():
    bak = SRC.with_suffix(".glb.bak")
    source = bak if bak.exists() else SRC
    if not bak.exists():
        shutil.copy2(SRC, bak)
    gltf, bin_data = load_glb(source)
    idle = anim_lookup(gltf, bin_data, "idle")
    n_weights = add_morphs(gltf, bin_data)
    mesh_node = 20

    def make_times(duration, count):
        return [duration * i / (count - 1) for i in range(count)]

    # --- listen: right hand to ear ---
    times = make_times(2.0, 61)
    tracks = copy_idle_tracks(idle, times)

    def listen_upper(q, t, _i):
        k = min(1.0, t / 0.35)
        hold = 0.04 * math.sin(t * math.pi * 2)
        posed = qmul(q, qaxis(1, 0, 0, math.radians(-82 + hold * 12)))
        posed = qmul(posed, qaxis(0, 1, 0, math.radians(-18)))
        return slerp(q, posed, k)

    def listen_lower(q, t, _i):
        k = min(1.0, t / 0.35)
        posed = qmul(q, qaxis(0, 0, 1, math.radians(-70)))
        posed = qmul(posed, qaxis(1, 0, 0, math.radians(-25)))
        return slerp(q, posed, k)

    def listen_head(q, t, _i):
        k = min(1.0, t / 0.35)
        posed = qmul(q, qaxis(0, 0, 1, math.radians(12)))
        posed = qmul(posed, qaxis(0, 1, 0, math.radians(-8)))
        return slerp(q, posed, k)

    replace_track(tracks, 11, "rotation", overlay_rotation(idle, 11, times, listen_upper))
    replace_track(tracks, 12, "rotation", overlay_rotation(idle, 12, times, listen_lower))
    replace_track(tracks, 5, "rotation", overlay_rotation(idle, 5, times, listen_head))
    build_clip(gltf, bin_data, "listen", times, tracks)

    # --- dance: bounce + arm swings ---
    times = make_times(2.0, 61)
    tracks = copy_idle_tracks(idle, times)

    def dance_hips_r(q, t, _i):
        return qmul(q, qaxis(0, 1, 0, math.sin(t * math.pi * 2) * 0.55))

    def dance_hips_t(_b, t, _i):
        return (0.0, abs(math.sin(t * math.pi * 4)) * 0.06, 0.0)

    def dance_arm_r(q, t, _i):
        swing = math.sin(t * math.pi * 2)
        posed = qmul(q, qaxis(1, 0, 0, math.radians(-40 - 35 * swing)))
        posed = qmul(posed, qaxis(0, 0, 1, math.radians(-20 * swing)))
        return posed

    def dance_arm_l(q, t, _i):
        swing = math.sin(t * math.pi * 2 + math.pi)
        posed = qmul(q, qaxis(1, 0, 0, math.radians(-40 - 35 * swing)))
        posed = qmul(posed, qaxis(0, 0, 1, math.radians(20 * swing)))
        return posed

    def dance_low(q, t, _i):
        return qmul(q, qaxis(1, 0, 0, math.radians(-25 + 10 * math.sin(t * math.pi * 4))))

    replace_track(tracks, 1, "rotation", overlay_rotation(idle, 1, times, dance_hips_r))
    replace_track(tracks, 1, "translation", overlay_translation(idle, 1, times, dance_hips_t))
    replace_track(tracks, 11, "rotation", overlay_rotation(idle, 11, times, dance_arm_r))
    replace_track(tracks, 7, "rotation", overlay_rotation(idle, 7, times, dance_arm_l))
    replace_track(tracks, 12, "rotation", overlay_rotation(idle, 12, times, dance_low))
    replace_track(tracks, 8, "rotation", overlay_rotation(idle, 8, times, dance_low))
    build_clip(gltf, bin_data, "dance", times, tracks)

    # --- spin: full turn on the root so the whole body rotates ---
    times = make_times(2.0, 61)
    tracks = copy_idle_tracks(idle, times)
    dur = times[-1]

    def spin_root(_q, t, _i):
        return qaxis(0, 1, 0, (t / dur) * math.tau)

    def spin_hips(q, t, _i):
        return qmul(q, qaxis(0, 1, 0, (t / dur) * math.tau))

    def spin_t(_b, t, _i):
        return (0.0, abs(math.sin(t * math.pi * 4)) * 0.04, 0.0)

    replace_track(tracks, 0, "rotation", [spin_root(None, t, i) for i, t in enumerate(times)])
    replace_track(tracks, 1, "rotation", overlay_rotation(idle, 1, times, spin_hips))
    replace_track(tracks, 1, "translation", overlay_translation(idle, 1, times, spin_t))
    build_clip(gltf, bin_data, "spin", times, tracks)

    # --- talk: lip morph + small head bob ---
    times = make_times(0.8, 61)
    tracks = copy_idle_tracks(idle, times)
    weights = []
    for _t in times:
        weights.extend([0.0] * n_weights)

    def talk_head(q, t, i):
        return qmul(q, qaxis(1, 0, 0, math.radians(4 * math.sin(t * math.pi * 6))))

    replace_track(tracks, 5, "rotation", overlay_rotation(idle, 5, times, talk_head))
    tracks.append((mesh_node, "weights", weights))
    build_clip(gltf, bin_data, "talk", times, tracks)

    dest = SRC
    write_glb(dest, gltf, bin_data)
    extra = Path(__file__).resolve().parents[1] / "lib" / "models" / "grab3d-cozy-character.glb"
    extra.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dest, extra)
    names = [a["name"] for a in gltf["animations"]]
    print("wrote", dest, "size", dest.stat().st_size, "anims", names)


if __name__ == "__main__":
    main()
