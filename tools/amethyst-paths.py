#!/usr/bin/env python3
"""Amethyst Mod Manager path detector for the Skyrim Goose Toolkit.

Reads Amethyst's per-game configuration (~/.config/AmethystModManager/games/)
and emits the path variables the toolkit expects. Used in place of the
Windows-centric MO2/Vortex detection in setup.sh.

Usage:
  python3 tools/amethyst-paths.py [--game "Skyrim Special Edition"]

Emits JSON on stdout:
  {
    "game_path": "/path/to/Skyrim Special Edition",
    "data_path": "/path/to/Skyrim Special Edition/Data",
    "profile_dir": "/path/to/Amethyst/.../profiles/<active_profile>/",
    "mods_dir": "/path/to/Amethyst/.../profiles/<active_profile>/mods/",
    "overwrite_dir": "/path/to/Amethyst/.../profiles/<active_profile>/overwrite/",
    "prefix_path": "/path/to/steam/compatdata/.../pfx",
    "wine_documents": "/path/to/steam/compatdata/.../pfx/drive_c/users/.../Documents",
    "my_games": "/path/to/steam/.../pfx/drive_c/users/.../Documents/My Games",
    "plugins_txt": "/path/to/Amethyst/.../profiles/<active_profile>/plugins.txt",
    "deploy_active": true,
    "last_deployed": "profile_name",
    "last_active_profile": "profile_name"
  }

All paths use forward slashes. Wine prefix paths are resolved from the
prefix_path in Amethyst's paths.json if present; otherwise the caller must
set SKYRIM_WINE_PREFIX or SKYRIM_DOCUMENTS to override.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

AMETHYST_CONFIG_ROOT = Path.home() / ".config" / "AmethystModManager" / "games"


def find_amethyst_config(game_name: str = "Skyrim Special Edition") -> Path | None:
    """Return the Amethyst config directory for the given game, if it exists."""
    candidate = AMETHYST_CONFIG_ROOT / game_name
    if candidate.is_dir():
        return candidate
    # Fuzzy fallback: case-insensitive match
    if AMETHYST_CONFIG_ROOT.is_dir():
        for child in AMETHYST_CONFIG_ROOT.iterdir():
            if child.is_dir() and child.name.lower() == game_name.lower():
                return child
    return None


def resolve_prefix_documents(prefix_path: Path) -> Path | None:
    """Walk a Wine prefix to find the user's Documents folder."""
    if not prefix_path.is_dir():
        return None
    # Typical Proton/Wine layout: .../pfx/drive_c/users/<username>/Documents
    drive_c = prefix_path / "drive_c"
    if not drive_c.is_dir():
        return None
    users = drive_c / "users"
    if not users.is_dir():
        return None
    # Try current username first, then common fallback names
    for name in [os.environ.get("USER", ""), os.environ.get("USERNAME", ""), "steamuser", os.getlogin()]:
        if not name:
            continue
        docs = users / name / "Documents"
        if docs.is_dir():
            return docs
    # If nothing matched, grab the first user directory that has Documents
    for user_dir in sorted(users.iterdir()):
        if user_dir.is_dir():
            docs = user_dir / "Documents"
            if docs.is_dir():
                return docs
    return None


def main() -> int:
    game_name = "Skyrim Special Edition"
    if len(sys.argv) > 1:
        if sys.argv[1] in ("-h", "--help"):
            print(__doc__)
            return 0
        game_name = sys.argv[1]

    env_override = os.environ.get("AMETHYST_GAME")
    if env_override:
        game_name = env_override

    cfg_dir = find_amethyst_config(game_name)
    if cfg_dir is None:
        print(json.dumps({
            "ok": False,
            "error": f"Amethyst config not found for '{game_name}' under {AMETHYST_CONFIG_ROOT}"
        }))
        return 1

    paths_file = cfg_dir / "paths.json"
    deploy_file = cfg_dir / "deploy_state.json"

    paths: dict[str, str | bool | None] = {"ok": True, "manager": "amethyst"}

    if paths_file.is_file():
        with open(paths_file, "r", encoding="utf-8") as f:
            paths_cfg = json.load(f)
        game_path = Path(paths_cfg.get("game_path", ""))
        staging_path = Path(paths_cfg.get("staging_path", ""))
        prefix_path_str = paths_cfg.get("prefix_path", "")
        prefix_path = Path(prefix_path_str) if prefix_path_str else None

        paths["game_path"] = str(game_path) if game_path.is_dir() else None
        paths["data_path"] = str(game_path / "Data") if (game_path / "Data").is_dir() else None
        paths["prefix_path"] = str(prefix_path) if prefix_path and prefix_path.is_dir() else None
        paths["deploy_mode"] = paths_cfg.get("deploy_mode", "unknown")

        # Resolve Documents/My Games inside the Wine prefix
        docs_override = os.environ.get("SKYRIM_DOCUMENTS")
        if docs_override:
            paths["wine_documents"] = docs_override
            paths["my_games"] = str(Path(docs_override) / "My Games")
        elif prefix_path:
            docs = resolve_prefix_documents(prefix_path)
            if docs:
                paths["wine_documents"] = str(docs)
                paths["my_games"] = str(docs / "My Games")

        # Save path override (if user set a custom save directory in Amethyst)
        save_override = paths_cfg.get("save_path_override", "")
        if save_override:
            paths["save_path_override"] = save_override
    else:
        print(json.dumps({
            "ok": False,
            "error": f"paths.json not found in {cfg_dir}"
        }))
        return 1

    if deploy_file.is_file():
        with open(deploy_file, "r", encoding="utf-8") as f:
            deploy = json.load(f)
        profile = deploy.get("last_deployed", deploy.get("last_active_profile", ""))
        paths["last_deployed"] = deploy.get("last_deployed")
        paths["last_active_profile"] = deploy.get("last_active_profile")
        paths["deploy_active"] = deploy.get("deploy_active", False)

        if profile and staging_path:
            profile_dir = staging_path / "profiles" / profile
            if profile_dir.is_dir():
                paths["profile_dir"] = str(profile_dir)
                mods_dir = profile_dir / "mods"
                paths["mods_dir"] = str(mods_dir) if mods_dir.is_dir() else None
                overwrite_dir = profile_dir / "overwrite"
                paths["overwrite_dir"] = str(overwrite_dir) if overwrite_dir.is_dir() else None
                plugins_txt = profile_dir / "plugins.txt"
                paths["plugins_txt"] = str(plugins_txt) if plugins_txt.is_file() else None
    else:
        # If no deploy_state.json, fall back to listing available profiles
        profiles_dir = staging_path / "profiles" if "staging_path" in locals() else None
        if profiles_dir and profiles_dir.is_dir():
            profiles = [p.name for p in profiles_dir.iterdir() if p.is_dir()]
            paths["available_profiles"] = profiles

    # Filter out None values for cleaner output
    paths = {k: v for k, v in paths.items() if v is not None}
    print(json.dumps(paths, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
