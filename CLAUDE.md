# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

"The Agency" is a curated **content** collection of ~184 specialized AI agent
personas, each a single Markdown file with YAML frontmatter. There is no
application to build or run — the only executable code is the Bash tooling in
`scripts/` that validates agents and transpiles them into formats consumed by
various agentic tools (Claude Code, Copilot, Cursor, Gemini CLI, OpenCode,
OpenClaw, Aider, Windsurf, Qwen, Kimi, Antigravity).

The unit of contribution is one agent `.md` file. Most real work here is writing
or editing agent personas, not changing tooling.

## Commands

```bash
# Lint agents (run before committing agent changes; this is what CI runs)
./scripts/lint-agents.sh                          # all agents
./scripts/lint-agents.sh engineering/foo.md       # specific file(s)

# Transpile agents into integrations/<tool>/ (regenerate after editing agents)
./scripts/convert.sh                              # all tools
./scripts/convert.sh --tool cursor                # one tool
./scripts/convert.sh --parallel                   # parallelize independent tools

# Install converted agents into local tool config dirs (~/.claude/agents/, etc.)
./scripts/install.sh                              # interactive, auto-detects tools
./scripts/install.sh --tool claude-code           # one tool, non-interactive
```

CI (`.github/workflows/lint-agents.yml`) runs `lint-agents.sh` against only the
agent files changed in a PR. Linter **errors fail CI**; warnings do not.

## Agent file contract

Every agent is a `.md` file in one of the category directories, structured as:

- **Frontmatter** (between the first two `---` lines). Required: `name`,
  `description`, `color`. Optional: `emoji`, `vibe`, `services`, `tools`.
- **Body**: Markdown with `##` section headers (see semantic routing below).

Files that lack opening `---` frontmatter or a `name` field are **silently
skipped** by `convert.sh` and `install.sh`. This is intentional — it lets
non-agent docs (e.g. everything under `strategy/`, `examples/`, `QUICKSTART.md`)
live inside scanned directories without being transpiled.

### Section headers are semantically meaningful

This is the non-obvious part. `convert.sh`'s OpenClaw converter splits each
agent body into two files by classifying `##` headers via case-insensitive
keyword match:

- **SOUL.md** (persona) ← headers matching: `identity`, `learning & memory`,
  `communication`, `style`, `critical rule`, `rules you must follow`
- **AGENTS.md** (operations) ← every other header (mission, deliverables,
  workflow, metrics, …)

`lint-agents.sh` enforces the same classification: it **warns** if an agent has
zero headers mapping to SOUL or zero mapping to AGENTS. The keyword lists in
`classify_header_target()` (lint-agents.sh) and the OpenClaw converter
(convert.sh) must stay in agreement — if you change one, change the other.

Lint also warns on: missing recommended sections (`Identity`, `Core Mission`,
`Critical Rules`) and bodies under 50 words.

The canonical template for a new agent's structure lives in `CONTRIBUTING.md`
under "Agent File Structure" — follow it so the section routing works.

## Directory layout

- **Category dirs** (the agent roster): `academic`, `design`, `engineering`,
  `finance`, `game-development`, `marketing`, `paid-media`, `product`,
  `project-management`, `sales`, `spatial-computing`, `specialized`, `strategy`,
  `support`, `testing`. `game-development/` nests further by engine
  (`unity/`, `godot/`, `unreal-engine/`, `blender/`, `roblox-studio/`); scans
  are recursive so nested agents are picked up.
- **`strategy/`** holds multi-agent orchestration docs — `playbooks/` (phased
  delivery), `runbooks/` (scenario walkthroughs), `coordination/` (handoff
  templates). These have no frontmatter and are *not* transpiled.
- **`integrations/`** is the **output directory** for `convert.sh`. Generated
  files are gitignored (see `.gitignore`) and must never be committed. The
  per-tool `README.md` files, plus `integrations/github-copilot/` and
  `integrations/mcp-memory/`, are hand-maintained and committed.
- **`examples/`** — end-to-end multi-agent workflow walkthroughs.
- **`scripts/i18n/`** — Chinese localization tooling (`localize-agents-zh.ps1`,
  `agent-names-zh.json`).

### The `AGENT_DIRS` list must stay in sync across three files

The category-directory list is duplicated in `scripts/lint-agents.sh`,
`scripts/convert.sh`, and `scripts/install.sh`. When adding or renaming a
category directory, update **all three** (and the `paths:` / `git diff` globs in
`.github/workflows/lint-agents.yml`).

## Conventions for changes

- After editing any agent, you do **not** need to commit `integrations/` output
  — it is generated and gitignored. Run `convert.sh` only to verify your changes
  transpile cleanly.
- Keep changes scoped to a single agent file when possible. Per `CONTRIBUTING.md`,
  bulk reformatting of existing agents and any new tooling/CI/architecture
  changes are expected to start as a Discussion, not a PR.
- Agent bodies support `${variable}` templating (e.g. `${project_name}`) for Qwen
  compatibility; preserve it when editing.
