#!/bin/bash
# Skyrim Goose Toolkit -- Linux Setup Script
#
# Configures the toolkit for an immutable Linux system running Amethyst Mod Manager.
# Does NOT auto-install dependencies (winget is unavailable); instead it detects what
# you have and prints install commands for your package manager / Flatpak / container.
#
# Usage: bash setup-linux.sh [--game "Skyrim Special Edition"]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_NAME="Skyrim Special Edition"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --game) GAME_NAME="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "============================================"
echo " Skyrim Goose Toolkit -- Linux Setup"
echo "============================================"
echo ""
echo "Game:        $GAME_NAME"
echo "Script dir:  $SCRIPT_DIR"
echo ""

# --- Verify toolkit files are present ---
if [ ! -f "$SCRIPT_DIR/KNOWLEDGEBASE.md" ] || [ ! -f "$SCRIPT_DIR/tools/amethyst-paths.py" ]; then
    echo "ERROR: Toolkit files not found."
    echo "Make sure you cloned or extracted the toolkit and are running setup-linux.sh from its root."
    exit 1
fi

# --- Detect Amethyst ---
echo "Detecting Amethyst Mod Manager paths..."
AMETHYST_JSON=$(python3 "$SCRIPT_DIR/tools/amethyst-paths.py" "$GAME_NAME")
if ! echo "$AMETHYST_JSON" | jq -e '.ok' >/dev/null 2>&1; then
    echo "ERROR: Amethyst detection failed:"
    echo "$AMETHYST_JSON" | jq -r '.error'
    echo ""
    echo "If Amethyst is installed under a different game name, pass it:"
    echo "  bash setup-linux.sh --game \"Skyrim VR\""
    exit 1
fi

GAME_PATH=$(echo "$AMETHYST_JSON" | jq -r '.game_path // empty')
DATA_PATH=$(echo "$AMETHYST_JSON" | jq -r '.data_path // empty')
PROFILE_DIR=$(echo "$AMETHYST_JSON" | jq -r '.profile_dir // empty')
MODS_DIR=$(echo "$AMETHYST_JSON" | jq -r '.mods_dir // empty')
OVERWRITE_DIR=$(echo "$AMETHYST_JSON" | jq -r '.overwrite_dir // empty')
PREFIX_PATH=$(echo "$AMETHYST_JSON" | jq -r '.prefix_path // empty')
MY_GAMES=$(echo "$AMETHYST_JSON" | jq -r '.my_games // empty')
PLUGINS_TXT=$(echo "$AMETHYST_JSON" | jq -r '.plugins_txt // empty')

if [ -z "$PROFILE_DIR" ]; then
    echo "WARNING: No deployed profile detected."
    echo "  last_active_profile: $(echo "$AMETHYST_JSON" | jq -r '.last_active_profile // empty')"
    echo "  last_deployed:       $(echo "$AMETHYST_JSON" | jq -r '.last_deployed // empty')"
    echo ""
    echo "Deploy a profile in Amethyst first, or set AMETHYST_PROFILE manually."
fi

echo "  Game path:    $GAME_PATH"
echo "  Data path:    $DATA_PATH"
echo "  Profile:      $PROFILE_DIR"
echo "  Mods:         $MODS_DIR"
echo "  Overwrite:    $OVERWRITE_DIR"
echo "  Wine prefix:  $PREFIX_PATH"
echo "  My Games:     $MY_GAMES"
echo ""

# --- Check dependencies ---
echo "Checking dependencies..."

_missing_deps=()

command -v jq >/dev/null 2>&1 || _missing_deps+=("jq")
command -v node >/dev/null 2>&1 || _missing_deps+=("nodejs")
command -v python3 >/dev/null 2>&1 || _missing_deps+=("python3")
command -v java >/dev/null 2>&1 || _missing_deps+=("openjdk")

# .NET is optional (Spriggit, AutoMod)
if command -v dotnet >/dev/null 2>&1; then
    if dotnet --list-sdks 2>/dev/null | grep -qE "^(9|1[0-9])\."; then
        echo "  .NET 9+ SDK:  present"
    else
        echo "  .NET 9+ SDK:  MISSING (Spriggit will not work)"
        _missing_deps+=("dotnet-sdk-9")
    fi
else
    echo "  .NET:         MISSING (Spriggit, AutoMod unavailable)"
    _missing_deps+=("dotnet")
fi

# Docker is optional (devcontainer)
if command -v docker >/dev/null 2>&1; then
    echo "  Docker:       present"
else
    echo "  Docker:       not found (devcontainer workflows unavailable)"
fi

# Wine is optional (SSEEdit scripting, Papyrus compilation)
if command -v wine >/dev/null 2>&1; then
    echo "  Wine:         present"
else
    echo "  Wine:         not found (SSEEdit/Caprica via Wine unavailable)"
fi

if [ ${#_missing_deps[@]} -gt 0 ]; then
    echo ""
    echo "MISSING DEPENDENCIES:"
    for dep in "${_missing_deps[@]}"; do
        case "$dep" in
            jq)          echo "  jq            -> flatpak install flathub app.getjq.jq  OR  distro package" ;;
            nodejs)      echo "  Node.js       -> https://nodejs.org  OR  flatpak  OR  linuxbrew" ;;
            python3)     echo "  Python 3      -> usually pre-installed; otherwise distro package" ;;
            openjdk)     echo "  OpenJDK 17+   -> flatpak install flathub org.freedesktop.Sdk.Extension.openjdk  OR  distro package" ;;
            dotnet)      echo "  .NET SDK      -> https://dotnet.microsoft.com  OR  distrobox" ;;
            dotnet-sdk-9) echo "  .NET 9 SDK    -> https://dotnet.microsoft.com  OR  distrobox" ;;
        esac
    done
    echo ""
    echo "On an immutable Linux system, typical paths are:"
    echo "  Flatpak:    flatpak install flathub <ref>"
    echo "  Distrobox:  distrobox create --image fedora:latest  &&  distrobox enter <name>"
    echo "  Homebrew:   brew install <formula>"
    echo ""
    echo "Setup will continue with path configuration. Install missing deps when needed."
    echo ""
fi

# --- Write path configuration ---
# Machine-specific paths are stored PROJECT-LOCAL so users have one place to look,
# but they are gitignored and never committed.
RUNTIME_DIR="$SCRIPT_DIR/.local/config"
mkdir -p "$RUNTIME_DIR"

ENV_FILE="$RUNTIME_DIR/skyrim-paths.env"

cat > "$ENV_FILE" <<EOF
# Generated by setup-linux.sh for Amethyst / immutable Linux.
# Source this file before running toolkit tools:
#   source .local/config/skyrim-paths.env
SKYRIM_GAME_ROOT="$GAME_PATH"
SKYRIM_DATA_DIR="$DATA_PATH"
SKYRIM_PROFILE_DIR="$PROFILE_DIR"
SKYRIM_MODS_DIR="$MODS_DIR"
SKYRIM_OVERWRITE_DIR="$OVERWRITE_DIR"
SKYRIM_WINE_PREFIX="$PREFIX_PATH"
SKYRIM_DOCUMENTS="${MY_GAMES%/My Games}"
SKYRIM_MY_GAMES="$MY_GAMES"
SKYRIM_PLUGINS_TXT="$PLUGINS_TXT"
SKYRIM_GAME_NAME="$GAME_NAME"
EOF

echo "Path configuration written to:"
echo "  $ENV_FILE"
echo ""

# --- Ensure backup directory exists (project-local, gitignored) ---
mkdir -p "$SCRIPT_DIR/.local/backups"

# --- Update devcontainer.json if Docker is present ---
DC_JSON="$SCRIPT_DIR/.devcontainer/devcontainer.json"
if [ -f "$DC_JSON" ] && command -v docker >/dev/null 2>&1; then
    echo "Updating .devcontainer/devcontainer.json with Amethyst mount sources..."
    # Backup original
    cp "$DC_JSON" "$DC_JSON.bak"
    # Use jq to replace mount sources. The devcontainer.json shipped by upstream has
    # placeholder paths like "{{SKYRIM_MODS_DIR}}" which we substitute with real ones.
    # We only touch mounts that already exist in the file.
    _jq_tmp=$(mktemp)
    jq --arg mods "$MODS_DIR" \
       --arg profile "$PROFILE_DIR" \
       --arg overwrite "$OVERWRITE_DIR" \
       '
       .mounts |= map(
         if .target == "/skyrim/mods" then .source = $mods
         elif .target == "/skyrim/profile" then .source = $profile
         elif .target == "/skyrim/overwrite" then .source = $overwrite
         else . end
       )
       ' "$DC_JSON" > "$_jq_tmp" && mv "$_jq_tmp" "$DC_JSON"
    echo "  Done."
    echo ""
fi

# --- Safety reminder ---
echo "============================================"
echo " Setup complete."
echo "============================================"
echo ""
echo "IMPORTANT: This fork runs WITHOUT Claude Code's safety hooks."
echo "You MUST enforce these rules manually:"
echo ""
echo "  1. NEVER write directly to .esp / .esm / .esl / .bsa / .ba2 files."
echo "     Use Spriggit (serialize -> edit YAML -> deserialize) or SSEEdit."
echo "  2. Back up files before editing (e.g. .local/backups/)."
echo "  3. State confidence level and show changes before applying."
echo "  4. On immutable Linux: install heavy deps (JDK, .NET) via Flatpak,"
echo "     distrobox, or the devcontainer — never layer onto the host."
echo ""
echo "Next steps:"
echo "  - Install missing dependencies (see above)."
echo "  - Download ReSaver.jar + lib/ into tools/resaver-cli/ for save analysis."
echo "  - If you have Docker: run ./devshell-docker.sh for an isolated dev env."
echo "  - Source the env file before running tools:"
echo "      source .local/config/skyrim-paths.env"
echo ""
