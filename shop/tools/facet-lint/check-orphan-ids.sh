#!/usr/bin/env sh
# Verifies every @facet: tag in source resolves to a known feature record.
# Requires: grep, find (POSIX; works with BusyBox on Alpine)
# Usage: sh tools/facet-lint/check-orphan-ids.sh [REPO_ROOT]

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/lib.sh"

RECORDS_DIRS=$(facet_records_dirs "$REPO_ROOT")

echo "=== Check orphan @facet: tag IDs ==="

# Collect all @facet: IDs from source. Scan scope comes from lib.sh, so a
# project with a non-standard layout is covered without editing this script.
tag_ids=$(facet_source_files "$REPO_ROOT" |
  while IFS= read -r f; do grep -h '@facet:' "$f" 2>/dev/null; done |
  grep -oE '@facet:[[:space:]]*[a-z][a-z0-9-]*/[a-z][a-z0-9-]*/[a-z][a-z0-9-]+' |
  sed 's/@facet:[[:space:]]*//' |
  sort -u)

if [ -z "$tag_ids" ]; then
  echo "  No @facet: tags found in source — bootstrap case, skipping check."
  echo "PASS"
  exit 0
fi

echo "  Found $(printf '%s\n' "$tag_ids" | wc -l | tr -d ' ') unique @facet: ID(s)."

FAILED=0

# Heredoc redirect (not pipe) so FAILED assignment is not in a subshell.
while IFS= read -r id; do
  [ -z "$id" ] && continue
  # With several registries an id resolves when any of them holds it; which
  # registry owns the file carrying the tag is the binary's question.
  found=""
  expected=""
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    [ -n "$expected" ] || expected="$dir/features/${id}.yaml"
    if [ -f "$dir/features/${id}.yaml" ]; then
      found=1
      break
    fi
  done <<DIRS
$RECORDS_DIRS
DIRS
  if [ -z "$found" ]; then
    echo "  ERROR: Unknown @facet: ID '$id' — expected record at ${expected#"$REPO_ROOT"/}"
    FAILED=1
  fi
done <<LIST
$tag_ids
LIST

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "FAIL: One or more @facet: tags reference IDs with no corresponding record."
  echo "      Create the missing facet.yaml records or fix the tag IDs."
  exit 1
fi

echo "PASS: All @facet: IDs resolve to existing records."
