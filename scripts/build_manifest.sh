#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOWS_DIR="$ROOT_DIR/assets/flows"
LANGS=(en hi kn mr pa)

for LANG in "${LANGS[@]}"; do
  LANG_DIR="$FLOWS_DIR/$LANG"
  [ -d "$LANG_DIR" ] || continue

  OUT_FILE="$LANG_DIR/flow_manifest.json"
  TMP_FILE="$(mktemp)"

  echo "{" > "$TMP_FILE"
  echo "  \"flows\": {" >> "$TMP_FILE"

  CATEGORIES=()
  for CAT_DIR in "$LANG_DIR"/*/; do
    [ -d "$CAT_DIR" ] || continue
    CATEGORIES+=("$(basename "$CAT_DIR")")
  done

  for i in "${!CATEGORIES[@]}"; do
    CAT="${CATEGORIES[$i]}"
    CAT_DIR="$LANG_DIR/$CAT"

    echo "    \"$CAT\": {" >> "$TMP_FILE"

    FILES=()
    for FILE in "$CAT_DIR"/*.json; do
      [ -e "$FILE" ] || continue
      FILES+=("$(basename "$FILE")")
    done

    for j in "${!FILES[@]}"; do
      FNAME="${FILES[$j]}"
      COMMA=","
      if [ "$j" -eq $((${#FILES[@]} - 1)) ]; then
        COMMA=""
      fi
      echo "      \"$FNAME\": { \"languages\": [\"$LANG\"] }$COMMA" >> "$TMP_FILE"
    done

    CLOSE_COMMA=","
    if [ "$i" -eq $((${#CATEGORIES[@]} - 1)) ]; then
      CLOSE_COMMA=""
    fi
    echo "    }$CLOSE_COMMA" >> "$TMP_FILE"
  done

  echo "  }" >> "$TMP_FILE"
  echo "}" >> "$TMP_FILE"

  mv "$TMP_FILE" "$OUT_FILE"
  echo "Wrote $OUT_FILE"
done
