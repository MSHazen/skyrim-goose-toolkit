# Agent Instructions — Skyrim Goose Toolkit

Welcome, agent. This environment is a `claude-code`-style toolkit that has been
ported for **immutable Linux + Amethyst Mod Manager + Goose**.

## Quick Start

1. **Read `GOOSE.md`** — it replaces the original Claude-specific instructions
   with safety conventions, tool status, and dependency guidance for non-Claude
   agents.

2. **Read `KNOWLEDGEBASE.md`** — 1,300+ lines of engine quirks, version
   differences, and tool gotchas. Consult it before touching anything.

3. **Source the environment** if paths have not been set:
   ```bash
   source .local/config/skyrim-paths.env
   ```

4. **Follow the portable skills** in `docs/skills/` for common workflows
   (inspect-esp, create-mod, port-to-vr, etc.).

## Differences from the Original Claude Code Setup

| Feature | Claude Code | This Fork (Goose/Any Agent) |
|---------|-------------|-----------------------------|
| Safety hooks | `.claude/hooks/*.sh` (automatic) | Manual per `GOOSE.md` Four Rules |
| Agent config | `.claude/settings.json` | `GOOSE.md` + local memory |
| Skills | `.claude/skills/` | `docs/skills/` (copied, portable) |
| Path setup | `setup.sh` (Windows/MSYS) | `setup-linux.sh` (Linux/Amethyst) |
| Runtime config | `.claude/skyrim-paths.env` | `.local/config/skyrim-paths.env` |

## Safety Rules (Manual Enforcement)

There is no automatic hook layer here. The agent must enforce these:

1. **Never write directly to `.esp` / `.esm` / `.esl` / `.bsa` / `.ba2`.**
   Use Spriggit (serialize → edit YAML → deserialize) or SSEEdit.
2. **Back up to `.local/backups/` before editing.**
3. **Show the change before applying.** Especially INIs, load order, game files.
4. **State confidence 0–100% and list assumptions before any gameplay-affecting change.**

## Questions?

Refer to `GOOSE.md` first. For engine behaviour, `KNOWLEDGEBASE.md`. For
workflows, `docs/skills/<skill>/SKILL.md`.
