# octo-openapi-dev-skill — tool development Makefile.
#
# For projects that ran `install.sh`, the installed skill provides its
# own `openapi-*` targets via `tools/octo-api/assets/openapi.mk` — that
# is what users invoke.
#
# This Makefile is for **skill maintainers** — runs self-tests + lints.

.DEFAULT_GOAL := help

help:
	@echo "octo-openapi-dev-skill — maintainer targets"
	@echo ""
	@echo "  test    Run all self-tests (JS unit + spectral fixture regression + coverage script unit + valid clean test)"
	@echo "  lint    Check octo-api/ file integrity (required files present + executable)"

test:
	@bash tests/run.sh

lint:
	@echo "Checking octo-api/ structure..."
	@test -f octo-api/SKILL.md                                || { echo "❌ missing octo-api/SKILL.md"; exit 1; }
	@test -f octo-api/references/api-spec.md                  || { echo "❌ missing references/api-spec.md"; exit 1; }
	@test -f octo-api/references/adoption.md                  || { echo "❌ missing references/adoption.md"; exit 1; }
	@test -f octo-api/references/toolchain.md                 || { echo "❌ missing references/toolchain.md"; exit 1; }
	@test -x octo-api/scripts/check-swag-coverage.sh          || { echo "❌ octo-api/scripts/check-swag-coverage.sh not executable"; exit 1; }
	@test -x octo-api/scripts/check-prereqs.sh                || { echo "❌ octo-api/scripts/check-prereqs.sh not executable"; exit 1; }
	@test -x octo-api/scripts/diff-openapi.sh                 || { echo "❌ octo-api/scripts/diff-openapi.sh not executable"; exit 1; }
	@test -x octo-api/scripts/normalize-spec.sh               || { echo "❌ octo-api/scripts/normalize-spec.sh not executable"; exit 1; }
	@test -f octo-api/assets/openapi.mk                       || { echo "❌ missing assets/openapi.mk"; exit 1; }
	@test -f octo-api/assets/spectral.yaml                    || { echo "❌ missing assets/spectral.yaml"; exit 1; }
	@test -f octo-api/assets/functions/octo-list-check.js     || { echo "❌ missing functions/octo-list-check.js"; exit 1; }
	@test -f octo-api/assets/templates/openapi-workflow.yml   || { echo "❌ missing templates/openapi-workflow.yml"; exit 1; }
	@test -f octo-api/assets/templates/PR_TEMPLATE.md         || { echo "❌ missing templates/PR_TEMPLATE.md"; exit 1; }
	@echo "✅ octo-api/ structure complete"

.PHONY: help test lint
