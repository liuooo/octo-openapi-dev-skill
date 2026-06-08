#!/usr/bin/env bash
#
# Unit test for octo-api/scripts/check-swag-coverage.sh
#
# Verifies behavior across 4 scenarios:
#   1. Handler with @Router annotation — should NOT be reported
#   2. Handler without any swag annotation — SHOULD be reported
#   3. Handler with @Summary but missing @Router — SHOULD be reported
#   4. Non-handler function (no Context parameter) — should be ignored

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/octo-api/scripts/check-swag-coverage.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

assert() {
  local name="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name"
    echo "     expected: $expected"
    echo "     actual:   $actual"
    FAIL=$((FAIL+1))
  fi
}

echo "Testing check-swag-coverage.sh..."

# ============================================================
# Scenario 1: handler with @Router → coverage 100%
# ============================================================
mkdir -p "$TMPDIR/scenario1/mod"
cat > "$TMPDIR/scenario1/mod/handler.go" <<'EOF'
package mod

import "github.com/Mininglamp-OSS/octo-lib/pkg/wkhttp"

// Foo godoc
// @Summary Foo handler
// @Router /v1/foo [get]
func (s *Server) foo(c *wkhttp.Context) {
}
EOF
OUTPUT=$(bash "$SCRIPT" "$TMPDIR/scenario1" 2>&1 || true)
COVERAGE=$(echo "$OUTPUT" | grep "Coverage:" | grep -oE "[0-9]+\.[0-9]+" | head -1)
assert "scenario 1: handler with @Router → coverage 100.0%" "$COVERAGE" "100.0"

# ============================================================
# Scenario 2: handler without annotations → reported
# ============================================================
mkdir -p "$TMPDIR/scenario2/mod"
cat > "$TMPDIR/scenario2/mod/handler.go" <<'EOF'
package mod

import "github.com/Mininglamp-OSS/octo-lib/pkg/wkhttp"

func (s *Server) bar(c *wkhttp.Context) {
}
EOF
OUTPUT=$(bash "$SCRIPT" "$TMPDIR/scenario2" 2>&1 || true)
echo "$OUTPUT" | grep -q "bar" && hit="yes" || hit="no"
assert "scenario 2: handler without annotation → reported" "$hit" "yes"

# ============================================================
# Scenario 3: handler with @Summary but missing @Router
# ============================================================
mkdir -p "$TMPDIR/scenario3/mod"
cat > "$TMPDIR/scenario3/mod/handler.go" <<'EOF'
package mod

import "github.com/Mininglamp-OSS/octo-lib/pkg/wkhttp"

// Baz godoc
// @Summary Baz handler
// (missing @Router on purpose)
func (s *Server) baz(c *wkhttp.Context) {
}
EOF
OUTPUT=$(bash "$SCRIPT" "$TMPDIR/scenario3" 2>&1 || true)
echo "$OUTPUT" | grep -q "baz" && hit="yes" || hit="no"
assert "scenario 3: @Summary but missing @Router → reported" "$hit" "yes"

# ============================================================
# Scenario 4: non-handler functions (no Context) → ignored
# ============================================================
mkdir -p "$TMPDIR/scenario4/mod"
cat > "$TMPDIR/scenario4/mod/helper.go" <<'EOF'
package mod

// helper is not a gin handler, just a normal function
func (s *Server) helper(arg string) error {
  return nil
}

func someStandaloneFunction() string {
  return "ok"
}
EOF
OUTPUT=$(bash "$SCRIPT" "$TMPDIR/scenario4" 2>&1 || true)
HANDLERS=$(echo "$OUTPUT" | grep "Handlers found:" | grep -oE "[0-9]+" | head -1)
assert "scenario 4: non-handler functions → not counted" "$HANDLERS" "0"

# ============================================================
# Scenario 5: mixed (handler with @Router + handler without) → reports only the missing one
# ============================================================
mkdir -p "$TMPDIR/scenario5/mod"
cat > "$TMPDIR/scenario5/mod/mixed.go" <<'EOF'
package mod

import "github.com/Mininglamp-OSS/octo-lib/pkg/wkhttp"

// Annotated godoc
// @Router /v1/annotated [get]
func (s *Server) annotated(c *wkhttp.Context) {
}

func (s *Server) missing(c *wkhttp.Context) {
}
EOF
OUTPUT=$(bash "$SCRIPT" "$TMPDIR/scenario5" 2>&1 || true)
echo "$OUTPUT" | grep -q "annotated" && reports_annotated="yes" || reports_annotated="no"
echo "$OUTPUT" | grep -q "missing" && reports_missing="yes" || reports_missing="no"
assert "scenario 5: annotated handler not in report" "$reports_annotated" "no"
assert "scenario 5: unannotated handler in report" "$reports_missing" "yes"

# ============================================================
# Summary
# ============================================================
echo
echo "Total: $((PASS+FAIL))   Pass: $PASS   Fail: $FAIL"
[ "$FAIL" -eq 0 ]
