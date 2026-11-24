#!/usr/bin/env sh

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/lib.sh"

RECORDS_DIRS=$(facet_records_dirs "$REPO_ROOT")

echo "=== Check orphan active FACET records (no source anchor) ==="

# Collect all @facet: IDs from source in one pass. Scan scope comes from lib.sh.
sourced_ids=$(facet_source_files "$REPO_ROOT" |
  while IFS= read -r f; do grep -h '@facet:' "$f" 2>/dev/null; done |
  grep -oE '@facet:[[:space:]]*[a-z][a-z0-9-]*/[a-z][a-z0-9-]*/[a-z][a-z0-9-]+' |
  sed 's/@facet:[[:space:]]*//' |
  sort -u)

# Find all active feature records.
# Every registry's features: with several, one directory per registry.
active_records=$(printf '%s\n' "$RECORDS_DIRS" |
  while IFS= read -r dir; do [ -n "$dir" ] && find "$dir/features" -name '*.yaml' 2>/dev/null; done |
  sort |
  while IFS= read -r f; do
    grep -q '^lifecycle:[[:space:]]*active' "$f" 2>/dev/null && echo "$f"
  done)

count=$(printf '%s\n' "$active_records" | grep -c '[^[:space:]]' 2>/dev/null || echo 0)
if [ -z "$active_records" ] || [ "$count" -eq 0 ]; then
  echo "  No active feature records found — skipping check."
  echo "PASS"
  exit 0
fi

echo "  Found $count active feature record(s). Checking source anchors..."

FAILED=0

while IFS= read -r f; do
  [ -z "$f" ] && continue

  facet_id=$(grep '^id:[[:space:]]' "$f" | sed 's/^id:[[:space:]]*//' | tr -d '[:space:]')
  if [ -z "$facet_id" ]; then
    echo "  WARNING: Could not extract id from $f — skipping."
    continue
  fi

  # Check membership in the pre-collected sourced_ids set.
  if ! printf '%s\n' "$sourced_ids" | grep -qxF "$facet_id"; then
    echo "  ERROR: Active record '$facet_id' has no @facet: anchor in source."
    FAILED=1
  fi
done <<LIST
$active_records
LIST

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "FAIL: One or more active FACET records have no source anchor."
  echo "      Add '@facet: <id>' + '@facet-role: primary' to the implementing file(s),"
  echo "      or set lifecycle: planned if the feature is not yet implemented."
  exit 1
fi

echo "PASS: All active FACET records have at least one source anchor."
