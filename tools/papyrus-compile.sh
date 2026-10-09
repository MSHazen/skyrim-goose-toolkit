#!/bin/bash
# Papyrus Compiler Wrapper for Linux + Proton/Wine
#
# Uses the official Creation Kit PapyrusCompiler.exe through Proton's wine64.
# Requires Amethyst symlink deployment (so Data/Scripts/Source contains all
# mod script imports via symlinks).
#
# Usage:
#   bash tools/papyrus-compile.sh <input.psc> [output-dir]
#   bash tools/papyrus-compile.sh <folder> -all
#
# Environment overrides:
#   SKYRIM_GAME_ROOT  -> path to Skyrim Special Edition (default: auto-detected)
#   WINEPREFIX        -> Wine prefix for Proton (default: auto-detected from Amethyst)
#
# The compiler import path is always Data/Scripts/Source/ (symlink farm).
# The compiler output path is always Data/Scripts/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_ROOT="${SKYRIM_GAME_ROOT:-}"
WINEPREFIX="${WINEPREFIX:-}"

# --- Auto-detect from Amethyst if not set ---
if [ -z "$GAME_ROOT" ] || [ -z "$WINEPREFIX" ]; then
    if [ -f "$SCRIPT_DIR/../.local/config/skyrim-paths.env" ]; then
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/../.local/config/skyrim-paths.env"
    fi
fi

# Fallback: try the toolkit's Amethyst detector
if [ -z "$GAME_ROOT" ]; then
    AMETHYST_JSON=$(python3 "$SCRIPT_DIR/amethyst-paths.py" 2>/dev/null || echo '{"game_path":""}')
    GAME_ROOT=$(echo "$AMETHYST_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin).get('game_path',''))")
fi

if [ -z "$GAME_ROOT" ] || [ ! -d "$GAME_ROOT" ]; then
    echo "ERROR: Could not detect Skyrim game root."
    echo "Set SKYRIM_GAME_ROOT or run setup-linux.sh first."
    exit 1
fi

COMPILER_DIR="$GAME_ROOT/Papyrus Compiler"
COMPILER="$COMPILER_DIR/PapyrusCompiler.exe"
FLAGS="$COMPILER_DIR/TESV_Papyrus_Flags.flg"
IMPORT="$GAME_ROOT/Data/Scripts/Source"
OUTPUT="$GAME_ROOT/Data/Scripts"

if [ ! -f "$COMPILER" ]; then
    echo "ERROR: PapyrusCompiler.exe not found at $COMPILER"
    echo "Install the Creation Kit or ensure the game directory is complete."
    exit 1
fi

# --- Resolve Proton wine binary ---
# Try common Steam Proton paths, falling back to plain 'wine64'
PROTON_WINE=""
for p in \
    "$HOME/.local/share/Steam/steamapps/common/Proton 10.0/files/bin/wine64" \
    "$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/files/bin/wine64" \
    "$HOME/.steam/steam/steamapps/common/Proton 10.0/files/bin/wine64" \
    "$HOME/.steam/root/steamapps/common/Proton 10.0/files/bin/wine64"; do
    if [ -x "$p" ]; then PROTON_WINE="$p"; break; fi
done

if [ -z "$PROTON_WINE" ]; then
    if command -v wine64 >/dev/null 2>&1; then
        PROTON_WINE="wine64"
    else
        echo "ERROR: No wine64 found. Install Wine or Proton."
        exit 1
    fi
fi

# --- Wine prefix ---
if [ -z "$WINEPREFIX" ]; then
    # Derive from game path: <steamapps>/compatdata/<appid>/pfx
    if [[ "$GAME_ROOT" == */steamapps/common/* ]]; then
        COMPATDATA="${GAME_ROOT%/common/*}/compatdata"
        # Try to find the appid directory (489830 = Skyrim SE)
        for appid in 489830 72850 1716740; do
            if [ -d "$COMPATDATA/$appid/pfx" ]; then
                WINEPREFIX="$COMPATDATA/$appid/pfx"
                break
            fi
        done
    fi
fi

if [ -z "$WINEPREFIX" ] || [ ! -d "$WINEPREFIX" ]; then
    echo "WARNING: WINEPREFIX not found. Using default Wine prefix."
    WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
fi

# --- Convert Linux paths to Wine Z:\ paths ---
# Wine sees the Linux root as Z:\, so /home/user/file -> Z:\home\user\file
# The game root itself should be referenced from inside Wine
wine_path() {
    printf 'Z:%s' "$(printf '%s' "$1" | tr '/' '\\')"
}

WINE_COMPILER=$(wine_path "$COMPILER")
WINE_IMPORT=$(wine_path "$IMPORT")
WINE_OUTPUT=$(wine_path "$OUTPUT")

# SSE PapyrusCompiler generally does NOT need the old TESV flags file.
# Only pass -f if a valid flags file exists (check by attempting parse, or skip).
FLAGS_ARG=""
if [ -f "$FLAGS" ]; then
    # The old TESV_Papyrus_Flags.flg causes "no viable alternative" errors on SSE.
    # Only use -f if the file looks like binary/compiler metadata, not text "Flag ..." lines.
    if ! head -n1 "$FLAGS" | grep -q "^Flag "; then
        FLAGS_BASENAME="$(basename "$FLAGS")"
        FLAGS_ARG="-f=\"$FLAGS_BASENAME\""
    fi
fi

# --- Input validation ---
INPUT="${1:-}"
if [ -z "$INPUT" ]; then
    echo "Usage: bash tools/papyrus-compile.sh <input.psc|folder> [output-dir]"
    echo "       bash tools/papyrus-compile.sh <folder> -all"
    exit 1
fi

# If input is a bare name (no path), check if it exists in the import path
if [ ! -e "$INPUT" ] && [ -f "$IMPORT/$INPUT.psc" ]; then
    INPUT="$IMPORT/$INPUT.psc"
fi

# If still not found, try relative to current dir
if [ ! -e "$INPUT" ]; then
    if [ -e "$(pwd)/$INPUT" ]; then
        INPUT="$(pwd)/$INPUT"
    else
        echo "ERROR: Input not found: $INPUT (also checked $IMPORT/$INPUT.psc)"
        exit 1
    fi
fi

WINE_INPUT=$(wine_path "$INPUT")

# Optional: custom output directory
if [ -n "${2:-}" ]; then
    WINE_OUTPUT=$(wine_path "$2")
fi

# --- Build command ---
# PapyrusCompiler <input> -f=<flags> -i=<import> -o=<output>
CMD="\"$WINE_COMPILER\" \"$WINE_INPUT\" ${FLAGS_ARG:-} -i=\"$WINE_IMPORT\" -o=\"$WINE_OUTPUT\""

# Check if -all should be passed (when input is a folder)
if [ -d "$INPUT" ]; then
    CMD="$CMD -all"
    echo "Compiling ALL scripts in folder: $INPUT"
else
    echo "Compiling: $INPUT"
fi

echo "  Wine binary: $PROTON_WINE"
echo "  WINEPREFIX:  $WINEPREFIX"
echo "  Import path: $IMPORT"
echo "  Output path: $OUTPUT"
echo ""

# --- Run ---
export WINEDEBUG=-all
export WINEPREFIX="$WINEPREFIX"

# Run from the compiler's directory so it resolves any relative paths
cd "$COMPILER_DIR"
"$PROTON_WINE" "$WINE_COMPILER" "$WINE_INPUT" $FLAGS_ARG -i="$WINE_IMPORT" -o="$WINE_OUTPUT" ${EXTRA_ARGS:-}
