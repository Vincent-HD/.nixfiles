#!/usr/bin/env python3
"""Generate and validate single-region Litematic and Sponge v2 schematics."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

try:
    import mcschematic
    import nbtlib
    from litemapy import BlockState, Region, Schematic
    from nbtlib.tag import ByteArray, Compound, Int, List, Short, String
except ImportError as exc:
    raise SystemExit(
        "Missing dependency. Install scripts/requirements.txt in a venv or target directory. "
        f"Original error: {exc}"
    ) from exc


STATE_RE = re.compile(r"^([a-z0-9_.-]+:[a-z0-9_./-]+)(?:\[([^\]]*)\])?$")
AIR = "minecraft:air"


def load_spec(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    required = {"name", "author", "description", "minecraft_version", "data_version", "dimensions", "operations"}
    missing = required - set(data)
    if missing:
        raise ValueError(f"Missing spec fields: {', '.join(sorted(missing))}")
    dims = data["dimensions"]
    if not isinstance(dims, list) or len(dims) != 3 or any(type(v) is not int or v <= 0 for v in dims):
        raise ValueError("dimensions must be three positive integers")
    if any(v > 32767 for v in dims):
        raise ValueError("Sponge v2 dimensions must fit signed shorts (<=32767)")
    if type(data["data_version"]) is not int or data["data_version"] <= 0:
        raise ValueError("data_version must be a positive integer")
    if not isinstance(data["operations"], list):
        raise ValueError("operations must be a list")
    return data


def normalize_state(value: Any) -> str:
    if not isinstance(value, str):
        raise ValueError("block state must be a string")
    match = STATE_RE.fullmatch(value)
    if not match:
        raise ValueError(f"Invalid block-state syntax: {value}")
    if match.group(2):
        props = match.group(2).split(",")
        if any("=" not in prop or not prop.split("=", 1)[0] or not prop.split("=", 1)[1] for prop in props):
            raise ValueError(f"Invalid block-state properties: {value}")
    return value


def parse_position(value: Any, label: str) -> tuple[int, int, int]:
    if not isinstance(value, list) or len(value) != 3 or any(type(v) is not int for v in value):
        raise ValueError(f"{label} must contain three integers")
    return tuple(value)


def expand_spec(spec: dict[str, Any]) -> dict[tuple[int, int, int], str]:
    width, height, length = spec["dimensions"]
    blocks: dict[tuple[int, int, int], str] = {}

    def place(pos: tuple[int, int, int], state: str) -> None:
        x, y, z = pos
        if not (0 <= x < width and 0 <= y < height and 0 <= z < length):
            raise ValueError(f"Coordinate outside declared dimensions: {pos}")
        if state == AIR:
            blocks.pop(pos, None)
        else:
            blocks[pos] = state

    for index, op in enumerate(spec["operations"]):
        if not isinstance(op, dict):
            raise ValueError(f"Operation {index} must be an object")
        state = normalize_state(op.get("state"))
        selectors = [key for key in ("pos", "box", "line") if key in op]
        if len(selectors) != 1:
            raise ValueError(f"Operation {index} must contain exactly one of pos, box, or line")
        selector = selectors[0]
        if selector == "pos":
            place(parse_position(op["pos"], "pos"), state)
        else:
            value = op[selector]
            if not isinstance(value, list) or len(value) != 6 or any(type(v) is not int for v in value):
                raise ValueError(f"{selector} must contain six integers")
            x1, y1, z1, x2, y2, z2 = value
            if selector == "line" and sum(a != b for a, b in ((x1, x2), (y1, y2), (z1, z2))) > 1:
                raise ValueError(f"Operation {index} line is not axis-aligned")
            for x in range(min(x1, x2), max(x1, x2) + 1):
                for y in range(min(y1, y2), max(y1, y2) + 1):
                    for z in range(min(z1, z2), max(z1, z2) + 1):
                        place((x, y, z), state)
    return blocks


def to_litemapy_state(value: str) -> BlockState:
    match = STATE_RE.fullmatch(value)
    assert match
    props: dict[str, str] = {}
    if match.group(2):
        for item in match.group(2).split(","):
            key, val = item.split("=", 1)
            props[key] = val
    return BlockState(match.group(1), **props)


def encode_varint(value: int) -> bytes:
    if value < 0:
        raise ValueError("palette IDs cannot be negative")
    output = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        output.append(byte | 0x80 if value else byte)
        if not value:
            return bytes(output)


def decode_varints(raw: bytes) -> list[int]:
    values: list[int] = []
    value = shift = 0
    for byte in raw:
        value |= (byte & 0x7F) << shift
        if byte & 0x80:
            shift += 7
            if shift > 35:
                raise ValueError("Malformed Sponge VarInt")
        else:
            values.append(value)
            value = shift = 0
    if shift:
        raise ValueError("Truncated Sponge VarInt")
    return values


def write_litematic(spec: dict[str, Any], blocks: dict[tuple[int, int, int], str], path: Path) -> None:
    width, height, length = spec["dimensions"]
    region = Region(0, 0, 0, width, height, length)
    cache: dict[str, BlockState] = {}
    for pos, value in blocks.items():
        cache.setdefault(value, to_litemapy_state(value))
        region[pos] = cache[value]
    schematic = region.as_schematic(
        name=spec["name"],
        author=spec["author"],
        description=spec["description"],
        mc_version=spec["data_version"],
    )
    schematic.save(str(path))


def write_schem(spec: dict[str, Any], blocks: dict[tuple[int, int, int], str], path: Path) -> None:
    width, height, length = spec["dimensions"]
    states = [AIR] + sorted(set(blocks.values()))
    palette = {state: index for index, state in enumerate(states)}
    encoded = bytearray()
    for y in range(height):
        for z in range(length):
            for x in range(width):
                encoded.extend(encode_varint(palette[blocks.get((x, y, z), AIR)]))
    signed = [value if value < 128 else value - 256 for value in encoded]
    root = Compound({
        "Version": Int(2),
        "DataVersion": Int(spec["data_version"]),
        "Metadata": Compound({
            "WEOffsetX": Int(0), "WEOffsetY": Int(0), "WEOffsetZ": Int(0),
            "Name": String(spec["name"]),
        }),
        "Width": Short(width), "Height": Short(height), "Length": Short(length),
        "PaletteMax": Int(len(palette)),
        "Palette": Compound({state: Int(index) for state, index in palette.items()}),
        "BlockData": ByteArray(signed),
        "BlockEntities": List[Compound]([]),
        "Entities": List[Compound]([]),
    })
    nbtlib.File(root, gzipped=True, byteorder="big", root_name="Schematic").save(path)


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_files(
    spec: dict[str, Any],
    blocks: dict[tuple[int, int, int], str],
    litematic_path: Path | None,
    schem_path: Path | None,
) -> dict[str, Any]:
    dims = tuple(spec["dimensions"])
    expected_palette = set(blocks.values()) | {AIR}
    report: dict[str, Any] = {
        "dimensions": {"width_x": dims[0], "height_y": dims[1], "depth_z": dims[2]},
        "minecraft_version": spec["minecraft_version"],
        "data_version": spec["data_version"],
        "volume": dims[0] * dims[1] * dims[2],
        "non_air_blocks": len(blocks),
        "palette_size_including_air": len(expected_palette),
        "block_counts": dict(sorted(Counter(blocks.values()).items())),
        "files": {},
    }

    if litematic_path:
        loaded = Schematic.load(str(litematic_path))
        if (loaded.width, loaded.height, loaded.length) != dims:
            raise ValueError("Litematic dimensions changed after reload")
        if loaded.mc_version != spec["data_version"]:
            raise ValueError("Litematic MinecraftDataVersion mismatch")
        if len(loaded.regions) != 1:
            raise ValueError("Expected one Litematic region")
        region = next(iter(loaded.regions.values()))
        palette = {state.to_block_state_identifier() for state in region.palette}
        if palette != expected_palette:
            raise ValueError("Litematic palette mismatch")
        if region.count_blocks() != len(blocks):
            raise ValueError("Litematic non-air count mismatch")
        for pos, expected in blocks.items():
            actual = region[pos].to_block_state_identifier()
            if actual != expected:
                raise ValueError(f"Litematic block mismatch at {pos}: {actual} != {expected}")
        raw = nbtlib.load(litematic_path, gzipped=True)
        if not {"Version", "MinecraftDataVersion", "Metadata", "Regions"} <= set(raw):
            raise ValueError("Litematic NBT root is incomplete")
        report["files"]["litematic"] = {
            "path": str(litematic_path), "bytes": litematic_path.stat().st_size,
            "sha256": file_hash(litematic_path), "library_reload": "passed", "raw_nbt": "passed",
        }

    if schem_path:
        raw_file = nbtlib.load(schem_path, gzipped=True)
        root = raw_file["Schematic"] if "Schematic" in raw_file else raw_file
        actual_dims = (int(root["Width"]), int(root["Height"]), int(root["Length"]))
        if actual_dims != dims:
            raise ValueError("Sponge dimensions changed after reload")
        if int(root["Version"]) != 2 or int(root["DataVersion"]) != spec["data_version"]:
            raise ValueError("Sponge version metadata mismatch")
        palette = {str(key): int(value) for key, value in root["Palette"].items()}
        if set(palette) != expected_palette or len(set(palette.values())) != len(palette):
            raise ValueError("Sponge palette mismatch or duplicate IDs")
        decoded = decode_varints(bytes(bytearray(root["BlockData"])))
        if len(decoded) != report["volume"] or max(decoded, default=0) >= int(root["PaletteMax"]):
            raise ValueError("Sponge BlockData length or palette index is invalid")
        for index, palette_id in enumerate(decoded):
            y, rem = divmod(index, dims[0] * dims[2])
            z, x = divmod(rem, dims[0])
            expected = blocks.get((x, y, z), AIR)
            if palette_id != palette[expected]:
                raise ValueError(f"Sponge block mismatch at {(x, y, z)}")
        if root.get("BlockEntities") and len(root["BlockEntities"]):
            raise ValueError("Unexpected Sponge block entities")
        # Independent reader: successful construction proves MCSchematic can parse the file.
        independent = mcschematic.MCSchematic(str(schem_path))
        if len(independent.getStructure().getBlockStates()) != len(blocks):
            raise ValueError("MCSchematic non-air count mismatch")
        report["files"]["schem"] = {
            "path": str(schem_path), "format": "Sponge Schematic v2",
            "bytes": schem_path.stat().st_size, "sha256": file_hash(schem_path),
            "independent_library_reload": "passed", "raw_nbt_and_varints": "passed",
        }
    return report


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return slug or "minecraft_build"


def command_generate(args: argparse.Namespace) -> None:
    spec_path = Path(args.spec).resolve()
    spec = load_spec(spec_path)
    blocks = expand_spec(spec)
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    stem = args.name or slugify(spec["name"])
    formats = {item.strip() for item in args.formats.split(",") if item.strip()}
    if not formats or formats - {"litematic", "schem"}:
        raise ValueError("formats must contain litematic and/or schem")
    lite = output_dir / f"{stem}.litematic" if "litematic" in formats else None
    schem = output_dir / f"{stem}.schem" if "schem" in formats else None
    if lite:
        write_litematic(spec, blocks, lite)
    if schem:
        write_schem(spec, blocks, schem)
    report = validate_files(spec, blocks, lite, schem)
    report_path = output_dir / f"{stem}_validation.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))


def command_validate(args: argparse.Namespace) -> None:
    spec = load_spec(Path(args.spec).resolve())
    blocks = expand_spec(spec)
    lite = Path(args.litematic).resolve() if args.litematic else None
    schem = Path(args.schem).resolve() if args.schem else None
    if not lite and not schem:
        raise ValueError("provide --litematic and/or --schem")
    report = validate_files(spec, blocks, lite, schem)
    if args.report:
        Path(args.report).resolve().write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    generate = sub.add_parser("generate", help="generate and validate schematic files")
    generate.add_argument("spec")
    generate.add_argument("--output-dir", required=True)
    generate.add_argument("--formats", default="litematic,schem")
    generate.add_argument("--name", help="output filename stem")
    generate.set_defaults(func=command_generate)
    validate = sub.add_parser("validate", help="validate files against their source spec")
    validate.add_argument("--spec", required=True)
    validate.add_argument("--litematic")
    validate.add_argument("--schem")
    validate.add_argument("--report")
    validate.set_defaults(func=command_validate)
    args = parser.parse_args()
    try:
        args.func(args)
    except (OSError, ValueError, KeyError, AssertionError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
