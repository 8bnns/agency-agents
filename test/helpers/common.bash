# Shared helpers for the bats test suites.
#
# REPO_ROOT points at the repository root regardless of where bats is invoked
# from. SCRIPTS and FIXTURES are convenience paths used throughout the suites.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS="$REPO_ROOT/scripts"
FIXTURES="$REPO_ROOT/test/fixtures"

# Extract the AGENT_DIRS bash array literal from a script and print one dir per
# line, sorted. Works for both the multi-line form (lint-agents.sh) and the
# wrapped single-statement form (convert.sh).
extract_agent_dirs() {
  local file="$1"
  awk '
    /^AGENT_DIRS=\(/ { capture=1; sub(/^AGENT_DIRS=\(/, ""); }
    capture {
      line=$0
      sub(/\).*/, "", line)   # drop closing paren and anything after
      n=split(line, words, /[ \t]+/)
      for (i=1; i<=n; i++) if (words[i] != "") print words[i]
      if ($0 ~ /\)/) exit
    }
  ' "$file" | sort -u
}
