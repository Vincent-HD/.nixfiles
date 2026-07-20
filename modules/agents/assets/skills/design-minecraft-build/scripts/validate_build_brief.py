#!/usr/bin/env python3
"""Validate a coordinate-aware Minecraft build brief JSON file."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


BLOCK_RE = re.compile(r"^[a-z0-9_.-]+:[a-z0-9_./-]+(?:\[[^\]]+\])?$")
REQUIRED = {
    "project", "edition", "minecraft_version", "mods", "deliverable",
    "coordinate_system", "envelope", "style", "palette", "zones", "features",
    "interfaces", "constraints", "assumptions", "construction_stages", "acceptance_checks",
}


def validate(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    warnings: list[str] = []
    missing = REQUIRED - set(data)
    if missing:
        errors.append(f"Missing root fields: {', '.join(sorted(missing))}")

    edition = data.get("edition")
    deliverable = data.get("deliverable")
    if edition not in {"java", "bedrock"}:
        errors.append("edition must be java or bedrock")
    if deliverable not in {"advice", "plan", "schematic", "both"}:
        errors.append("deliverable must be advice, plan, schematic, or both")
    if not isinstance(data.get("project"), str) or not data.get("project", "").strip():
        errors.append("project must be a non-empty string")
    if not isinstance(data.get("mods"), list) or any(not isinstance(v, str) for v in data.get("mods", [])):
        errors.append("mods must be a list of strings")

    coordinate = data.get("coordinate_system", {})
    if not isinstance(coordinate, dict):
        errors.append("coordinate_system must be an object")
        coordinate = {}
    if coordinate.get("front_direction") not in {"-Z", "+Z", "-X", "+X"}:
        errors.append("coordinate_system.front_direction must be -Z, +Z, -X, or +X")
    axes = coordinate.get("axes")
    if not isinstance(axes, dict) or set(axes) != {"x", "y", "z"}:
        errors.append("coordinate_system.axes must define x, y, and z")

    envelope = data.get("envelope", {})
    dims: tuple[int, int, int] | None = None
    if not isinstance(envelope, dict):
        errors.append("envelope must be an object")
    else:
        values = [envelope.get(key) for key in ("width", "height", "depth")]
        if any(type(value) is not int or value <= 0 for value in values):
            errors.append("envelope width, height, and depth must be positive integers")
        else:
            dims = tuple(values)

    style = data.get("style", {})
    keywords = style.get("keywords", []) if isinstance(style, dict) else []
    if not isinstance(keywords, list) or any(not isinstance(v, str) for v in keywords):
        errors.append("style.keywords must be a list of strings")
    elif len(keywords) < 2:
        warnings.append("Use at least two style keywords to constrain the design language")

    palette = data.get("palette", [])
    if not isinstance(palette, list):
        errors.append("palette must be a list")
        palette = []
    roles: set[str] = set()
    palette_blocks: set[str] = set()
    for index, entry in enumerate(palette):
        if not isinstance(entry, dict):
            errors.append(f"palette[{index}] must be an object")
            continue
        role = entry.get("role")
        blocks = entry.get("blocks")
        if not isinstance(role, str) or not role.strip():
            errors.append(f"palette[{index}].role must be non-empty")
        elif role in roles:
            warnings.append(f"palette role is repeated: {role}")
        else:
            roles.add(role)
        if not isinstance(blocks, list) or not blocks:
            errors.append(f"palette[{index}].blocks must be a non-empty list")
        else:
            for block in blocks:
                if not isinstance(block, str) or not BLOCK_RE.fullmatch(block):
                    errors.append(f"invalid block state in palette[{index}]: {block!r}")
                else:
                    palette_blocks.add(block)

    def check_bounds(collection_name: str) -> None:
        collection = data.get(collection_name, [])
        if not isinstance(collection, list):
            errors.append(f"{collection_name} must be a list")
            return
        names: set[str] = set()
        for index, item in enumerate(collection):
            if not isinstance(item, dict):
                errors.append(f"{collection_name}[{index}] must be an object")
                continue
            name = item.get("name")
            if not isinstance(name, str) or not name.strip():
                errors.append(f"{collection_name}[{index}].name must be non-empty")
            elif name in names:
                warnings.append(f"duplicate {collection_name} name: {name}")
            else:
                names.add(name)
            bounds = item.get("bounds")
            if not isinstance(bounds, list) or len(bounds) != 6 or any(type(v) is not int for v in bounds):
                errors.append(f"{collection_name}[{index}].bounds must contain six integers")
                continue
            if dims:
                x1, y1, z1, x2, y2, z2 = bounds
                low = (min(x1, x2), min(y1, y2), min(z1, z2))
                high = (max(x1, x2), max(y1, y2), max(z1, z2))
                if any(value < 0 for value in low) or high[0] >= dims[0] or high[1] >= dims[1] or high[2] >= dims[2]:
                    errors.append(f"{collection_name}[{index}].bounds exceed the envelope")

    check_bounds("zones")
    check_bounds("features")

    for field in ("interfaces", "constraints", "assumptions", "construction_stages", "acceptance_checks"):
        value = data.get(field, [])
        if not isinstance(value, list):
            errors.append(f"{field} must be a list")
    if isinstance(data.get("acceptance_checks"), list) and not data["acceptance_checks"]:
        warnings.append("Add measurable acceptance checks")
    if isinstance(data.get("construction_stages"), list) and not data["construction_stages"]:
        warnings.append("Add a construction sequence")

    if deliverable in {"schematic", "both"}:
        if edition != "java":
            errors.append(".litematic and .schem delivery requires Java Edition")
        if not isinstance(data.get("minecraft_version"), str) or not re.fullmatch(r"\d+(?:\.\d+){1,2}", data.get("minecraft_version", "")):
            errors.append("schematic delivery requires an exact minecraft_version")
        if type(data.get("data_version")) is not int or data.get("data_version", 0) <= 0:
            errors.append("schematic delivery requires a positive data_version")
        if not palette_blocks:
            errors.append("schematic delivery requires exact palette block IDs")
    elif "data_version" not in data:
        warnings.append("Add data_version before converting this plan to a schematic")

    return {
        "valid": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "project": data.get("project"),
            "deliverable": deliverable,
            "dimensions": dims,
            "palette_roles": len(roles),
            "unique_block_states": len(palette_blocks),
            "zones": len(data.get("zones", [])) if isinstance(data.get("zones"), list) else 0,
            "features": len(data.get("features", [])) if isinstance(data.get("features"), list) else 0,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("brief", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = validate(args.brief.resolve())
    rendered = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.report:
        args.report.resolve().write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    raise SystemExit(0 if report["valid"] else 1)


if __name__ == "__main__":
    main()
