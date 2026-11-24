#!/usr/bin/env sh
# Validates FACET YAML records against their JSON schemas.
# Requires: yq (4.x), ajv-cli (npm install -g ajv-cli)
# Usage: sh tools/facet-lint/validate-schemas.sh [REPO_ROOT] [SINGLE_FILE]

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SINGLE_FILE="$2"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/lib.sh"

RECORDS_DIRS=$(facet_records_dirs "$REPO_ROOT")
SCHEMA_DIR=$(facet_schema_dir "$REPO_ROOT")

FAILED=0
CHECK_SPEC_LOCK=0
TMP_JSON="${TMPDIR:-/tmp}/facet-validate-$$.json"
trap 'rm -f "$TMP_JSON"' EXIT

echo "=== Validate FACET schemas ==="

# Missing yq/ajv is a skip by default so the check degrades gracefully on a
# developer machine; set FACET_STRICT_DEPS=1 (as CI does) to make it an error.
facet_require_tool ajv
case $? in
1) exit 1 ;;
2) exit 0 ;;
esac

facet_require_yaml_converter
case $? in
1) exit 1 ;;
2) exit 0 ;;
esac

if [ ! -d "$SCHEMA_DIR" ]; then
  echo "  SKIP: no schema directory at ${SCHEMA_DIR#"$REPO_ROOT"/}"
  exit 0
fi

validate_one() {
  f="$1"
  schema="$2"
  echo "    Checking: ${f#"$REPO_ROOT"/}"
  if ! facet_yaml_to_json "$f" >"$TMP_JSON" 2>/dev/null; then
    echo "      ERROR: could not convert YAML to JSON — is this valid YAML?"
    FAILED=1
    return 0
  fi
  case "$f" in
  "$RECORDS_DIR"/features/*)
    if grep -q '"specified_by"[[:space:]]*:' "$TMP_JSON"; then
      CHECK_SPEC_LOCK=1
    fi
    ;;
  esac
  if ! ajv validate -s "$schema" -d "$TMP_JSON" 2>&1; then
    FAILED=1
  fi
}

schema_for_category() {
  case "$1" in
  features | graveyard) printf '%s\n' "$SCHEMA_DIR/facet.schema.json" ;;
  policies) printf '%s\n' "$SCHEMA_DIR/policy.schema.json" ;;
  assumptions) printf '%s\n' "$SCHEMA_DIR/assumption.schema.json" ;;
  data-entities) printf '%s\n' "$SCHEMA_DIR/data-entity.schema.json" ;;
  *) return 1 ;;
  esac
}

# Single-file mode: derive the schema from the record's category directory.
if [ -n "$SINGLE_FILE" ]; then
  # The records directory holding the file; with several registries, the one
  # whose path is a prefix of it.
  rel="$SINGLE_FILE"
  while IFS= read -r RECORDS_DIR; do
    [ -n "$RECORDS_DIR" ] || continue
    case "$SINGLE_FILE" in
    "$RECORDS_DIR"/*)
      rel="${SINGLE_FILE#"$RECORDS_DIR"/}"
      break
      ;;
    esac
  done <<DIRS
$RECORDS_DIRS
DIRS
  category="${rel%%/*}"
  schema=$(schema_for_category "$category") || {
    echo "  SKIP: $SINGLE_FILE is not under a known record category."
    exit 0
  }
  validate_one "$SINGLE_FILE" "$schema"
  [ "$FAILED" -eq 1 ] && {
    echo ""
    echo "FAIL: record failed schema validation."
    exit 1
  }
  echo "PASS: record is schema-valid."
  exit 0
fi

validate_dir() {
  category="$1"
  schema=$(schema_for_category "$category")
  dir="$RECORDS_DIR/$category"

  count=$(find "$dir" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    echo "  No $category records found — skipping."
    return 0
  fi
  echo "  Found $count $category record(s). Validating..."

  # Heredoc redirect (not pipe) so FAILED assignment is not in a subshell.
  # yq output goes to a temp file — avoids /dev/stdin pipe issues on Linux.
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    validate_one "$f" "$schema"
  done <<LIST
$(find "$dir" -name '*.yaml' 2>/dev/null | sort)
LIST
}

# One pass per records directory: a project with a registries block has one
# per registry, every other project exactly one.
while IFS= read -r RECORDS_DIR; do
  [ -n "$RECORDS_DIR" ] || continue
  if [ "$(printf '%s\n' "$RECORDS_DIRS" | grep -c .)" -gt 1 ]; then
    echo "  Records: ${RECORDS_DIR#"$REPO_ROOT"/}"
  fi
  # The taxonomy is a committed document like any other, and its mistakes are
  # otherwise silent: a mistyped key unmarshals to an empty map, and the errors
  # show up on every id under it rather than on the file that caused them.
  if [ -f "$RECORDS_DIR/taxonomy.yaml" ] && [ -f "$SCHEMA_DIR/taxonomy.schema.json" ]; then
    echo "  Validating taxonomy..."
    validate_one "$RECORDS_DIR/taxonomy.yaml" "$SCHEMA_DIR/taxonomy.schema.json"
  fi

  if [ -f "$RECORDS_DIR/glossary.yaml" ] && [ -f "$SCHEMA_DIR/glossary.schema.json" ]; then
    echo "  Validating glossary..."
    validate_one "$RECORDS_DIR/glossary.yaml" "$SCHEMA_DIR/glossary.schema.json"
  fi

  validate_dir "features"

  validate_dir "graveyard"
  validate_dir "policies"
  validate_dir "assumptions"
  validate_dir "data-entities"

done <<DIRS
$RECORDS_DIRS
DIRS

if [ "$CHECK_SPEC_LOCK" -eq 1 ] || [ -e "$REPO_ROOT/docs/facets/spec-lock.yaml" ]; then
  echo "  Checking pinned specification conformance..."
  facet_require_tool facet
  case $? in
  0) facet spec check-lock --root "$REPO_ROOT" || FAILED=1 ;;
  *)
    # A pinned specification is a promise the project opted into; without
    # the binary nothing can check it, so this is never a silent skip.
    echo "  ERROR: a specification lock or specified_by reference needs the 'facet' binary to be checked."
    FAILED=1
    ;;
  esac
fi

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "FAIL: One or more records failed schema validation or specification conformance."
  exit 1
fi

echo "PASS: All FACET records are schema-valid."
