#!/bin/bash
# Goose Session Start — run this at the beginning of each working session
# to load paths and verify toolkit health.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the environment
if [ -f "$SCRIPT_DIR/.local/config/skyrim-paths.env" ]; then
    source "$SCRIPT_DIR/.local/config/skyrim-paths.env"
    echo "✅ Environment loaded from .local/config/skyrim-paths.env"
else
    echo "❌ Config not found. Run: bash setup-linux.sh"
    exit 1
fi

# Verify key paths
errors=0
for var in SKYRIM_GAME_ROOT SKYRIM_DATA_DIR SKYRIM_PROFILE_DIR SKYRIM_MODS_DIR SKYRIM_WINE_PREFIX; do
    path="${!var}"
    if [ -z "$path" ]; then
        echo "❌ $var not set"
        errors=$((errors+1))
    elif [ ! -d "$path" ]; then
        echo "⚠️  $var=$path (not a directory)"
    else
        echo "✅ $var=$path"
    fi
done

# Check tools
echo ""
echo "=== Toolkit Tools ==="
for tool in tools/crash-triage.py tools/papyrus-triage.py tools/amethyst-paths.py \
            tools/resaver-cli.sh tools/papyrus-compile.sh tools/devbench-cli.sh; do
    if [ -f "$SCRIPT_DIR/$tool" ]; then
        echo "✅ $tool"
    else
        echo "❌ $tool missing"
        errors=$((errors+1))
    fi
done

# Check JDK (for ReSaver)
if command -v java >/dev/null 2>&1; then
    echo "✅ JDK: $(java -version 2>&1 | head -n1)"
else
    echo "⚠️  JDK not found (ReSaver will not work)"
fi

# Check ReSaver jar
if [ -f "$SCRIPT_DIR/tools/resaver-cli/ReSaver.jar" ]; then
    echo "✅ ReSaver.jar present"
else
    echo "⚠️  ReSaver.jar missing — download from Nexus 5031"
fi

# Check Node.js (for xelib scripts)
if command -v node >/dev/null 2>&1; then
    echo "✅ Node.js: $(node --version)"
else
    echo "⚠️  Node.js missing (xelib scripts won't run)"
fi

echo ""
if [ $errors -eq 0 ]; then
    echo "=== All checks passed. Toolkit is ready. ==="
else
    echo "=== $errors issue(s) found. See above. ==="
    exit 1
fi
