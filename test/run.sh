#!/usr/bin/env bash
#
# Run the tooling test suite with bats.
#
# Uses a system-installed `bats` if present; otherwise vendors bats-core into
# test/vendor/bats-core (gitignored) on first run. Pass extra args straight
# through to bats, e.g. ./test/run.sh test/lint.bats
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v bats >/dev/null 2>&1; then
  BATS=bats
else
  VENDOR="$TEST_DIR/vendor/bats-core"
  if [[ ! -x "$VENDOR/bin/bats" ]]; then
    echo "bats not found — vendoring bats-core into test/vendor/ ..."
    mkdir -p "$TEST_DIR/vendor"
    git clone --depth 1 https://github.com/bats-core/bats-core.git "$VENDOR" >/dev/null 2>&1
  fi
  BATS="$VENDOR/bin/bats"
fi

if [[ $# -gt 0 ]]; then
  exec "$BATS" "$@"
fi

exec "$BATS" "$TEST_DIR"/*.bats
