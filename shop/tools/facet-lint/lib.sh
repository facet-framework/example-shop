#!/usr/bin/env sh
# Shared discovery helpers for the FACET lint scripts. Sourced, never executed.

# Directories never worth scanning for source anchors. This is the floor, not
# the whole story: inside a git work tree the repository's own ignore rules are
# applied on top (see facet_drop_gitignored), the way the Go anchor scanner
# (ScanAnchors) already does it.
FACET_PRUNE_DIRS=".git node_modules vendor target dist build out coverage
.venv venv __pycache__ .next .nuxt .svelte-kit .terraform .gradle .idea
.mypy_cache .pytest_cache .tox .cache .claude-plugin"

FACET_CONFIG_NAME=".facetrc.yaml"

# Keep only the paths the repository itself considers its own, reading the
# candidate list on stdin and printing what survives.

facet_drop_gitignored() {
  _giroot="$1"
  _gilist=$(cat)
  [ -n "$_gilist" ] || return 0
  command -v git >/dev/null 2>&1 || {
    printf '%s\n' "$_gilist"
    return 0
  }
  _gitop=$(git -C "$_giroot" rev-parse --show-toplevel 2>/dev/null) || {
    printf '%s\n' "$_gilist"
    return 0
  }
  [ -n "$_gitop" ] || {
    printf '%s\n' "$_gilist"
    return 0
  }
  _gitmp=$(mktemp 2>/dev/null) || {
    printf '%s\n' "$_gilist"
    return 0
  }
  git -C "$_gitop" ls-files --cached --others --exclude-standard 2>/dev/null |
    awk -v p="$_gitop/" '{print p $0}' >"$_gitmp"
  _gikept=$(printf '%s\n' "$_gilist" | grep -Fxf "$_gitmp" 2>/dev/null)
  rm -f "$_gitmp"
  if [ -z "$_gikept" ]; then
    printf '%s\n' "$_gilist"
  else
    printf '%s\n' "$_gikept"
  fi
}

# Read one top-level scalar key out of .facetrc.yaml.

facet_config_value() {
  _root="$1"
  _key="$2"
  [ -f "$_root/$FACET_CONFIG_NAME" ] || return 1
  _val=$(sed -n "s/^$_key:[[:space:]]*//p" "$_root/$FACET_CONFIG_NAME" |
    head -n 1 | sed 's/[[:space:]]*#.*$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//')
  [ -n "$_val" ] || return 1
  printf '%s\n' "$_val"
}

# True when the project declares several registries, which the shell fallback
# cannot resolve. Callers say so rather than quietly reporting the default
# layout, which in such a project is nobody's layout.
facet_declares_registries() {
  [ -f "$1/$FACET_CONFIG_NAME" ] || return 1
  grep -q '^registries:' "$1/$FACET_CONFIG_NAME" 2>/dev/null
}

# Print every records directory the project declares, absolute, one per line.

facet_records_dirs() {
  _root="$1"
  if [ -z "$FACET_RECORDS_DIR" ] && facet_declares_registries "$_root"; then
    _found=$(awk '
      /^registries:[[:space:]]*(#.*)?$/ { inside = 1; next }
      inside && /^[^[:space:]#]/ { inside = 0 }
      inside && /^[[:space:]]+records:[[:space:]]*[^[:space:]#]/ {
        value = $0
        sub(/^[[:space:]]+records:[[:space:]]*/, "", value)
        sub(/[[:space:]]*#.*$/, "", value)
        gsub(/^["'\'']|["'\'']$/, "", value)
        print value
      }
    ' "$_root/$FACET_CONFIG_NAME")
    if [ -n "$_found" ]; then
      printf '%s\n' "$_found" | while IFS= read -r _dir; do
        case "$_dir" in
        /*) printf '%s\n' "$_dir" ;;
        *) printf '%s\n' "$_root/$_dir" ;;
        esac
      done
      return 0
    fi
  fi
  facet_records_dir "$_root"
}

facet_records_dir() {
  _root="$1"
  if [ -n "$FACET_RECORDS_DIR" ]; then
    _dir="$FACET_RECORDS_DIR"
  else
    _dir=$(facet_config_value "$_root" records) || _dir="docs/facets"
  fi
  case "$_dir" in
  /*) printf '%s\n' "$_dir" ;;
  *) printf '%s\n' "$_root/$_dir" ;;
  esac
}

# Schema location. Prefers the consumer's own copy so local schema edits win,
# then falls back to the copy bundled with the plugin (if invoked from one).
facet_schema_dir() {
  _root="$1"
  _declared="$FACET_SCHEMA_DIR"
  [ -n "$_declared" ] || _declared=$(facet_config_value "$_root" schema) || _declared=""
  if [ -n "$_declared" ]; then
    case "$_declared" in
    /*) printf '%s\n' "$_declared" ;;
    *) printf '%s\n' "$_root/$_declared" ;;
    esac
    return 0
  fi
  _local="$(facet_records_dir "$_root")/schema"
  if [ -d "$_local" ]; then
    printf '%s\n' "$_local"
  elif [ -d "$_root/schema" ] && [ -f "$_root/schema/facet.schema.json" ]; then
    # The FACET framework repo itself keeps the canonical schemas at the root
    # rather than a vendored copy under the records directory.
    printf '%s\n' "$_root/schema"
  elif [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -d "$CLAUDE_PLUGIN_ROOT/schema" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT/schema"
  else
    printf '%s\n' "$_local"
  fi
}

# Print the top-level 'sources:' list, space separated. Handles both the flow
# form ([a, b]) and the block form (one '- a' per line); nothing deeper, for the
# same reason facet_config_value stops where it does.
facet_config_sources() {
  _root="$1"
  [ -f "$_root/$FACET_CONFIG_NAME" ] || return 0
  _flow=$(sed -n 's/^sources:[[:space:]]*\[\(.*\)\].*/\1/p' "$_root/$FACET_CONFIG_NAME" | head -n 1)
  if [ -n "$_flow" ]; then
    printf '%s\n' "$_flow" | tr ',' ' ' | tr -d '"'"'"
    return 0
  fi
  sed -n '/^sources:[[:space:]]*$/,/^[^[:space:]-]/p' "$_root/$FACET_CONFIG_NAME" |
    sed -n 's/^[[:space:]]*-[[:space:]]*//p' | tr -d '"'"'" | tr '\n' ' '
}

# Print every source file that may carry an @facet: tag, one path per line.

facet_source_files() {
  _root="$1"

  _dirs="$FACET_SOURCE_DIRS"
  [ -n "$_dirs" ] || _dirs=$(facet_config_sources "$_root")

  set --
  if [ -n "$_dirs" ]; then
    for _d in $_dirs; do
      [ -d "$_root/$_d" ] && set -- "$@" "$_root/$_d"
    done
    [ "$#" -eq 0 ] && return 0
  else
    set -- "$_root"
  fi

  # Include stylesheets accepted by ScanAnchors so stylesheet-only anchors
  # cannot pass the Go scan but appear orphaned here. This walker uses an
  # extension allowlist; ScanAnchors excludes prose formats instead.
  _exts="${FACET_SOURCE_EXTS:-rs go ts tsx js jsx mjs cjs vue svelte py rb java kt kts scala cs php swift dart ex exs c h cc cpp hpp m mm sql yaml yml tf hcl ini toml sh bash zsh css scss less}"
  _ext_re=$(printf '%s' "$_exts" | tr ' ' '|')

  # Prune expression is built as a single -name a -o -name b ... group.
  _prune_expr=""
  for _p in $FACET_PRUNE_DIRS; do
    if [ -z "$_prune_expr" ]; then
      _prune_expr="-name $_p"
    else
      _prune_expr="$_prune_expr -o -name $_p"
    fi
  done

  # Word-splitting on $_prune_expr is deliberate: it is a find expression,
  # built above from a fixed list with no spaces in any element.
  # shellcheck disable=SC2086
  _all=$(find "$@" \( $_prune_expr \) -prune -o -type f -print 2>/dev/null |
    facet_drop_gitignored "$_root")

  # Separate consumer registries can demonstrate their own anchors. Honour
  # FACET's explicit ignore file for tracked sources as well as new files,
  # using Git's pattern semantics rather than maintaining a second parser.
  if [ -f "$_root/.facetignore" ] && command -v git >/dev/null 2>&1; then
    _fitop=$(git -C "$_root" rev-parse --show-toplevel 2>/dev/null) || _fitop=""
    if [ -n "$_fitop" ]; then
      _fiignored=$(git -C "$_root" ls-files --full-name --cached --others --ignored \
        --exclude-from="$_root/.facetignore" 2>/dev/null |
        awk -v p="$_fitop/" '{print p $0}')
      if [ -n "$_fiignored" ]; then
        _all=$(printf '%s\n' "$_fiignored" '@FACET_SOURCE_LIST@' "$_all" |
          awk '
              $0 == "@FACET_SOURCE_LIST@" { sources = 1; next }
              !sources { ignored[$0] = 1; next }
              !($0 in ignored) { print }
            ')
      fi
    fi
  fi

  # A file declaring '@facet-ignore-file' in its head demonstrates the tag
  # syntax rather than using it — test fixtures, scaffolding templates, code
  # generators — so it is excluded entirely.

  _drop_ignored() {
    while IFS= read -r _p; do
      [ -n "$_p" ] || continue
      head -n 10 "$_p" 2>/dev/null | grep -q '@facet-ignore''-file' && continue
      printf '%s\n' "$_p"
    done
  }

  printf '%s\n' "$_all" | grep -Ei "\.($_ext_re)$" | _drop_ignored

  # Executables conventionally carry no extension, so an extension filter alone
  # is blind to everything in bin/. Anything whose basename has no dot counts as
  # source when it starts with a shebang.
  printf '%s\n' "$_all" | grep -v '/[^/]*\.[^/]*$' | while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    case "$(head -c 2 "$_f" 2>/dev/null)" in
    '#!') printf '%s\n' "$_f" ;;
    esac
  done | _drop_ignored
}

# Convert a YAML file to JSON on stdout.

facet_yaml_to_json() {
  _file="$1"
  case "$FACET_YQ_MODE" in
  go) yq -o=json '.' "$_file" ;;
  python) yq '.' "$_file" ;;
  none) return 1 ;;
  *)
    if printf 'facet_probe: 1\n' | yq -o=json '.' 2>/dev/null | grep -q 'facet_probe'; then
      FACET_YQ_MODE=go
    elif printf 'facet_probe: 1\n' | yq '.' 2>/dev/null | grep -q '"facet_probe"'; then
      FACET_YQ_MODE=python
    else
      FACET_YQ_MODE=none
      return 1
    fi
    facet_yaml_to_json "$_file"
    ;;
  esac
}

# Report a missing external dependency. Returns 1 when the caller should treat
# it as fatal, 0 when the check should be skipped.
facet_require_tool() {
  _tool="$1"
  if command -v "$_tool" >/dev/null 2>&1; then
    return 0
  fi
  _facet_dep_missing "'$_tool' is not installed"
}

# Same contract as facet_require_tool, but checks that a *working* YAML-to-JSON
# converter exists rather than that some binary named yq is on PATH.
facet_require_yaml_converter() {
  if facet_yaml_to_json /dev/null >/dev/null 2>&1 || [ "$FACET_YQ_MODE" != "none" ]; then
    return 0
  fi
  _facet_dep_missing "no working YAML-to-JSON converter found (need yq)"
}

_facet_dep_missing() {
  if [ "$FACET_STRICT_DEPS" = "1" ]; then
    echo "  ERROR: $1 (FACET_STRICT_DEPS=1)."
    return 1
  fi
  echo "  SKIP: $1 — skipping this check."
  echo "        Install it, or set FACET_STRICT_DEPS=1 to make this an error."
  return 2
}
