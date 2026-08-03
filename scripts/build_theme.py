#!/usr/bin/env python3
"""Compile ChromiumColor theme/folder-color pairs into load-unpacked manifests."""

from __future__ import annotations

import argparse
import colorsys
import json
import re
import shutil
import sys
import tempfile
import tomllib
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = ROOT / "themes.toml"
DEFAULT_OUTPUT = ROOT / "dist" / "chromiumcolor"
COLOR_PATTERN = re.compile(r"^#[0-9a-fA-F]{6}$")
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
VERSION_PATTERN = re.compile(r"^\d+(?:\.\d+){0,3}$")
REQUIRED_THEME_KEYS = {
    "name",
    "description",
    "mode",
    "frame",
    "toolbar",
    "foreground",
    "muted",
    "accent",
    "default_folder_color",
}
EXPECTED_SLOTS = [
    "grey",
    "blue",
    "red",
    "yellow",
    "green",
    "pink",
    "purple",
    "cyan",
    "orange",
]


class CatalogError(ValueError):
    """Raised when themes.toml does not satisfy the generator contract."""


def load_catalog() -> dict[str, Any]:
    try:
        with CATALOG_PATH.open("rb") as catalog_file:
            catalog = tomllib.load(catalog_file)
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise CatalogError(f"could not read {CATALOG_PATH.name}: {error}") from error
    validate_catalog(catalog)
    return catalog


def validate_catalog(catalog: dict[str, Any]) -> None:
    project = catalog.get("project")
    themes = catalog.get("themes")
    folder_colors = catalog.get("folder_colors")
    if not isinstance(project, dict):
        raise CatalogError("missing [project] table")
    if not isinstance(themes, dict) or not themes:
        raise CatalogError("at least one [themes.<id>] table is required")
    if not isinstance(folder_colors, dict) or not folder_colors:
        raise CatalogError("at least one [folder_colors.<id>] table is required")

    for key in ("name", "version", "default_theme"):
        if not isinstance(project.get(key), str) or not project[key].strip():
            raise CatalogError(f"project.{key} must be a non-empty string")
    if not VERSION_PATTERN.fullmatch(project["version"]):
        raise CatalogError("project.version must contain one to four numeric components")
    if project["default_theme"] not in themes:
        raise CatalogError("project.default_theme does not reference a defined theme")

    for theme_id, theme in themes.items():
        if not ID_PATTERN.fullmatch(theme_id):
            raise CatalogError(f"invalid theme ID: {theme_id!r}")
        if not isinstance(theme, dict):
            raise CatalogError(f"themes.{theme_id} must be a table")
        missing = REQUIRED_THEME_KEYS - theme.keys()
        if missing:
            raise CatalogError(
                f"themes.{theme_id} is missing: {', '.join(sorted(missing))}"
            )
        if theme["mode"] not in {"dark", "light"}:
            raise CatalogError(f"themes.{theme_id}.mode must be 'dark' or 'light'")
        for key in ("name", "description"):
            if not isinstance(theme[key], str) or not theme[key].strip():
                raise CatalogError(f"themes.{theme_id}.{key} must be a non-empty string")
        for key in ("frame", "toolbar", "foreground", "muted", "accent"):
            if not isinstance(theme[key], str) or not COLOR_PATTERN.fullmatch(theme[key]):
                raise CatalogError(f"themes.{theme_id}.{key} must be a #rrggbb color")
        if theme["default_folder_color"] not in folder_colors:
            raise CatalogError(
                f"themes.{theme_id}.default_folder_color references an unknown palette"
            )

    for folder_id, folder in folder_colors.items():
        if not ID_PATTERN.fullmatch(folder_id):
            raise CatalogError(f"invalid folder-color ID: {folder_id!r}")
        if not isinstance(folder, dict):
            raise CatalogError(f"folder_colors.{folder_id} must be a table")
        for key in ("name", "description"):
            if not isinstance(folder.get(key), str) or not folder[key].strip():
                raise CatalogError(
                    f"folder_colors.{folder_id}.{key} must be a non-empty string"
                )
        if not isinstance(folder.get("base_color"), str) or not COLOR_PATTERN.fullmatch(
            folder["base_color"]
        ):
            raise CatalogError(
                f"folder_colors.{folder_id}.base_color must be a #rrggbb color"
            )
        slots = folder.get("slots")
        hues = folder.get("hues")
        if slots != EXPECTED_SLOTS:
            raise CatalogError(
                f"folder_colors.{folder_id}.slots must be {EXPECTED_SLOTS!r}"
            )
        if (
            not isinstance(hues, list)
            or len(hues) != len(EXPECTED_SLOTS)
            or any(type(hue) is not int or not 0 <= hue <= 359 for hue in hues)
        ):
            raise CatalogError(
                f"folder_colors.{folder_id}.hues must contain nine integers from 0 to 359"
            )
        middle_hue = hues[len(hues) // 2]
        base_hue = hue(folder["base_color"])
        hue_difference = abs(base_hue - middle_hue)
        if min(hue_difference, 360 - hue_difference) > 6:
            raise CatalogError(
                f"folder_colors.{folder_id}.base_color has hue {base_hue}, "
                f"which does not match middle hue {middle_hue}"
            )


def rgb(hex_color: str) -> list[int]:
    return [int(hex_color[index : index + 2], 16) for index in (1, 3, 5)]


def hue(hex_color: str) -> int:
    red, green, blue = (channel / 255 for channel in rgb(hex_color))
    color_hue, _, _ = colorsys.rgb_to_hsv(red, green, blue)
    return round(color_hue * 360) % 360


def make_manifest(
    catalog: dict[str, Any], theme_id: str, folder_id: str
) -> dict[str, Any]:
    themes = catalog["themes"]
    folders = catalog["folder_colors"]
    if theme_id not in themes:
        raise CatalogError(
            f"unknown theme {theme_id!r}; choose one of: {', '.join(themes)}"
        )
    if folder_id not in folders:
        raise CatalogError(
            f"unknown folder color {folder_id!r}; choose one of: {', '.join(folders)}"
        )

    project = catalog["project"]
    theme = themes[theme_id]
    folder = folders[folder_id]
    frame = rgb(theme["frame"])
    toolbar = rgb(theme["toolbar"])
    foreground = rgb(theme["foreground"])
    muted = rgb(theme["muted"])
    accent = rgb(theme["accent"])
    tab_group_palette = {
        f"{slot}_override": hue
        for slot, hue in zip(folder["slots"], folder["hues"], strict=True)
    }

    return {
        "version": project["version"],
        "name": f"{project['name']} — {theme['name']} / {folder['name']}",
        "description": (
            f"{theme['description']} {folder['name']} colors apply only to tab groups."
        ),
        "manifest_version": 3,
        "theme": {
            "colors": {
                "frame": frame,
                "frame_inactive": frame,
                "bookmark_text": foreground,
                "button_background": frame,
                "tab_background_text": muted,
                "tab_background_text_inactive": muted,
                "tab_text": foreground,
                "toolbar": toolbar,
                "toolbar_button_icon": foreground,
                "toolbar_text": foreground,
                "frame_incognito": frame,
                "frame_incognito_inactive": frame,
                "tab_background_text_incognito": foreground,
                "tab_background_text_incognito_inactive": muted,
                "omnibox_text": accent,
                "omnibox_background": frame,
                "ntp_background": frame,
                "ntp_header": toolbar,
                "ntp_link": accent,
                "ntp_text": muted,
            },
            "tab_group_color_palette": tab_group_palette,
            "tints": {
                "buttons": [-1, -1, -1],
                "frame": [-1, -1, -1],
                "frame_inactive": [-1, -1, -1],
                "frame_incognito": [-1, -1, -1],
                "frame_incognito_inactive": [-1, -1, -1],
            },
            "properties": {"ntp_logo_alternate": 1 if theme["mode"] == "dark" else 0},
        },
    }


def validate_manifest(manifest: dict[str, Any]) -> None:
    if manifest.get("manifest_version") != 3:
        raise CatalogError("generated manifest is not Manifest V3")
    if not isinstance(manifest.get("name"), str) or len(manifest["name"]) > 75:
        raise CatalogError("generated manifest name exceeds Chromium's 75-character limit")
    if (
        not isinstance(manifest.get("description"), str)
        or len(manifest["description"]) > 132
    ):
        raise CatalogError(
            "generated manifest description exceeds Chromium's 132-character limit"
        )
    colors = manifest.get("theme", {}).get("colors", {})
    for key, value in colors.items():
        if (
            not isinstance(value, list)
            or len(value) != 3
            or any(type(channel) is not int or not 0 <= channel <= 255 for channel in value)
        ):
            raise CatalogError(f"generated theme.colors.{key} is not a valid RGB triplet")
    palette = manifest.get("theme", {}).get("tab_group_color_palette", {})
    if set(palette) != {f"{slot}_override" for slot in EXPECTED_SLOTS}:
        raise CatalogError("generated tab-group palette has the wrong slots")


def write_manifest(manifest: dict[str, Any], output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / "manifest.json"
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=output_dir, delete=False
    ) as temporary_file:
        json.dump(manifest, temporary_file, indent=2)
        temporary_file.write("\n")
        temporary_path = Path(temporary_file.name)
    temporary_path.replace(destination)
    return destination


def print_catalog(catalog: dict[str, Any]) -> None:
    print("Themes:")
    for theme_id, theme in catalog["themes"].items():
        print(f"  {theme_id:<14} default: {theme['default_folder_color']}")
    print("\nFolder colors (tab groups only):")
    for folder_id, folder in catalog["folder_colors"].items():
        middle_hue = folder["hues"][len(folder["hues"]) // 2]
        print(f"  {folder_id:<14} ~{folder['base_color'].lower()} ({middle_hue}°)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--list", action="store_true", help="list catalog choices")
    action.add_argument("--check", action="store_true", help="validate every combination")
    action.add_argument("--clean", action="store_true", help="remove generated output")
    parser.add_argument(
        "selection",
        nargs="*",
        metavar="CHOICE",
        help="optional theme ID followed by an optional folder-color ID",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="output directory")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if len(args.selection) > 2:
        raise CatalogError("usage: just build [theme] [folder-color]")
    if (args.list or args.check or args.clean) and args.selection:
        raise CatalogError("catalog actions do not accept theme or folder-color choices")
    if args.clean:
        if (ROOT / "dist").exists():
            shutil.rmtree(ROOT / "dist")
        print("Removed dist/.")
        return 0

    catalog = load_catalog()
    if args.list:
        print_catalog(catalog)
        return 0

    if args.check:
        combinations = 0
        for theme_id in catalog["themes"]:
            baseline_theme: dict[str, Any] | None = None
            for folder_id in catalog["folder_colors"]:
                manifest = make_manifest(catalog, theme_id, folder_id)
                validate_manifest(manifest)
                generated_theme = dict(manifest["theme"])
                generated_theme.pop("tab_group_color_palette")
                if baseline_theme is None:
                    baseline_theme = generated_theme
                elif generated_theme != baseline_theme:
                    raise CatalogError(
                        f"folder color {folder_id!r} changes non-tab-group values for "
                        f"theme {theme_id!r}"
                    )
                combinations += 1
        print(f"Validated {combinations} theme/folder-color combinations.")
        return 0

    theme_id = args.selection[0] if args.selection else catalog["project"]["default_theme"]
    if theme_id not in catalog["themes"]:
        raise CatalogError(
            f"unknown theme {theme_id!r}; choose one of: {', '.join(catalog['themes'])}"
        )
    folder_id = (
        args.selection[1]
        if len(args.selection) == 2
        else catalog["themes"][theme_id]["default_folder_color"]
    )
    manifest = make_manifest(catalog, theme_id, folder_id)
    validate_manifest(manifest)
    destination = write_manifest(manifest, args.output)
    print(f"Built {theme_id} + {folder_id}: {destination.relative_to(ROOT)}")
    print(f"Load unpacked: {args.output.resolve()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except CatalogError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2) from error
