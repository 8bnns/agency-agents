#!/usr/bin/env bats
#
# Tests for scripts/convert.sh — the transpiler that turns agent .md files into
# per-tool formats. These exercise the core helpers and the OpenClaw SOUL/AGENTS
# split, none of which are currently run in CI.
#
# convert.sh derives its source root from its own location (SCRIPT_DIR/..), so
# to convert fixtures in isolation we build a throwaway repo containing a copy
# of the script plus a single category dir, and point --out at a temp dir.

load helpers/common

setup() {
  OUT="$(mktemp -d)"
  TMPREPO="$(mktemp -d)"
  mkdir -p "$TMPREPO/scripts" "$TMPREPO/specialized"
  cp "$SCRIPTS/convert.sh" "$TMPREPO/scripts/convert.sh"
  CONVERT="$TMPREPO/scripts/convert.sh"
}

teardown() {
  rm -rf "$OUT" "$TMPREPO"
}

# Place a fixture (optionally a modified copy) into the temp repo and convert it.
# Usage: run_convert <tool> [source-file]
run_convert() {
  local tool="$1"
  local src="${2:-$FIXTURES/valid-agent.md}"
  cp "$src" "$TMPREPO/specialized/agent.md"
  "$CONVERT" --tool "$tool" --out "$OUT" >/dev/null
}

@test "convert: opencode resolves a named color to uppercase hex" {
  run_convert opencode
  local f="$OUT/opencode/agents/test-valid-agent.md"
  [ -f "$f" ]
  grep -q "color: '#00FFFF'" "$f"
}

@test "convert: opencode falls back to gray for an unknown color" {
  sed 's/^color: cyan/color: not-a-real-color/' "$FIXTURES/valid-agent.md" \
    > "$TMPREPO/odd.md"
  run_convert opencode "$TMPREPO/odd.md"
  grep -q "color: '#6B7280'" "$OUT/opencode/agents/test-valid-agent.md"
}

@test "convert: name is slugified into the output filename" {
  run_convert cursor
  [ -f "$OUT/cursor/rules/test-valid-agent.mdc" ]
}

@test "convert: qwen emits the tools field when present in frontmatter" {
  run_convert qwen
  grep -q "^tools: Read, Write, Bash" "$OUT/qwen/agents/test-valid-agent.md"
}

@test "convert: qwen omits the tools field when absent" {
  grep -v '^tools:' "$FIXTURES/valid-agent.md" > "$TMPREPO/notools.md"
  run_convert qwen "$TMPREPO/notools.md"
  # grep -q exits 1 when the pattern is absent (and 2 on a read error, which
  # would also catch a missing output file), so assert the not-found status.
  run grep -q "^tools:" "$OUT/qwen/agents/test-valid-agent.md"
  [ "$status" -eq 1 ]
}

@test "convert: body templating tokens are preserved verbatim" {
  run_convert cursor
  grep -q '${project_name}' "$OUT/cursor/rules/test-valid-agent.mdc"
}

@test "convert: openclaw splits persona headers into SOUL.md" {
  run_convert openclaw
  local dir="$OUT/openclaw/test-valid-agent"
  [ -f "$dir/SOUL.md" ]
  grep -q "## Identity" "$dir/SOUL.md"
  grep -q "## Communication Style" "$dir/SOUL.md"
  grep -q "## Critical Rules" "$dir/SOUL.md"
}

@test "convert: openclaw splits operations headers into AGENTS.md" {
  run_convert openclaw
  local dir="$OUT/openclaw/test-valid-agent"
  [ -f "$dir/AGENTS.md" ]
  grep -q "## Core Mission" "$dir/AGENTS.md"
  grep -q "## Workflow" "$dir/AGENTS.md"
}

@test "convert: openclaw persona content does not leak into AGENTS.md" {
  run_convert openclaw
  # Persona headers must be absent from AGENTS.md: grep -q exits 1 (not found).
  run grep -q "## Identity" "$OUT/openclaw/test-valid-agent/AGENTS.md"
  [ "$status" -eq 1 ]
}

@test "convert: openclaw IDENTITY.md uses emoji and vibe when present" {
  run_convert openclaw
  local f="$OUT/openclaw/test-valid-agent/IDENTITY.md"
  grep -q "🧪 Test Valid Agent" "$f"
  grep -q "Calm, methodical" "$f"
}

@test "convert: openclaw IDENTITY.md falls back to description without emoji/vibe" {
  grep -vE '^(emoji|vibe):' "$FIXTURES/valid-agent.md" > "$TMPREPO/plain.md"
  run_convert openclaw "$TMPREPO/plain.md"
  local f="$OUT/openclaw/test-valid-agent/IDENTITY.md"
  grep -q "# Test Valid Agent" "$f"
  grep -q "A well-formed fixture agent" "$f"
}

@test "convert: files without frontmatter are silently skipped" {
  cp "$FIXTURES/missing-frontmatter.md" "$TMPREPO/specialized/skipme.md"
  run_convert cursor
  [ -f "$OUT/cursor/rules/test-valid-agent.mdc" ]
  # The non-agent doc produced no output file.
  run bash -c "ls '$OUT/cursor/rules' | wc -l"
  [ "$output" -eq 1 ]
}

@test "convert: an unknown --tool is rejected with a nonzero exit" {
  run "$CONVERT" --tool bogus --out "$OUT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown tool"* ]]
}
