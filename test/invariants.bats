#!/usr/bin/env bats
#
# Cross-file invariant tests. CLAUDE.md documents two lists that are hand-copied
# across multiple files and "must stay in sync" / "must stay in agreement", but
# nothing enforces them. These tests fail loudly the moment they drift.
#
# Every test below parses lists out of scripts/workflows by text matching and
# then compares them. A parsing regression could silently make both sides empty,
# so each test first asserts the extraction produced a non-empty list containing
# a known sentinel entry — otherwise two empty lists would compare equal and the
# invariant would false-pass.

load helpers/common

# Pull the SOUL-classification keyword regexes out of a script's header
# classifier (works for both the lint function and convert's inline block).
soul_keywords() {
  grep -oE 'header_lower" =~ [^]]+' "$1" | sed 's/.*=~ //; s/ *$//' | sort -u
}

# Fail the test if $1 is empty or does not contain the sentinel line $2.
assert_parsed() {
  local list="$1" sentinel="$2" what="$3"
  [ -n "$list" ] || { echo "parsing produced an empty list for: $what"; return 1; }
  grep -qx "$sentinel" <<< "$list" \
    || { echo "expected sentinel '$sentinel' missing from $what (parser broken?)"; return 1; }
}

@test "invariant: AGENT_DIRS is identical in lint-agents.sh and convert.sh" {
  local lint convert
  lint="$(extract_agent_dirs "$SCRIPTS/lint-agents.sh")"
  convert="$(extract_agent_dirs "$SCRIPTS/convert.sh")"
  assert_parsed "$lint" academic "lint-agents.sh AGENT_DIRS"
  assert_parsed "$convert" academic "convert.sh AGENT_DIRS"
  diff <(echo "$lint") <(echo "$convert")
}

@test "invariant: AGENT_DIRS is identical in lint-agents.sh and install.sh" {
  local lint install
  lint="$(extract_agent_dirs "$SCRIPTS/lint-agents.sh")"
  install="$(extract_agent_dirs "$SCRIPTS/install.sh")"
  assert_parsed "$lint" academic "lint-agents.sh AGENT_DIRS"
  assert_parsed "$install" academic "install.sh AGENT_DIRS"
  diff <(echo "$lint") <(echo "$install")
}

@test "invariant: SOUL/AGENTS header keywords agree between lint and convert" {
  # CLAUDE.md: classify_header_target() (lint) and the OpenClaw converter
  # (convert) "must stay in agreement — if you change one, change the other."
  local lint convert
  lint="$(soul_keywords "$SCRIPTS/lint-agents.sh")"
  convert="$(soul_keywords "$SCRIPTS/convert.sh")"
  assert_parsed "$lint" identity "lint-agents.sh SOUL keywords"
  assert_parsed "$convert" identity "convert.sh SOUL keywords"
  diff <(echo "$lint") <(echo "$convert")
}

@test "invariant: every category dir in AGENT_DIRS exists on disk" {
  local dirs
  dirs="$(extract_agent_dirs "$SCRIPTS/lint-agents.sh")"
  assert_parsed "$dirs" academic "lint-agents.sh AGENT_DIRS"
  while IFS= read -r dir; do
    [ -d "$REPO_ROOT/$dir" ] || {
      echo "AGENT_DIRS references missing directory: $dir"
      return 1
    }
  done <<< "$dirs"
}

@test "invariant: the CI workflow's path and git-diff lists agree with each other" {
  # paths: globs (academic/**) and the git diff globs (academic/**/*.md) must
  # cover the same set of directories.
  local wf="$REPO_ROOT/.github/workflows/lint-agents.yml"
  local paths_dirs diff_dirs
  paths_dirs=$(grep -oE '^\s+- "[a-z-]+/\*\*"' "$wf" \
                 | sed -E 's:.*- "([a-z-]+)/.*:\1:' | sort -u)
  diff_dirs=$(grep -oE "'[a-z-]+/\*\*/\*\.md'" "$wf" \
                 | sed -E "s:'([a-z-]+)/.*:\1:" | sort -u)
  assert_parsed "$paths_dirs" academic "workflow paths: globs"
  assert_parsed "$diff_dirs" academic "workflow git-diff globs"
  diff <(echo "$paths_dirs") <(echo "$diff_dirs")
}

@test "invariant: every dir the CI workflow lints is a real AGENT_DIRS category" {
  # The workflow may intentionally lint a subset (e.g. strategy/ is excluded
  # because its docs have no frontmatter), but it must never reference a
  # category that isn't in AGENT_DIRS.
  local wf="$REPO_ROOT/.github/workflows/lint-agents.yml"
  local agent_dirs wf_dirs
  agent_dirs="$(extract_agent_dirs "$SCRIPTS/lint-agents.sh")"
  wf_dirs="$(grep -oE '^\s+- "[a-z-]+/\*\*"' "$wf" \
               | sed -E 's:.*- "([a-z-]+)/.*:\1:' | sort -u)"
  assert_parsed "$agent_dirs" academic "lint-agents.sh AGENT_DIRS"
  assert_parsed "$wf_dirs" academic "workflow paths: globs"
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    grep -qx "$dir" <<< "$agent_dirs" || {
      echo "Workflow lints '$dir' which is not in AGENT_DIRS"
      return 1
    }
  done <<< "$wf_dirs"
}
