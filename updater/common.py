#!/usr/bin/env python3

"""Shared deterministic catalog and updater helpers."""

from __future__ import annotations

import difflib
import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path, PurePosixPath
from typing import Any, Sequence


UPDATER_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = UPDATER_DIR.parent
CATALOG_PATH = UPDATER_DIR / "versions.json"
EXTENSION_DIR = REPOSITORY_ROOT / "extension-applovin"
USER_AGENT = "extension-applovin-updater/2.0"


class UpdaterError(RuntimeError):
    """A concise user-facing updater failure."""


def parse_coordinate(coordinate: str) -> tuple[str, str, str]:
    parts = coordinate.split(":")
    if len(parts) != 3 or not all(parts):
        raise UpdaterError(f"Invalid Maven coordinate: {coordinate!r}")
    return parts[0], parts[1], parts[2]


def _require_hex_digest(value: Any, label: str) -> None:
    if (
        not isinstance(value, str)
        or len(value) != 64
        or any(character not in "0123456789abcdef" for character in value)
    ):
        raise UpdaterError(f"{label} must be a lowercase SHA-256 digest")


def _require_object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise UpdaterError(f"{label} must be a JSON object")
    return value


def _require_nonempty_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise UpdaterError(f"{label} must be a non-empty string")
    return value


def _require_positive_integer(value: Any, label: str) -> int:
    if type(value) is not int or value <= 0:
        raise UpdaterError(f"{label} must be a positive integer")
    return value


def _require_https_url(value: Any, label: str) -> str:
    url = _require_nonempty_string(value, label)
    parsed = urllib.parse.urlparse(url)
    if (
        parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username is not None
        or parsed.password is not None
    ):
        raise UpdaterError(f"{label} must use an HTTPS URL without credentials")
    return url


def _require_string_list(value: Any, label: str) -> list[str]:
    if (
        not isinstance(value, list)
        or any(
            not isinstance(item, str)
            or not item.strip()
            or "\n" in item
            or "\r" in item
            for item in value
        )
    ):
        raise UpdaterError(f"{label} must be a list of non-empty strings")
    if len(value) != len(set(value)):
        raise UpdaterError(f"{label} must not contain duplicates")
    return value


def _require_safe_archive_path(value: Any, label: str) -> str:
    raw_path = _require_nonempty_string(value, label)
    path = PurePosixPath(raw_path)
    if (
        path.is_absolute()
        or not path.parts
        or ".." in path.parts
        or "\\" in raw_path
        or path.as_posix() != raw_path
    ):
        raise UpdaterError(f"{label} must be a safe relative archive path")
    return raw_path


def load_catalog() -> dict[str, Any]:
    try:
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise UpdaterError(f"Unable to read {CATALOG_PATH}: {error}") from error
    if not isinstance(catalog, dict):
        raise UpdaterError(f"{CATALOG_PATH} must contain a JSON object")

    if (
        type(catalog.get("schema_version")) is not int
        or catalog["schema_version"] != 1
    ):
        raise UpdaterError(
            f"Unsupported catalog schema in {CATALOG_PATH}: "
            f"{catalog.get('schema_version')!r}"
        )

    scope = _require_object(catalog.get("scope"), "scope")
    if scope.get("core_sdk_only") is not True:
        raise UpdaterError("The catalog must declare its core-SDK-only scope")
    _require_https_url(
        scope.get("mediated_networks"), "scope.mediated_networks"
    )

    android = _require_object(catalog.get("android"), "android")
    minimum_sdk = _require_positive_integer(
        android.get("minimum_sdk"), "android.minimum_sdk"
    )
    target_sdk = _require_positive_integer(
        android.get("target_sdk"), "android.target_sdk"
    )
    if target_sdk < minimum_sdk:
        raise UpdaterError(
            "android.target_sdk must be greater than or equal to "
            "android.minimum_sdk"
        )
    for name in ("sdk", "consent"):
        dependency = _require_object(
            android.get(name), f"android.{name}"
        )
        coordinate = _require_nonempty_string(
            dependency.get("coordinate"), f"android.{name}.coordinate"
        )
        version = _require_nonempty_string(
            dependency.get("version"), f"android.{name}.version"
        )
        _, _, coordinate_version = parse_coordinate(
            coordinate
        )
        if coordinate_version != version:
            raise UpdaterError(
                f"Android {name} coordinate and version disagree"
            )
        for key in ("repository", "metadata_url", "artifact_url"):
            _require_https_url(
                dependency.get(key), f"android.{name}.{key}"
            )
        _require_hex_digest(
            dependency.get("artifact_sha256"),
            f"android.{name}.artifact_sha256",
        )
        _require_hex_digest(
            dependency.get("consumer_rules_sha256"),
            f"android.{name}.consumer_rules_sha256",
        )
        consumer_rules = _require_string_list(
            dependency.get("consumer_rules"),
            f"android.{name}.consumer_rules",
        )
        if not consumer_rules or not consumer_rules[0].startswith("-"):
            raise UpdaterError(
                f"android.{name}.consumer_rules must contain active rules"
            )
        if "release" in dependency:
            _require_https_url(
                dependency.get("release"), f"android.{name}.release"
            )

    ios = _require_object(catalog.get("ios"), "ios")
    _require_nonempty_string(
        ios.get("minimum_version"), "ios.minimum_version"
    )
    _require_nonempty_string(ios.get("version"), "ios.version")
    _require_nonempty_string(ios.get("pod"), "ios.pod")
    for key in ("podspec_url", "archive_url"):
        _require_https_url(ios.get(key), f"ios.{key}")
    _require_https_url(
        ios.get("skadnetwork_url"), "ios.skadnetwork_url"
    )
    skadnetwork_ids = _require_string_list(
        ios.get("skadnetwork_ids"), "ios.skadnetwork_ids"
    )
    if not skadnetwork_ids:
        raise UpdaterError("ios.skadnetwork_ids must not be empty")
    if skadnetwork_ids != sorted(skadnetwork_ids):
        raise UpdaterError("ios.skadnetwork_ids must be sorted")
    for identifier in skadnetwork_ids:
        if re.fullmatch(r"[a-z0-9]{10}\.skadnetwork", identifier) is None:
            raise UpdaterError(
                "ios.skadnetwork_ids contains an invalid identifier: "
                f"{identifier!r}"
            )
    if "release" in ios:
        _require_https_url(ios.get("release"), "ios.release")
    for key in (
        "podspec_sha256",
        "archive_sha256",
        "framework_info_sha256",
        "privacy_manifest_sha256",
    ):
        _require_hex_digest(ios.get(key), f"ios.{key}")
    _require_safe_archive_path(
        ios.get("device_framework_subpath"),
        "ios.device_framework_subpath",
    )
    _require_safe_archive_path(
        ios.get("simulator_framework_subpath"),
        "ios.simulator_framework_subpath",
    )
    resource_bundle = _require_object(
        ios.get("resource_bundle"), "ios.resource_bundle"
    )
    bundle_directory = _require_safe_archive_path(
        resource_bundle.get("directory"),
        "ios.resource_bundle.directory",
    )
    if "/" in bundle_directory:
        raise UpdaterError(
            "ios.resource_bundle.directory must be a directory name"
        )
    _require_hex_digest(
        resource_bundle.get("tree_sha256"),
        "ios.resource_bundle.tree_sha256",
    )
    _require_positive_integer(
        resource_bundle.get("file_count"),
        "ios.resource_bundle.file_count",
    )
    _require_nonempty_string(
        resource_bundle.get("omid_version"),
        "ios.resource_bundle.omid_version",
    )
    for key in (
        "frameworks",
        "weak_frameworks",
        "libraries",
        "compile_flags",
    ):
        _require_string_list(ios.get(key), f"ios.{key}")
    if "-fobjc-arc" not in ios["compile_flags"]:
        raise UpdaterError("ios.compile_flags must enable Objective-C ARC")

    sources = _require_object(catalog.get("sources"), "sources")
    for name, url in sources.items():
        _require_https_url(url, f"sources.{name}")

    return catalog


def write_or_check(path: Path, content: str, check: bool) -> bool:
    """Write generated text or print a unified diff in check mode."""

    if not content.endswith("\n"):
        content += "\n"

    if check:
        if not path.exists():
            print(f"missing generated file: {path}", file=sys.stderr)
            return False
        current = path.read_text(encoding="utf-8")
        if current == content:
            print(f"up to date: {path}")
            return True
        diff = difflib.unified_diff(
            current.splitlines(keepends=True),
            content.splitlines(keepends=True),
            fromfile=str(path),
            tofile=f"{path} (generated)",
        )
        sys.stderr.writelines(diff)
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"generated: {path}")
    return True


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_sha256(directory: Path) -> tuple[str, int]:
    """Hash a stable manifest of every file's relative path and SHA-256."""

    files = sorted(path for path in directory.rglob("*") if path.is_file())
    digest = hashlib.sha256()
    for path in files:
        relative_path = path.relative_to(directory).as_posix()
        line = f"{sha256_file(path)}  {relative_path}\n"
        digest.update(line.encode("utf-8"))
    return digest.hexdigest(), len(files)


def fetch_bytes(url: str, timeout: float, attempts: int = 3) -> bytes:
    if attempts <= 0:
        raise UpdaterError("fetch attempts must be greater than zero")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error: BaseException | None = None
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if 400 <= error.code < 500:
                raise UpdaterError(
                    f"Unable to fetch {url}: HTTP {error.code}"
                ) from error
            last_error = error
        except (OSError, urllib.error.URLError) as error:
            last_error = error
        if attempt < attempts:
            time.sleep(0.5 * attempt)
    raise UpdaterError(f"Unable to fetch {url}: {last_error}") from last_error


def fetch_json(url: str, timeout: float) -> dict[str, Any]:
    try:
        value = json.loads(fetch_bytes(url, timeout).decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise UpdaterError(f"Invalid JSON from {url}: {error}") from error
    if not isinstance(value, dict):
        raise UpdaterError(f"Expected a JSON object from {url}")
    return value


def fetch_maven_versions(
    metadata_url: str, timeout: float
) -> tuple[str | None, set[str]]:
    try:
        root = ET.fromstring(fetch_bytes(metadata_url, timeout))
    except ET.ParseError as error:
        raise UpdaterError(
            f"Invalid Maven metadata XML from {metadata_url}: {error}"
        ) from error
    release_node = root.find("./versioning/release")
    release = release_node.text if release_node is not None else None
    versions = {
        node.text
        for node in root.findall("./versioning/versions/version")
        if node.text
    }
    return release, versions


def normalize_aliases(
    argv: Sequence[str], commands: Sequence[str]
) -> list[str]:
    values = list(argv)
    aliases = {f"--{command}": command for command in commands}
    if values and values[0] in aliases:
        values[0] = aliases[values[0]]
    return values
