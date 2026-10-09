# Goose Safety Conventions — Skyrim Goose Toolkit

This fork replaces Claude Code's automatic safety hooks with **explicit conventions**
that you and Goose must follow. There is no agent runtime enforcing these — compliance
is deliberate.

Read this file before every session where you touch Skyrim files.

---

## The Four Rules

### 1. Never Write Directly to ESP / ESM / ESL / BSA / BA2

A hand-edited plugin binary is a corrupted plugin. Always use:
- **Spriggit**: `spriggit serialize` → edit YAML → `spriggit deserialize`
- **SSEEdit / xEdit**: Open the plugin in the editor, make changes through the GUI
- **SSEEdit scripting**: For automated changes, write a zEdit/xEdit script and run it

**Exception:** Text files (`.psc`, `.ini`, `.txt`, `.json`, `.yaml`) may be edited directly.

### 2. Back Up Before You Touch

Before any edit or destructive operation, snapshot the file:
```bash
# Toolkit convention — use it even though the automatic hook is gone
cp MyFile.txt .local/backups/$(date +%Y%m%d_%H%M%S)_MyFile.txt
```

For batch work, name the backup descriptively so you can roll back:
```bash
cp -r Data/SKSE/Plugins/AgencyEngine.json .local/backups/agency_pre_urgency_tweak/
```

### 3. Show the Change Before Applying

Goose must present the intended change in full before execution, especially for:
- INI files (`Skyrim.ini`, `SkyrimPrefs.ini`, `SkyrimCustom.ini`)
- Load order files (`plugins.txt`, `loadorder.txt`)
- Anything under the game directory or Wine prefix
- Any Papyrus `.psc` source file

You approve explicitly; there is no silent auto-apply.

### 4. State Confidence and Assumptions

Before any change that affects gameplay, Goose must rate confidence 0–100% and
list every assumption the change rests on. If confidence is below 80%, investigate
further before proceeding.

---

## Immutable Linux Specifics

### Dependency Installation

| Tool | Purpose | Install Path |
|------|---------|--------------|
| jq | JSON parsing, safety checks | Flatpak: `flatpak install flathub app.getjq.jq` |
| Node.js | xelib, FOMOD XML, dev tooling | Homebrew / NodeSource / Distrobox |
| Python 3 | Crash triage, save analysis, PyNifly | Usually pre-installed |
| OpenJDK 17+ | ReSaver CLI | Flatpak SDK / Distrobox |
| .NET 9 SDK | Spriggit, AutoMod | Distrobox (immutable hosts resist system layering) |
| Docker | Devcontainer workflows | Rootless Docker or Podman |
| Wine | SSEEdit scripting, Papyrus compilation | Your existing Amethyst runtime |

**Rule of thumb:** If it needs compilation or heavy system integration, run it in a
**Distrobox** or the **devcontainer** rather than layering onto the immutable host.

### Amethyst Path Resolution

Run `python3 tools/amethyst-paths.py` at any time to re-scan your Amethyst config.
Source the generated env file before running toolkit utilities:

```bash
source .local/config/skyrim-paths.env
```

This sets `SKYRIM_MODS_DIR`, `SKYRIM_PROFILE_DIR`, `SKYRIM_WINE_PREFIX`,
`SKYRIM_DOCUMENTS`, and other variables that `tools/skyrim_paths.py` and
`tools/crash-triage.py` consume.

### Wine Prefix Notes

Amethyst manages a Proton/Wine prefix under `steamapps/compatdata/<appid>/pfx`.
Your `Documents/My Games/Skyrim Special Edition/` lives **inside that prefix**, not
under your Linux `~/Documents`. The setup script resolves it automatically, but if
youever move your prefix or use a custom one, set `SKYRIM_WINE_PREFIX`.

---

## Tool Status on Linux

| Tool | Status | Notes |
|------|--------|-------|
| `tools/resaver-cli.sh` | ✅ Native | Classpath separator fixed for Linux JDK |
| `tools/crash-triage.py` | ✅ Native | Pure Python |
| `tools/papyrus-triage.py` | ✅ Native | Pure Python |
| `tools/amethyst-paths.py` | ✅ Native | New in this fork |
| `tools/devbench-cli.sh` | ✅ Native wrapper | DevBench itself is a Windows SKSE plugin |
| `tools/skyrim-winner.js` | ⚠️ Partial | Works for single-file reads; full load-order resolution needs xelib (Windows DLL) |
| `tools/xelib/` | ❌ Windows-only | `XEditLib.dll` is Delphi-compiled |
| `tools/spriggit-cli.sh` | ⚠️ Container/Distrobox | Needs .NET 9 SDK; runs fine in devcontainer |
| `tools/automod-cli.sh` | ⚠️ Container/Distrobox | Needs .NET 8 SDK + global.json |
| Papyrus compilation | ⚠️ Wine/SSEEdit | No confirmed native Linux SSE compiler yet; SSEEdit scripting under Wine is the pragmatic path |
| PyNifly / Blender NIF | ⚠️ Complex | PyNifly is Python bindings to C++ nifly; Blender headless needs native Blender install |

---

## When to Use the Devcontainer

If you installed Docker/Podman, `./devshell-docker.sh` gives you an isolated
environment with Python, Node, .NET, and OpenJDK pre-installed. Use it for:
- Spriggit ESP serialization/deserialization
- ReSaver save analysis (if you don't want JDK on the host)
- Python unit testing
- Node-based FOMOD/JSON generation

It mounts your real Amethyst mod folders read-only; it does NOT need Wine or
the game running.

---

## Contributing

Found a quirk specific to Linux, Amethyst, or immutable systems? Write it into
`KNOWLEDGEBASE.local.md` — that file is never shipped by releases and survives
updates. Never add platform notes to the upstream `KNOWLEDGEBASE.md`; the next
fork sync would overwrite them.
