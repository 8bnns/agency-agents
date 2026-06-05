#!/usr/bin/env bats
#
# Cross-file invariant tests. CLAUDE.md documents two lists that are hand-copied
# across multiple files and "must stay in sync" / "must stay in agreement", but
# nothing enforces them. These tests fail loudly the moment they drift.

load helpers/common

# Pull the SOUL-classification keyword regexes out of a script's header
# classifier (works for both the lint function and convert's inline block).
soul_keywords() {
  grep -oE 'header_lower" =~ [^]]+' "$1" | sed 's/.*=~ //; s/ *$//' | sort -u
}

@test "invariant: AGENT_DIRS is identical in lint-agents.sh and convert.sh" {
  diff <(extract_agent_dirs "$SCRIPTS/lint-agents.sh") \
       <(extract_agent_dirs "$SCRIPTS/convert.sh")
}

@test "invariant: AGENT_DIRS is identical in lint-agents.sh and install.sh" {
  diff <(extract_agent_dirs "$SCRIPTS/lint-agents.sh") \
       <(extract_agent_dirs "$SCRIPTS/install.sh")
}

@test "invariant: SOUL/AGENTS header keywords agree between lint and convert" {
  # CLAUDE.md: classify_header_target() (lint) and the OpenClaw converter
  # (convert) "must stay in agreement — if you change one, change the other."
  diff <(soul_keywords "$SCRIPTS/lint-agents.sh") \
       <(soul_keywords "$SCRIPTS/convert.sh")
}

@test "invariant: every category dir in AGENT_DIRS exists on disk" {
  while IFS= read -r dir; do
    [ -d "$REPO_ROOT/$dir" ] || {
      echo "AGENT_DIRS references missing directory: $dir"
      return 1
    }
  done < <(extract_agent_dirs "$SCRIPTS/lint-agents.sh")
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
  diff <(echo "$paths_dirs") <(echo "$diff_dirs")
}

@test "invariant: every dir the CI workflow lints is a real AGENT_DIRS category" {
  # The workflow may intentionally lint a subset (e.g. strategy/ is excluded
  # because its docs have no frontmatter), but it must never reference a
  # category that isn't in AGENT_DIRS.
  local wf="$REPO_ROOT/.github/workflows/lint-agents.yml"
  local agent_dirs
  agent_dirs="$(extract_agent_dirs "$SCRIPTS/lint-agents.sh")"
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    grep -qx "$dir" <<< "$agent_dirs" || {
      echo "Workflow lints '$dir' which is not in AGENT_DIRS"
      return 1
    }
  done < <(grep -oE '^\s+- "[a-z-]+/\*\*"' "$wf" \
             | sed -E 's:.*- "([a-z-]+)/.*:\1:' | sort -u)
}
