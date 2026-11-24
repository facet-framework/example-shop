#!/usr/bin/env sh
# @facet-ignore-file

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
WORK=$(mktemp -d)
FAILED=0

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fail() {
  printf 'FAIL %s\n  %s\n' "$1" "$2"
  FAILED=1
}
pass() { printf 'ok   %s\n' "$1"; }

# Resolve the required utilities before restricting PATH. The isolated
# allow-list includes neither yq nor ajv, even when they share an
# installation directory with sh.
MISSING_TOOLS_PATH="$WORK/without-tools"
mkdir -p "$MISSING_TOOLS_PATH"
for utility in sh dirname cat find sort wc tr sed head grep awk mktemp rm git; do
  location=$(command -v "$utility") || {
    printf 'FAIL fixture: required utility %s is unavailable\n' "$utility"
    exit 1
  }
  ln -s "$location" "$MISSING_TOOLS_PATH/$utility" || exit 1
done

# Assert the fixture itself before judging any missing-dependency behaviour.
if PATH="$MISSING_TOOLS_PATH" sh -c 'command -v ajv >/dev/null 2>&1'; then
  fail "fixture" "ajv remains available in the isolated PATH"
  exit 1
fi
path_without_tools() {
  printf '%s' "$MISSING_TOOLS_PATH"
}

# A repository with one valid record and one source file anchoring it.
make_repo() {
  rm -rf "$WORK/repo"
  mkdir -p "$WORK/repo/docs/facets/features/tasks/create" "$WORK/repo/schema" "$WORK/repo/src"
  cp "$ROOT/schema/facet.schema.json" "$WORK/repo/schema/facet.schema.json"
  cat >"$WORK/repo/docs/facets/features/tasks/create/quick-add.yaml" <<'RECORD'
schema_version: "0.1"
id: tasks/create/quick-add
lifecycle: active
intent:
  summary: |
    Adds a task from one line of text.
contract:
  scenarios:
    - id: task-added
      statement: |
        Given a list
        When a line is typed
        Then a task stands in it
lineage:
  owner:
    team: tasks
  created_at: "2026-05-12"
RECORD
  printf '// @facet: tasks/create/quick-add\n// @facet-role: primary\nexport function quickAdd() {}\n' \
    >"$WORK/repo/src/quick_add.ts"
}

run_suite() {
  (cd "$WORK/repo" && sh "$SCRIPT_DIR/run-all.sh" "$WORK/repo" 2>&1)
}

run_suite_without_tools() {
  (cd "$WORK/repo" && PATH="$(path_without_tools)" sh "$SCRIPT_DIR/run-all.sh" "$WORK/repo" 2>&1)
}

# 1. The ordinary run checks every record and passes.

make_repo
out=$(run_suite)
code=$?
checked=$(printf '%s\n' "$out" | grep -c 'Checking:')
if [ "$code" -ne 0 ]; then
  fail "a clean repository" "the suite failed: $out"
elif [ "$checked" -lt 1 ]; then
  fail "a clean repository" "no record was checked, so this fixture proves nothing: $out"
else
  pass "a clean repository passes, and its records are really checked"
fi

# 2. THE TRAP. Without ajv the suite validates nothing, says so, and still
# reports that every check passed.

make_repo
out=$(run_suite_without_tools)
code=$?
skipped=$(printf '%s\n' "$out" | grep -c "SKIP: 'ajv' is not installed")
checked=$(printf '%s\n' "$out" | grep -c 'Checking:')
if [ "$skipped" -lt 1 ]; then
  fail "a missing tool" "nothing was skipped, so ajv was still on PATH: $out"
elif [ "$checked" -ne 0 ]; then
  fail "a missing tool" "$checked record(s) were checked without ajv: $out"
elif [ "$code" -ne 0 ]; then
  fail "a missing tool" "expected the documented exit 0, got $code"
else
  case "$out" in
  *"All FACET lint checks passed"*)
    pass "a missing tool checks nothing, says so, and still reports success"
    ;;
  *) fail "a missing tool" "expected the passing summary, got: $out" ;;
  esac
fi

# 3. And the way out of it: FACET_STRICT_DEPS=1 turns that silence into a
# failure. This is the flag CI sets, and the only reason the case above is
# a documented behaviour rather than a defect.
make_repo
out=$( (cd "$WORK/repo" && PATH="$(path_without_tools)" FACET_STRICT_DEPS=1 \
  sh "$SCRIPT_DIR/run-all.sh" "$WORK/repo" 2>&1))
code=$?
case "$out" in
*"ERROR: 'ajv' is not installed (FACET_STRICT_DEPS=1)."*)
  if [ "$code" -eq 0 ]; then
    fail "a missing tool under strict deps" "it named the flag and still exited 0"
  else
    pass "a missing tool under strict deps is an error, not a skip"
  fi
  ;;
*) fail "a missing tool under strict deps" "expected the flag to be named, got: $out" ;;
esac

# 4. A record that does not match its schema fails the suite.
make_repo
printf 'schema_version: "0.1"\nid: broken\n' \
  >"$WORK/repo/docs/facets/features/tasks/create/broken.yaml"
out=$(run_suite)
code=$?
if [ "$code" -eq 0 ]; then
  fail "an invalid record" "the suite passed over it: $out"
else
  case "$out" in
  *broken.yaml*) pass "an invalid record fails the suite, named by file" ;;
  *) fail "an invalid record" "the file was not named: $out" ;;
  esac
fi

# 5. An anchor pointing at no record fails the suite.
make_repo
printf '// @facet: tasks/create/gone\nexport const x = 1;\n' >"$WORK/repo/src/gone.ts"
out=$(run_suite)
code=$?
if [ "$code" -eq 0 ]; then
  fail "an orphan anchor" "the suite passed over it: $out"
else
  case "$out" in
  *tasks/create/gone*) pass "an anchor pointing at no record fails the suite" ;;
  *) fail "an orphan anchor" "the id was not named: $out" ;;
  esac
fi

# 6. An active record nothing anchors fails the suite.
make_repo
rm "$WORK/repo/src/quick_add.ts"
out=$(run_suite)
code=$?
if [ "$code" -eq 0 ]; then
  fail "an unanchored active record" "the suite passed over it: $out"
else
  case "$out" in
  *quick-add*) pass "an active record nothing anchors fails the suite" ;;
  *) fail "an unanchored active record" "the record was not named: $out" ;;
  esac
fi

# 7. A record anchored only in a stylesheet counts as anchored.

make_repo
rm "$WORK/repo/src/quick_add.ts"
printf '/* @facet: tasks/create/quick-add */\n.a { color: red; }\n' >"$WORK/repo/src/app.css"
# The precondition: without the stylesheet this record IS reported, so the
# case measures the extension and not something else.
out=$(run_suite)
if [ $? -eq 0 ]; then
  : # unexpected; the assertion below will say so
fi
mv "$WORK/repo/src/app.css" "$WORK/repo/src/app.css.off"
out=$(run_suite)
if [ $? -eq 0 ]; then
  fail "fixture" "the record passes without any anchor at all, so this case proves nothing"
fi
mv "$WORK/repo/src/app.css.off" "$WORK/repo/src/app.css"

out=$(run_suite)
code=$?
if [ "$code" -ne 0 ]; then
  fail "an anchor in a stylesheet" "it was not counted: $out"
else
  pass "an anchor in a stylesheet counts, as it does for the binary"
fi

# 8. A failing check does not stop the ones after it.

make_repo
printf 'schema_version: "0.1"\nid: broken\n' \
  >"$WORK/repo/docs/facets/features/tasks/create/broken.yaml"
printf '// @facet: tasks/create/gone\nexport const x = 1;\n' >"$WORK/repo/src/gone.ts"
out=$(run_suite)
if printf '%s\n' "$out" | grep -q 'broken.yaml' && printf '%s\n' "$out" | grep -q 'tasks/create/gone'; then
  pass "a failing check does not hide the ones after it"
else
  fail "two failures at once" "only one of them was reported: $out"
fi

# Named mutation: omit the .facetignore source filter. A tracked consumer
# project then contributes unknown anchors to its parent registry.
make_repo
git -C "$WORK/repo" init -q
mkdir -p "$WORK/repo/examples/demo"
printf '// @facet: examples/consumer/unknown\n' >"$WORK/repo/examples/demo/example.js"
git -C "$WORK/repo" add examples
out=$(run_suite)
if [ $? -eq 0 ]; then
  fail "fixture" "the foreign consumer anchor did not fail before exclusion"
fi
printf '/examples/*\n!examples/kept.js\n' >"$WORK/repo/.facetignore"
out=$(run_suite)
if [ $? -ne 0 ]; then
  fail "tracked consumer registry" "explicit .facetignore was ignored: $out"
else
  pass "tracked consumer anchors respect .facetignore"
fi
printf '// @facet: examples/consumer/unknown\n' >"$WORK/repo/examples/kept.js"
out=$(run_suite)
if [ $? -eq 0 ]; then
  fail "negated ignore" "Git ignore negation hid a source which should stay visible"
else
  pass "negated .facetignore keeps selected consumer sources visible"
fi

# 9. A registries block: every registry's records directory is checked.

make_repo
mkdir -p "$WORK/repo/docs/facets/shop" "$WORK/repo/apps/admin/docs/facets/features/tasks/review"
mv "$WORK/repo/docs/facets/features" "$WORK/repo/docs/facets/shop/features"
sed 's#tasks/create/quick-add#tasks/review/approve#' \
  "$WORK/repo/docs/facets/shop/features/tasks/create/quick-add.yaml" \
  >"$WORK/repo/apps/admin/docs/facets/features/tasks/review/approve.yaml"
printf '// @facet: tasks/review/approve\n// @facet-role: primary\nexport function approve() {}\n' \
  >"$WORK/repo/src/approve.ts"
cat >"$WORK/repo/.facetrc.yaml" <<'CONFIG'
registries:
  shop:
    records: docs/facets/shop   # the storefront
    sources: [src]
  admin:
    records: "apps/admin/docs/facets"
    sources: [src]
CONFIG
if [ -d "$WORK/repo/docs/facets/features" ]; then
  fail "fixture" "the default records directory still exists, so this case proves nothing"
fi
out=$(run_suite)
code=$?
checked=$(printf '%s\n' "$out" | grep -c 'Checking:')
if [ "$code" -ne 0 ]; then
  fail "a registries block" "the suite failed: $out"
elif [ "$checked" -ne 2 ]; then
  fail "a registries block" "expected both registries' records checked, saw $checked: $out"
else
  pass "a registries block has every registry's records checked and resolved"
fi
printf 'schema_version: "0.1"\nid: broken\n' \
  >"$WORK/repo/apps/admin/docs/facets/features/tasks/review/broken.yaml"
printf '// @facet: tasks/review/gone\nexport const x = 1;\n' >"$WORK/repo/src/gone.ts"
out=$(run_suite)
if [ $? -eq 0 ]; then
  fail "a registries block" "a broken record and an unknown anchor passed: $out"
elif printf '%s\n' "$out" | grep -q 'broken.yaml' && printf '%s\n' "$out" | grep -q 'tasks/review/gone'; then
  pass "a broken record in the second registry and an unknown anchor still fail"
else
  fail "a registries block" "the failure did not name the broken record and the unknown id: $out"
fi

exit "$FAILED"
