#!/usr/bin/env bash
#
# Run all self-tests for octo-openapi-dev-skill.
#
# Used by:
#   - `make test` locally
#   - `.github/workflows/self-test.yml` in CI

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "═══════════════════════════════════════════════════════"
echo "  octo-openapi-dev-skill self-test suite"
echo "═══════════════════════════════════════════════════════"
echo

echo "═══ 1/4 check-swag-coverage.sh unit test ═══"
bash tests/fixtures/test-coverage-script.sh
echo

echo "═══ 2/4 spectral function unit tests ═══"
for t in tests/functions/*.test.mjs; do
  echo "--- $t ---"
  node "$t"
done
echo

echo "═══ 3/4 spectral rule fire-test (violations.yaml) ═══"
bash tests/fixtures/verify-rules-fire.sh
echo

echo "═══ 4/4 spectral clean-test (valid.yaml) ═══"
npx -y @stoplight/spectral-cli@latest lint tests/fixtures/valid.yaml \
  --ruleset octo-api/assets/spectral.yaml \
  --fail-severity error
echo

echo "✅ All self-tests passed"
