#!/usr/bin/env bash
#
# Verifies each OCTO custom rule fires on the expected path in violations.yaml.
# Goes beyond "count errors > 0" to assert per-rule per-path coverage.
#
# Run after editing spectral.yaml or violations.yaml.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TMP_JSON=$(mktemp)
trap 'rm -f "$TMP_JSON"' EXIT

npx -y @stoplight/spectral-cli@latest lint \
  tests/fixtures/violations.yaml \
  --ruleset octo-api/assets/spectral.yaml \
  --format json > "$TMP_JSON" 2>/dev/null || true

python3 - "$TMP_JSON" <<'PY'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

# (rule_code, expected_endpoint_path) — every OCTO rule should fire on at
# least one of these. The endpoint path is the key under paths.
expected = {
    # primary cases
    ("octo-summary-required",        "/no_summary"),
    ("octo-summary-length-exceeded", "/long_summary"),
    ("octo-summary-english-verb",    "/lowercase_summary"),
    ("octo-tags-single",             "/multi_tags"),
    ("octo-tags-lowercase",          "/upper_tag"),
    ("octo-operation-id-format",     "/bad_id"),
    ("octo-path-snake-case",         "/Users"),
    ("octo-path-resource-singular",  "/matter/{matter_id}"),
    ("octo-path-param-id-suffix",    "/matters/{matter_no}"),
    ("octo-path-param-no-uid",       "/matters/{uid}"),
    ("octo-response-uses-envelope",  "/raw_success"),
    ("octo-auth-has-401",            "/auth_no_401"),
    ("octo-auth-has-403",            "/auth_no_401"),
    # boundary cases
    ("octo-summary-required",        "/empty_summary"),
    ("octo-summary-length-exceeded", "/summary_81_chars"),
    ("octo-tags-single",             "/zero_tags"),
    ("octo-tags-single",             "/three_tags"),
    ("octo-operation-id-format",     "/opid_one_part"),
    ("octo-operation-id-format",     "/opid_four_parts"),
    ("octo-path-resource-singular",  "/groups/{group_id}/user/{user_id}"),
    ("octo-path-resource-singular",  "/manager/backup/{backup_id}"),  # singular non-resource prefix
    ("octo-path-resource-singular",  "/admin/users"),                 # singular non-resource prefix
}

# Rules that fire on schema fields (not path endpoints)
schema_expected = {
    "octo-schema-property-snake-case",
    "octo-schema-time-at-suffix",
    "octo-schema-url-suffix",
    "octo-schema-boolean-prefix",
    "octo-openapi-version",
}

path_hits = set()
schema_hits = set()
for item in data:
    code = item.get("code", "")
    path = item.get("path", [])
    if len(path) >= 2 and path[0] == "paths":
        endpoint = path[1]
        if (code, endpoint) in expected:
            path_hits.add((code, endpoint))
    if code in schema_expected:
        schema_hits.add(code)

missing_path = expected - path_hits
missing_schema = schema_expected - schema_hits

print(f"Endpoint rules: {len(path_hits)}/{len(expected)} fired")
print(f"Schema rules:   {len(schema_hits)}/{len(schema_expected)} fired")
print()

for e in sorted(expected):
    mark = "✅" if e in path_hits else "❌"
    print(f"  {mark} {e[0]} on {e[1]}")
print()
for r in sorted(schema_expected):
    mark = "✅" if r in schema_hits else "❌"
    print(f"  {mark} {r}")

if missing_path or missing_schema:
    print()
    print("FAIL: some expected rules did not fire")
    sys.exit(1)
print()
print("OK: all expected rules fired")
PY
