#!/usr/bin/env python3
"""Provision canonical Essentials DAV collections and device share mappings."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import tempfile
import time
from pathlib import Path
from typing import Any, Callable, TextIO


CSV_FIELDS = [
    "ShareType", "PathOrToken", "PathMapped", "Conversion", "Owner", "User",
    "Permissions", "EnabledByOwner", "EnabledByUser", "HiddenByOwner",
    "HiddenByUser", "TimestampCreated", "TimestampUpdated", "Properties", "Actions",
]
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identities", required=True, type=Path)
    parser.add_argument("--storage", required=True, type=Path)
    parser.add_argument("--database", required=True, type=Path)
    return parser.parse_args()


def load_identities(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as source:
        identities = json.load(source)
    if not isinstance(identities, dict):
        raise ValueError("identities must be a JSON object")
    return identities


def checked_mapping(value: Any, name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{name} must be an object")
    return value


def checked_name(value: Any, description: str) -> str:
    if not isinstance(value, str) or not SAFE_NAME.fullmatch(value):
        raise ValueError(f"invalid {description}: {value!r}")
    return value


def atomic_write(path: Path, write: Callable[[TextIO], Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    previous_mode = path.stat().st_mode & 0o777 if path.exists() else None
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as output:
            write(output)
            output.flush()
            os.fsync(output.fileno())
        if previous_mode is not None:
            os.chmod(temporary, previous_mode)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def ensure_collection(storage: Path, owner: str, collection: str, spec: Any) -> None:
    spec = checked_mapping(spec, f"collection {owner}/{collection}")
    tag = spec.get("tag")
    display_name = spec.get("displayName")
    if tag not in {"VCALENDAR", "VADDRESSBOOK"}:
        raise ValueError(f"invalid DAV tag for {owner}/{collection}: {tag!r}")
    if not isinstance(display_name, str) or not display_name:
        raise ValueError(f"invalid display name for {owner}/{collection}")

    collection_path = storage / "collection-root" / owner / collection
    collection_path.mkdir(parents=True, exist_ok=True)
    properties_path = collection_path / ".Radicale.props"
    properties: dict[str, Any] = {}
    if properties_path.exists():
        with properties_path.open(encoding="utf-8") as source:
            loaded = json.load(source)
        if not isinstance(loaded, dict):
            raise ValueError(f"invalid Radicale properties in {properties_path}")
        properties.update(loaded)
    properties.update({"tag": tag, "D:displayname": display_name})
    encoded = json.dumps(properties, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    atomic_write(properties_path, lambda output: output.write(encoded))


def desired_rows(identities: dict[str, Any], now: int) -> list[dict[str, str]]:
    users = checked_mapping(identities.get("users"), "users")
    groups = checked_mapping(identities.get("groups"), "groups")
    devices = checked_mapping(identities.get("devices"), "devices")
    dav = checked_mapping(identities.get("davCollections"), "davCollections")
    user_collections = checked_mapping(dav.get("users"), "davCollections.users")
    group_collections = checked_mapping(dav.get("groups"), "davCollections.groups")

    rows: list[dict[str, str]] = []
    for raw_device_name, raw_device in sorted(devices.items()):
        device_name = checked_name(raw_device_name, "device name")
        device = checked_mapping(raw_device, f"device {device_name}")
        user = checked_name(device.get("user"), f"user for device {device_name}")
        if user not in users:
            raise ValueError(f"device {device_name} references unknown user {user}")
        raw_groups = device.get("groups")
        if not isinstance(raw_groups, list) or not all(isinstance(group, str) for group in raw_groups):
            raise ValueError(f"groups for device {device_name} must be a list of names")

        mappings: list[tuple[str, str, str]] = []
        private = checked_mapping(user_collections.get(user, {}), f"collections for {user}")
        for raw_collection in sorted(private):
            collection = checked_name(raw_collection, f"collection for {user}")
            mappings.append((f"private-{collection}", user, collection))
        for raw_group in sorted(raw_groups):
            group = checked_name(raw_group, f"group for device {device_name}")
            if group not in groups:
                raise ValueError(f"device {device_name} references unknown group {group}")
            shared = checked_mapping(group_collections.get(group, {}), f"collections for {group}")
            for raw_collection in sorted(shared):
                collection = checked_name(raw_collection, f"collection for {group}")
                mappings.append((f"{group}-{collection}", group, collection))

        for alias, owner, collection in mappings:
            rows.append({
                "ShareType": "map", "PathOrToken": f"/{device_name}/{alias}/",
                "PathMapped": f"/{owner}/{collection}/", "Conversion": "none",
                "Owner": owner, "User": device_name, "Permissions": "rw",
                "EnabledByOwner": "True", "EnabledByUser": "True",
                "HiddenByOwner": "False", "HiddenByUser": "False",
                "TimestampCreated": str(now), "TimestampUpdated": str(now),
                "Properties": "", "Actions": "",
            })
    return rows


def preserve_timestamps(rows: list[dict[str, str]], database: Path) -> None:
    if not database.exists():
        return
    with database.open(encoding="utf-8", newline="") as source:
        existing = {
            row.get("PathOrToken"): row for row in csv.DictReader(source, delimiter=";")
            if row.get("ShareType") == "map"
        }
    stable = ("ShareType", "PathOrToken", "PathMapped", "Conversion", "Owner", "User", "Permissions")
    changing = tuple(field for field in CSV_FIELDS if field not in {"TimestampCreated", "TimestampUpdated"})
    for row in rows:
        previous = existing.get(row["PathOrToken"])
        if not previous:
            continue
        normalized_previous = dict(previous)
        normalized_previous["Conversion"] = previous.get("Conversion") or "none"
        if all(normalized_previous.get(field) == row[field] for field in stable):
            row["TimestampCreated"] = previous.get("TimestampCreated") or row["TimestampCreated"]
            if all(normalized_previous.get(field, "") == row[field] for field in changing):
                row["TimestampUpdated"] = previous.get("TimestampUpdated") or row["TimestampUpdated"]


def reconcile(identities: dict[str, Any], storage: Path, database: Path) -> None:
    dav = checked_mapping(identities.get("davCollections"), "davCollections")
    for scope in ("users", "groups"):
        owners = checked_mapping(dav.get(scope), f"davCollections.{scope}")
        for raw_owner, collections in sorted(owners.items()):
            owner = checked_name(raw_owner, f"{scope} collection owner")
            for raw_collection, spec in sorted(checked_mapping(collections, f"collections for {owner}").items()):
                collection = checked_name(raw_collection, f"collection for {owner}")
                ensure_collection(storage, owner, collection, spec)

    rows = desired_rows(identities, int(time.time()))
    preserve_timestamps(rows, database)

    def write_csv(output: TextIO) -> None:
        writer = csv.DictWriter(output, fieldnames=CSV_FIELDS, delimiter=";", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    atomic_write(database, write_csv)


def main() -> None:
    args = parse_args()
    reconcile(load_identities(args.identities), args.storage, args.database)


if __name__ == "__main__":
    main()
