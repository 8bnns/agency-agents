# Tooling tests

Unit tests for the Bash tooling in [`scripts/`](../scripts), written with
[bats-core](https://github.com/bats-core/bats-core). The existing
`lint-agents.yml` CI job validates agent **content**; this suite validates the
**tools** that lint and transpile that content — none of which had any tests
before.

## Running

```bash
./test/run.sh                 # whole suite
./test/run.sh test/lint.bats  # one file
```

`run.sh` uses a system-installed `bats` if present, otherwise it vendors
bats-core into `test/vendor/` (gitignored) on first run. CI installs bats via
the `bats-core/bats-action` GitHub Action — see `.github/workflows/test-tooling.yml`.

## Layout

| File | Covers |
|---|---|
| `lint.bats` | `lint-agents.sh` — ERROR vs WARN behaviour, exit codes, full-roster pass |
| `convert.bats` | `convert.sh` — colour resolution, slugify, qwen tools field, OpenClaw SOUL/AGENTS split, frontmatter-less skipping |
| `invariants.bats` | Cross-file lists CLAUDE.md says must stay in sync: `AGENT_DIRS` across the three scripts, and the SOUL/AGENTS keyword lists shared by `lint-agents.sh` and `convert.sh` |
| `fixtures/` | Minimal valid and deliberately-broken agents |
| `helpers/common.bash` | Shared paths and the `AGENT_DIRS` extractor |

## Notes / known gaps

- `convert.sh` derives its source root from its own location, so the convert
  tests build a throwaway repo containing a copy of the script plus one category
  dir, then point `--out` at a temp dir.
- A bare `./scripts/lint-agents.sh` (the "all agents" invocation in CLAUDE.md)
  currently **fails**, because `strategy/` is in `AGENT_DIRS` but its docs have
  no frontmatter. CI sidesteps this by passing explicit changed files. The
  roster test excludes `strategy/` to match CI's effective coverage.
- `install.sh` is not yet covered — it copies into real user config dirs and
  needs fake-`$HOME` fixtures. Good next target.
