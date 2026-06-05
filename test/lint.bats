#!/usr/bin/env bats
#
# Tests for scripts/lint-agents.sh — the only tooling currently run in CI.
# Verifies that ERRORs fail the build (exit 1) and WARNs do not (exit 0).

load helpers/common

@test "lint: a well-formed agent passes with no errors or warnings" {
  run "$SCRIPTS/lint-agents.sh" "$FIXTURES/valid-agent.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASSED"* ]]
  [[ "$output" == *"0 error(s), 0 warning(s)"* ]]
}

@test "lint: missing frontmatter opening --- is an ERROR and fails" {
  run "$SCRIPTS/lint-agents.sh" "$FIXTURES/missing-frontmatter.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing frontmatter opening ---"* ]]
  [[ "$output" == *"FAILED"* ]]
}

@test "lint: a missing required frontmatter field is an ERROR and fails" {
  run "$SCRIPTS/lint-agents.sh" "$FIXTURES/missing-color.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing frontmatter field 'color'"* ]]
}

@test "lint: short body and missing soul headers are WARN-only (exit 0)" {
  run "$SCRIPTS/lint-agents.sh" "$FIXTURES/short-no-soul.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASSED"* ]]
  [[ "$output" == *"body seems very short"* ]]
  [[ "$output" == *"no section headers map to SOUL.md"* ]]
}

@test "lint: missing recommended sections warn but do not fail" {
  run "$SCRIPTS/lint-agents.sh" "$FIXTURES/short-no-soul.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing recommended section 'Identity'"* ]]
  [[ "$output" == *"missing recommended section 'Critical Rules'"* ]]
}

@test "lint: a nonexistent file is reported as an ERROR" {
  run "$SCRIPTS/lint-agents.sh" "$FIXTURES/does-not-exist.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a file or does not exist"* ]]
}

@test "lint: the full agent roster (excluding strategy/) passes" {
  # Guards against a linter refactor regressing against real agents, and against
  # an agent being merged that the changed-files-only CI job missed.
  #
  # strategy/ is excluded on purpose: its docs intentionally have no frontmatter,
  # so the linter ERRORs on them. (Note: that also means a bare
  # `./scripts/lint-agents.sh` — the "all agents" invocation in CLAUDE.md —
  # currently fails, because strategy/ is in AGENT_DIRS. See PR notes.)
  local files=()
  while IFS= read -r dir; do
    [ "$dir" = "strategy" ] && continue
    [ -d "$REPO_ROOT/$dir" ] || continue
    while IFS= read -r f; do files+=("$f"); done \
      < <(find "$REPO_ROOT/$dir" -name "*.md" -type f)
  done < <(extract_agent_dirs "$SCRIPTS/lint-agents.sh")

  run "$SCRIPTS/lint-agents.sh" "${files[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASSED"* ]]
}
