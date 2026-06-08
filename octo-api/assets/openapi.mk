# OpenAPI / swag toolchain Make targets.
#
# Included by the project root Makefile via:
#     include tools/octo-api/assets/openapi.mk
#
# All targets are self-contained — they reference scripts, configs, and
# fixtures in the skill package layout (tools/octo-api/{scripts,assets}).
# To consume in a different repo, copy tools/octo-api/ as-is and add the
# include line in the new repo's Makefile.
#
# Override-able variables:
#   SWAG_VERSION       swag CLI version pin (default v2.0.0-rc5)
#   OPENAPI_OUT_DIR    spec output directory (default docs/openapi)
#   BASE_REF           git ref for openapi-diff (default origin/main)
#   OCTO_API_DIR       skill package root (default tools/octo-api)

SWAG_VERSION    ?= v2.0.0-rc5
OPENAPI_OUT_DIR ?= docs/openapi
OCTO_API_DIR    ?= tools/octo-api

# Resolve swag absolute path: prefer PATH (e.g. brew), else $GOPATH/bin
# (where `go install` lands). Makefile can't trust caller's PATH to
# contain $GOPATH/bin, so we fall back explicitly.
SWAG := $(shell command -v swag 2>/dev/null || echo $$(go env GOPATH)/bin/swag)

OPENAPI_SPEC_FILES := \
	$(OPENAPI_OUT_DIR)/swagger.yaml \
	$(OPENAPI_OUT_DIR)/swagger.json \
	$(OPENAPI_OUT_DIR)/docs.go

# ----------------------------------------------------------------------
# Install swag v2 CLI if missing
# ----------------------------------------------------------------------
openapi-install:
	@$(SWAG) --version 2>/dev/null | grep -q "v2\." || { \
	  echo "Installing swag $(SWAG_VERSION) to $$(go env GOPATH)/bin..."; \
	  go install github.com/swaggo/swag/v2/cmd/swag@$(SWAG_VERSION); \
	}
	@$(SWAG) --version

# ----------------------------------------------------------------------
# Coverage: every gin handler has @Router swag annotation
# ----------------------------------------------------------------------
openapi-coverage:
	bash $(OCTO_API_DIR)/scripts/check-swag-coverage.sh modules

# ----------------------------------------------------------------------
# Generate OpenAPI 3.1 spec from Go source + swag annotations
# ----------------------------------------------------------------------
openapi-gen: openapi-install
	$(SWAG) init -g main.go -d ./ -o $(OPENAPI_OUT_DIR) --v3.1
	@bash $(OCTO_API_DIR)/scripts/normalize-spec.sh $(OPENAPI_OUT_DIR)

# ----------------------------------------------------------------------
# Verify: regenerate spec and assert no drift vs committed baseline.
# ----------------------------------------------------------------------
openapi-verify: openapi-gen
	@DRIFT=$$(git status --porcelain -- $(OPENAPI_SPEC_FILES)); \
	if [ -n "$$DRIFT" ]; then \
	  echo "❌ OpenAPI spec drift detected:"; \
	  echo "$$DRIFT"; \
	  echo ""; \
	  echo "Run 'make openapi-gen' and commit $(OPENAPI_OUT_DIR)/swagger.{yaml,json,docs.go}."; \
	  exit 1; \
	fi
	@echo "✅ Generated spec matches committed baseline"

# ----------------------------------------------------------------------
# Lint spec against spectral.yaml
# ----------------------------------------------------------------------
openapi-lint:
	@test -f $(OPENAPI_OUT_DIR)/swagger.yaml || { echo "$(OPENAPI_OUT_DIR)/swagger.yaml missing — run 'make openapi-gen' first"; exit 1; }
	npx -y @stoplight/spectral-cli@latest lint $(OPENAPI_OUT_DIR)/swagger.yaml --ruleset $(OCTO_API_DIR)/assets/spectral.yaml --fail-severity error

# ----------------------------------------------------------------------
# Four-gate check (run before pushing)
# ----------------------------------------------------------------------
openapi-check: openapi-coverage openapi-verify openapi-lint
	@echo "✅ OpenAPI four-gate check passed (coverage → gen → verify → lint)"

# ----------------------------------------------------------------------
# Diff current spec against a base git ref (default origin/main).
# Outputs text diff; AI / reviewer classifies as breaking or non-breaking.
# ----------------------------------------------------------------------
openapi-diff: openapi-gen
	@bash $(OCTO_API_DIR)/scripts/diff-openapi.sh $(BASE_REF)

.PHONY: openapi-install openapi-coverage openapi-gen openapi-verify openapi-lint openapi-check openapi-diff
