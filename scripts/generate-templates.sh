#!/usr/bin/env bash
#
# Generate hindsight-docs/src/data/templates.json from the
# hindsight-bank-templates package. Flattens the catalog by inlining each
# manifest file under the `manifest` field so the Templates Hub page can
# consume a single committed import.
#
# Runs as part of the verify-generated-files CI job — re-run locally when
# editing anything under hindsight-bank-templates/ and commit the regenerated
# templates.json alongside your source change.
#
# Usage: ./scripts/generate-templates.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TPL_ROOT="$REPO_ROOT/hindsight-bank-templates"
CATALOG="$TPL_ROOT/templates.json"
OUT="$REPO_ROOT/hindsight-docs/src/data/templates.json"

if [ ! -f "$CATALOG" ]; then
  echo -e "\033[31m✗\033[0m Source catalog not found: $CATALOG" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "\033[31m✗\033[0m jq is required but not installed" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

LEN=$(jq '.templates | length' "$CATALOG")
RESULT='{"templates": []}'

for i in $(seq 0 $((LEN - 1))); do
  ENTRY=$(jq ".templates[$i]" "$CATALOG")
  MANIFEST_FILE=$(echo "$ENTRY" | jq -r '.manifest_file')
  MANIFEST_PATH="$TPL_ROOT/$MANIFEST_FILE"

  if [ ! -f "$MANIFEST_PATH" ]; then
    echo -e "\033[31m✗\033[0m Manifest not found: $MANIFEST_PATH" >&2
    exit 1
  fi

  MANIFEST=$(jq '.' "$MANIFEST_PATH")
  MERGED=$(echo "$ENTRY" | jq --argjson m "$MANIFEST" '. + {manifest: $m} | del(.manifest_file)')
  RESULT=$(echo "$RESULT" | jq --argjson e "$MERGED" '.templates += [$e]')
done

echo "$RESULT" > "$OUT"
COUNT=$(echo "$RESULT" | jq '.templates | length')
echo -e "\033[32m✓\033[0m Generated $OUT ($COUNT templates)"
