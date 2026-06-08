#!/usr/bin/env bash
#
# diff-openapi.sh — Compare current OpenAPI spec against a base git ref.
#
# Outputs a unified text diff. Does NOT classify breaking vs non-breaking
# — that judgment is left to a reviewer or AI looking at the diff
# (semantic OpenAPI diff would need oasdiff, which is on the roadmap).
#
# Usage:
#   bash tools/octo-api/scripts/diff-openapi.sh [base_ref]
#
# Examples:
#   bash tools/octo-api/scripts/diff-openapi.sh                 # compare HEAD against origin/main
#   bash tools/octo-api/scripts/diff-openapi.sh origin/release  # compare against release branch
#   bash tools/octo-api/scripts/diff-openapi.sh v0.5.0          # compare against a tag
#
# Exit codes:
#   0 — no spec change
#   1 — spec changed (review needed) OR base ref not found

set -euo pipefail

BASE_REF="${1:-origin/main}"
SPEC_FILES=("docs/openapi/swagger.yaml" "docs/openapi/swagger.json")
CURRENT_DIR="$(pwd)"

if [ ! -f "${SPEC_FILES[0]}" ]; then
  echo "❌ Current spec not found: ${SPEC_FILES[0]}"
  echo "   Run 'make openapi-gen' first to generate the current spec."
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Fetch base spec from git
BASE_AVAILABLE=true
for f in "${SPEC_FILES[@]}"; do
  if ! git show "$BASE_REF:$f" > "$TMP_DIR/$(basename "$f")" 2>/dev/null; then
    BASE_AVAILABLE=false
    break
  fi
done

if [ "$BASE_AVAILABLE" = false ]; then
  echo "⚠️  Base spec not found in $BASE_REF (first time? wrong ref?)"
  echo "    Tried: $BASE_REF:${SPEC_FILES[0]}"
  echo ""
  echo "If this is the first time the spec is being committed, this is expected."
  echo "After this PR merges, future PRs can diff against $BASE_REF."
  exit 1
fi

# Diff
CHANGED=false
for f in "${SPEC_FILES[@]}"; do
  base_file="$TMP_DIR/$(basename "$f")"
  if ! diff -q "$base_file" "$f" >/dev/null 2>&1; then
    CHANGED=true
    echo "═══════════════════════════════════════════════════════"
    echo "  Diff: $f  ($BASE_REF → HEAD)"
    echo "═══════════════════════════════════════════════════════"
    diff -u "$base_file" "$f" || true
    echo ""
  fi
done

if [ "$CHANGED" = false ]; then
  echo "✅ No OpenAPI spec change between $BASE_REF and HEAD"
  exit 0
fi

cat <<EOF

───────────────────────────────────────────────────────
  Reviewer / AI: classify each diff entry below
───────────────────────────────────────────────────────

🔴 Breaking changes (require deprecate flow or version bump):
   • Removed property / endpoint / response code
   • Changed property type (int → string, optional → required type narrowing)
   • Added required parameter / required property
   • Made optional field required
   • Restricted enum values (removed members)
   • Renamed property (json key changed)
   • Tightened validation (max=200 → max=100, etc.)

🟢 Non-breaking changes (safe to ship):
   • Added optional property / parameter
   • Added new endpoint
   • Added new response code
   • Expanded enum values (added members)
   • Relaxed validation (max=100 → max=200)
   • Updated description / summary only

If any diff falls into the breaking category, plan accordingly:
   1. Confirm with API consumers (octo-cli, client SDKs) before merging
   2. Consider a deprecate flow on the old shape
   3. Document in PR description

EOF
exit 1
