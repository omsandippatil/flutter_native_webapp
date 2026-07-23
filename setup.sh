#!/usr/bin/env bash

RAW_ROOT="${1:-.}"
MODE="${2:-analyze}"

if [[ "$MODE" != "analyze" && "$MODE" != "apply" ]]; then
  echo "ERROR: second argument must be 'analyze' or 'apply' (got '${MODE}')" >&2
  echo "Usage: $0 <project_root> [analyze|apply]" >&2
  exit 1
fi

if [[ ! -d "$RAW_ROOT" ]]; then
  echo "ERROR: not a directory: ${RAW_ROOT}" >&2
  exit 1
fi

ROOT="$(cd "$RAW_ROOT" && pwd -P)"
LIB="${ROOT}/lib"
DATA_MODELS="${LIB}/data/models"
PLAIN_MODELS="${LIB}/models"

if [[ ! -d "$LIB" ]]; then
  echo "ERROR: no lib/ under ${ROOT}" >&2
  exit 1
fi
if [[ ! -d "$DATA_MODELS" ]]; then
  echo "ERROR: no lib/data/models/ under ${ROOT}" >&2
  exit 1
fi
if [[ ! -d "$PLAIN_MODELS" ]]; then
  echo "ERROR: no lib/models/ under ${ROOT}" >&2
  exit 1
fi

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

pass() { printf '  \033[32m[%-10s]\033[0m %s\n' "$1" "$2"; }
warn() { printf '  \033[33m[%-10s]\033[0m %s\n' "$1" "$2"; }
fail() { printf '  \033[31m[%-10s]\033[0m %s\n' "$1" "$2"; }
info() { printf '  %s\n' "$1"; }

section() {
  echo ""
  echo "================================================================"
  echo " $1"
  echo "================================================================"
}

contains_line() {
  local needle="$1"
  local file="$2"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  grep -qxF -- "$needle" "$file"
  return $?
}

PAIRS="${WORK}/pairs.txt"
: > "$PAIRS"

while IFS= read -r data_file; do
  base="$(basename "$data_file")"
  plain_file="${PLAIN_MODELS}/${base}"
  if [[ -f "$plain_file" ]]; then
    printf '%s\t%s\t%s\n' "$data_file" "$plain_file" "$base" >> "$PAIRS"
  fi
done < <(find "$DATA_MODELS" -maxdepth 1 -name '*.dart' -type f | sort)

DATA_ONLY="${WORK}/data_only.txt"
: > "$DATA_ONLY"
while IFS= read -r data_file; do
  base="$(basename "$data_file")"
  plain_file="${PLAIN_MODELS}/${base}"
  if [[ ! -f "$plain_file" ]]; then
    echo "$data_file" >> "$DATA_ONLY"
  fi
done < <(find "$DATA_MODELS" -maxdepth 1 -name '*.dart' -type f | sort)

PAIRS_COUNT=0
if [[ -f "$PAIRS" ]]; then
  PAIRS_COUNT="$(wc -l < "$PAIRS" | tr -d ' ')"
fi

if [[ "$PAIRS_COUNT" -eq 0 ]]; then
  section "No data/models/X.dart vs models/X.dart pairs found"
  info "Nothing to consolidate. Exiting."
  exit 0
fi

section "1. Pairs found (data/models/X.dart vs models/X.dart)"

IDENTICAL_PAIRS="${WORK}/identical_pairs.txt"
DIFFERING_PAIRS="${WORK}/differing_pairs.txt"
: > "$IDENTICAL_PAIRS"
: > "$DIFFERING_PAIRS"

while IFS=$'\t' read -r data_file plain_file base; do
  echo ""
  echo "  ${base}"
  if cmp -s "$data_file" "$plain_file"; then
    pass "IDENTICAL " "data/models/${base} and models/${base} are byte-identical"
    printf '%s\t%s\t%s\n' "$data_file" "$plain_file" "$base" >> "$IDENTICAL_PAIRS"
  else
    fail "DIFFERS   " "content differs -- models/${base} would silently lose data if consolidated blindly"
    printf '%s\t%s\t%s\n' "$data_file" "$plain_file" "$base" >> "$DIFFERING_PAIRS"
    echo "    --- diff (data/models/${base} vs models/${base}) ---"
    diff -u "$data_file" "$plain_file" 2>/dev/null | sed 's/^/    /'
  fi
done < "$PAIRS"

IDENTICAL_COUNT="$(wc -l < "$IDENTICAL_PAIRS" | tr -d ' ')"
DIFFERING_COUNT="$(wc -l < "$DIFFERING_PAIRS" | tr -d ' ')"

echo ""
info "Total pairs: ${PAIRS_COUNT}  |  identical: ${IDENTICAL_COUNT}  |  differing: ${DIFFERING_COUNT}"

section "2. data/models/X.dart files with no models/ counterpart"

DATA_ONLY_COUNT=0
if [[ -f "$DATA_ONLY" ]]; then
  DATA_ONLY_COUNT="$(wc -l < "$DATA_ONLY" | tr -d ' ')"
fi

if [[ "$DATA_ONLY_COUNT" -gt 0 ]]; then
  info "These have nothing to consolidate onto. They will be MOVED into models/ (not deleted)."
  while IFS= read -r f; do
    echo "  ${f#"$ROOT"/}"
  done < "$DATA_ONLY"
else
  info "(none -- every data/models/ file has a models/ counterpart)"
fi

section "3. Imports referencing lib/data/models/ (across all of lib/)"

ALL_TARGET_BASENAMES="${WORK}/target_basenames.txt"
: > "$ALL_TARGET_BASENAMES"
cut -f3 "$PAIRS" >> "$ALL_TARGET_BASENAMES"
if [[ "$DATA_ONLY_COUNT" -gt 0 ]]; then
  while IFS= read -r f; do
    basename "$f" >> "$ALL_TARGET_BASENAMES"
  done < "$DATA_ONLY"
fi

IMPORT_REFS="${WORK}/import_refs.txt"
: > "$IMPORT_REFS"

ALL_DART_FILES="${WORK}/all_dart_files.txt"
find "$LIB" -type f -name '*.dart' > "$ALL_DART_FILES"

while IFS= read -r importer; do
  IMPORT_LINES="${WORK}/one_file_imports.txt"
  grep -E "^\s*(import|export)\s+['\"]" "$importer" > "$IMPORT_LINES" 2>/dev/null
  if [[ ! -s "$IMPORT_LINES" ]]; then
    continue
  fi
  while IFS= read -r raw_line; do
    line="$(printf '%s' "$raw_line" | sed -E 's/^[[:space:]]*//')"
    case "$line" in
      //*)
        continue
        ;;
    esac
    uri="$(printf '%s' "$line" | sed -nE "s/^(import|export)[[:space:]]+['\"]([^'\"]+)['\"].*/\2/p")"
    if [[ -z "$uri" ]]; then
      continue
    fi
    case "$uri" in
      *data/models/*.dart)
        base="$(basename "$uri")"
        if contains_line "$base" "$ALL_TARGET_BASENAMES"; then
          printf '%s\t%s\t%s\n' "$importer" "$uri" "$base" >> "$IMPORT_REFS"
        fi
        ;;
    esac
  done < "$IMPORT_LINES"
done < "$ALL_DART_FILES"

REF_COUNT=0
if [[ -f "$IMPORT_REFS" ]]; then
  REF_COUNT="$(wc -l < "$IMPORT_REFS" | tr -d ' ')"
fi

if [[ "$REF_COUNT" -eq 0 ]]; then
  info "(no imports reference lib/data/models/ for the files in scope)"
else
  info "${REF_COUNT} import statement(s) will need repointing:"
  while IFS=$'\t' read -r importer uri base; do
    echo "  ${importer#"$ROOT"/}  imports '${uri}'"
  done < "$IMPORT_REFS"
fi

if [[ "$MODE" == "analyze" ]]; then
  section "ANALYZE MODE -- no files changed"
  echo "  Re-run as:"
  echo "    $0 \"$RAW_ROOT\" apply"
  echo "  to actually repoint imports, move/delete data/models files, and consolidate onto models/."
  echo ""
  echo "  Pairs marked DIFFERS will NOT be auto-resolved even in apply mode."
  echo "  Those need manual review first -- apply mode will skip them and print a reminder."
  exit 0
fi

section "APPLYING: repointing imports from data/models/X.dart to models/X.dart"

SAFE_BASENAMES="${WORK}/safe_basenames.txt"
: > "$SAFE_BASENAMES"
if [[ "$IDENTICAL_COUNT" -gt 0 ]]; then
  cut -f3 "$IDENTICAL_PAIRS" >> "$SAFE_BASENAMES"
fi
if [[ "$DATA_ONLY_COUNT" -gt 0 ]]; then
  while IFS= read -r f; do
    basename "$f" >> "$SAFE_BASENAMES"
  done < "$DATA_ONLY"
fi

REPOINTED=0
SKIPPED_DIFFERING=0

while IFS= read -r importer; do
  IMPORT_LINES="${WORK}/one_file_imports2.txt"
  grep -E "^\s*(import|export)\s+['\"]" "$importer" > "$IMPORT_LINES" 2>/dev/null
  if [[ ! -s "$IMPORT_LINES" ]]; then
    continue
  fi
  changed_this_file=0
  while IFS= read -r raw_line; do
    line="$(printf '%s' "$raw_line" | sed -E 's/^[[:space:]]*//')"
    case "$line" in
      //*)
        continue
        ;;
    esac
    uri="$(printf '%s' "$line" | sed -nE "s/^(import|export)[[:space:]]+['\"]([^'\"]+)['\"].*/\2/p")"
    if [[ -z "$uri" ]]; then
      continue
    fi
    case "$uri" in
      *data/models/*.dart)
        base="$(basename "$uri")"
        if contains_line "$base" "$SAFE_BASENAMES"; then
          new_uri="${uri//data\/models\//models/}"
          esc_old="$(printf '%s' "$uri" | sed -e 's/[\/&]/\\&/g')"
          esc_new="$(printf '%s' "$new_uri" | sed -e 's/[\/&]/\\&/g')"
          sed -i "s/${esc_old}/${esc_new}/g" "$importer"
          changed_this_file=1
          REPOINTED=$((REPOINTED + 1))
        elif contains_line "$base" "$ALL_TARGET_BASENAMES"; then
          SKIPPED_DIFFERING=$((SKIPPED_DIFFERING + 1))
        fi
        ;;
    esac
  done < "$IMPORT_LINES"
  if [[ "$changed_this_file" -eq 1 ]]; then
    echo "  repointed imports in ${importer#"$ROOT"/}"
  fi
done < "$ALL_DART_FILES"

echo ""
info "Repointed ${REPOINTED} import statement(s)."
if [[ "$SKIPPED_DIFFERING" -gt 0 ]]; then
  warn "SKIPPED   " "${SKIPPED_DIFFERING} import(s) left untouched because they target a DIFFERING pair."
fi

section "APPLYING: removing data/models/ duplicates now safely repointed"

DELETED=0
if [[ "$IDENTICAL_COUNT" -gt 0 ]]; then
  while IFS=$'\t' read -r data_file plain_file base; do
    rm -f "$data_file"
    echo "  deleted ${data_file#"$ROOT"/}  (kept models/${base})"
    DELETED=$((DELETED + 1))
  done < "$IDENTICAL_PAIRS"
fi

if [[ "$DATA_ONLY_COUNT" -gt 0 ]]; then
  section "APPLYING: moving data/models/-only files into models/"
  while IFS= read -r f; do
    base="$(basename "$f")"
    dest="${PLAIN_MODELS}/${base}"
    mv "$f" "$dest"
    echo "  moved ${f#"$ROOT"/}  ->  ${dest#"$ROOT"/}"
    DELETED=$((DELETED + 1))
  done < "$DATA_ONLY"
fi

if [[ "$DIFFERING_COUNT" -gt 0 ]]; then
  section "MANUAL ACTION STILL REQUIRED"
  warn "PENDING   " "${DIFFERING_COUNT} pair(s) were left in place because content differs:"
  while IFS=$'\t' read -r data_file plain_file base; do
    echo "    - ${base}: diff \"${data_file#"$ROOT"/}\" \"${plain_file#"$ROOT"/}\""
  done < "$DIFFERING_PAIRS"
  echo ""
  info "For each: decide the correct field set, edit models/${base} by hand,"
  info "then delete lib/data/models/${base} and re-run this script in apply mode."
fi

section "APPLYING: removing now-empty directories"

DATA_MODELS_CONTENTS="$(ls -A "$DATA_MODELS" 2>/dev/null)"
if [[ -d "$DATA_MODELS" && -z "$DATA_MODELS_CONTENTS" ]]; then
  rmdir "$DATA_MODELS"
  echo "  removed empty directory: ${DATA_MODELS#"$ROOT"/}"
else
  info "lib/data/models/ left in place (still has content pending manual reconcile)"
fi

DATA_DIR="${LIB}/data"
DATA_DIR_CONTENTS="$(ls -A "$DATA_DIR" 2>/dev/null)"
if [[ -d "$DATA_DIR" && -z "$DATA_DIR_CONTENTS" ]]; then
  rmdir "$DATA_DIR"
  echo "  removed empty directory: ${DATA_DIR#"$ROOT"/}"
fi

section "SUMMARY"
echo "  pairs found:              ${PAIRS_COUNT}"
echo "  identical (consolidated): ${IDENTICAL_COUNT}"
echo "  differing (left pending): ${DIFFERING_COUNT}"
echo "  data-only (moved):        ${DATA_ONLY_COUNT}"
echo "  imports repointed:        ${REPOINTED}"
echo ""
echo "  Next steps:"
echo "    1. Run: flutter analyze"
echo "    2. Resolve any DIFFERING pairs listed above by hand, then re-run in apply mode."
echo "    3. Run your dead-file analyzer again to confirm nothing was left behind."