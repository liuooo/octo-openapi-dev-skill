#!/usr/bin/env bash
#
# Unit test for octo-api/scripts/check-prereqs.sh
#
# Scenarios:
#   1. Fully-prepared repo (+ committed baseline) → pass with --require-baseline
#   2. Missing main.go → fail, mentions main.go
#   3. main.go without global annotations → fail, mentions @title
#   4. No @Router anywhere → fail, mentions @Router
#   5. Baseline untracked: pass WITHOUT flag, fail WITH --require-baseline

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/octo-api/scripts/check-prereqs.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

assert() {
  local name="$1" actual="$2" expected="$3"
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

# Build a fully-prepared repo fixture
make_good_repo() {
  local dir="$1"
  mkdir -p "$dir/modules/mod" "$dir/docs/openapi"
  cat > "$dir/main.go" <<'EOF'
package main

// @title       Fixture API
// @version     1.0.0
// @BasePath    /v1
func main() {}
EOF
  cat > "$dir/modules/mod/handler.go" <<'EOF'
package mod

// Foo godoc
// @Router /foos [get]
func (s *Server) foo(c *wkhttp.Context) {}
EOF
  echo "openapi: 3.1.0" > "$dir/docs/openapi/swagger.yaml"
  git -C "$dir" init -q
  git -C "$dir" -c user.name=t -c user.email=t@t add docs/openapi/swagger.yaml
  git -C "$dir" -c user.name=t -c user.email=t@t commit -qm baseline
}

echo "Testing check-prereqs.sh..."

# ============================================================
# Scenario 1: fully prepared (+ baseline committed) → exit 0
# ============================================================
make_good_repo "$TMPDIR/good"
EXIT=0
(cd "$TMPDIR/good" && bash "$SCRIPT" docs/openapi --require-baseline >/dev/null 2>&1) || EXIT=$?
assert "scenario 1: prepared repo + baseline → exit 0" "$EXIT" "0"

# ============================================================
# Scenario 2: missing main.go → exit 1, names main.go
# ============================================================
mkdir -p "$TMPDIR/no_main"
EXIT=0
OUTPUT=$( (cd "$TMPDIR/no_main" && bash "$SCRIPT" 2>&1) ) || EXIT=$?
assert "scenario 2: no main.go → exit 1" "$EXIT" "1"
assert "scenario 2: message names main.go" "$(echo "$OUTPUT" | grep -c 'main.go not found')" "1"

# ============================================================
# Scenario 3: main.go without global annotations → exit 1
# ============================================================
make_good_repo "$TMPDIR/no_anno"
cat > "$TMPDIR/no_anno/main.go" <<'EOF'
package main

func main() {}
EOF
EXIT=0
OUTPUT=$( (cd "$TMPDIR/no_anno" && bash "$SCRIPT" 2>&1) ) || EXIT=$?
assert "scenario 3: missing @title/@BasePath → exit 1" "$EXIT" "1"
assert "scenario 3: message names the annotations" "$(echo "$OUTPUT" | grep -c '@title / @BasePath')" "1"

# ============================================================
# Scenario 4: no @Router anywhere → exit 1
# ============================================================
make_good_repo "$TMPDIR/no_router"
sed -i.bak '/@Router/d' "$TMPDIR/no_router/modules/mod/handler.go" && rm -f "$TMPDIR/no_router/modules/mod/handler.go.bak"
EXIT=0
OUTPUT=$( (cd "$TMPDIR/no_router" && bash "$SCRIPT" 2>&1) ) || EXIT=$?
assert "scenario 4: zero @Router → exit 1" "$EXIT" "1"
assert "scenario 4: message names @Router" "$(echo "$OUTPUT" | grep -c 'no @Router annotation')" "1"

# ============================================================
# Scenario 5: baseline untracked → flag-dependent
# ============================================================
make_good_repo "$TMPDIR/no_baseline"
git -C "$TMPDIR/no_baseline" rm -q --cached docs/openapi/swagger.yaml
EXIT=0
(cd "$TMPDIR/no_baseline" && bash "$SCRIPT" >/dev/null 2>&1) || EXIT=$?
assert "scenario 5a: untracked baseline, no flag → exit 0" "$EXIT" "0"
EXIT=0
OUTPUT=$( (cd "$TMPDIR/no_baseline" && bash "$SCRIPT" docs/openapi --require-baseline 2>&1) ) || EXIT=$?
assert "scenario 5b: untracked baseline + flag → exit 1" "$EXIT" "1"
assert "scenario 5b: message names baseline" "$(echo "$OUTPUT" | grep -c 'baseline not committed')" "1"

echo
echo "Total: $((PASS+FAIL))   Pass: $PASS   Fail: $FAIL"
[ "$FAIL" -eq 0 ]
