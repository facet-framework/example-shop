#!/usr/bin/env sh
# Runs all FACET lint checks. Exits 1 if any check fails.
# Usage: sh tools/facet-lint/run-all.sh [REPO_ROOT]

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
# Sibling scripts are resolved next to this file, so the suite runs the same
# whether it was copied into a project or invoked from the FACET plugin.
SCRIPTS=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

OVERALL=0

run_check() {
  script="$1"
  echo ""
  sh "$SCRIPTS/$script" "$REPO_ROOT"
  rc=$?
  if [ $rc -ne 0 ]; then
    OVERALL=1
  fi
}

run_check validate-schemas.sh
run_check check-orphan-ids.sh
run_check check-orphan-records.sh

echo ""
if [ "$OVERALL" -eq 0 ]; then
  echo "=== All FACET lint checks passed ==="
else
  echo "=== FACET lint FAILED — see errors above ==="
  exit 1
fi
