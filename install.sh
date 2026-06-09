#!/usr/bin/env bash
#
# install.sh — install octo-openapi-dev-skill into a Go API project.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/liuooo/octo-openapi-dev-skill/main/install.sh | bash
#
# Pin a specific branch / tag / commit:
#   OCTO_SKILL_VERSION=v1.0 curl -fsSL ... | bash       # tag
#   OCTO_SKILL_VERSION=abc1234 curl -fsSL ... | bash    # commit SHA
#
# Install to a custom location (default tools/octo-api):
#   OCTO_SKILL_TARGET=vendor/octo-api curl -fsSL ... | bash
#
# What it does:
#   1. Validates current directory is an API repo (has main.go + modules/)
#   2. Downloads the octo-api/ subtree from a given ref
#   3. Copies it to <target-dir>/ in your project
#   4. Adds `include <target-dir>/assets/openapi.mk` to your Makefile
#   5. Prints next steps for the manual post-install configuration

set -euo pipefail

# --- config ---
SKILL_REPO_URL="${OCTO_SKILL_REPO:-https://github.com/liuooo/octo-openapi-dev-skill}"
SKILL_VERSION="${OCTO_SKILL_VERSION:-main}"
TARGET_DIR="${OCTO_SKILL_TARGET:-tools/octo-api}"

# --- colors ---
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
NC=$'\033[0m'

info()  { echo "${BLUE}ℹ${NC}  $*"; }
ok()    { echo "${GREEN}✓${NC}  $*"; }
warn()  { echo "${YELLOW}⚠${NC}  $*"; }
err()   { echo "${RED}✗${NC}  $*" >&2; }
die()   { err "$*"; exit 1; }

# --- preflight ---
PROJECT_DIR="$(pwd)"
INSTALL_PATH="$PROJECT_DIR/$TARGET_DIR"

echo "═══════════════════════════════════════════════════════"
echo "  octo-openapi-dev-skill installer"
echo "═══════════════════════════════════════════════════════"
echo "  Source:     $SKILL_REPO_URL"
echo "  Ref:        $SKILL_VERSION"
echo "  ${BOLD}Install to: $INSTALL_PATH${NC}"
echo "═══════════════════════════════════════════════════════"
echo

# Must be in a git repo
git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository — run from your project root"

# Must be an API repo (heuristic: main.go + modules/ dir)
[ -f main.go ] || die "no main.go in current directory — this skill is for Go API projects"
[ -d modules ] || warn "no modules/ directory — check-swag-coverage.sh expects gin handlers in modules/<sub>/*.go"

# Must have make + git
command -v make >/dev/null 2>&1 || die "make is required"
command -v git  >/dev/null 2>&1 || die "git is required"

# Optional but recommended
command -v go   >/dev/null 2>&1 || warn "go not found in PATH — required later for 'make openapi-gen'"
command -v npx  >/dev/null 2>&1 || warn "npx not found — required later for 'make openapi-lint' (install Node.js)"

ok "preflight checks passed"
echo

# --- check target directory ---
if [ -d "$TARGET_DIR" ]; then
  warn "$INSTALL_PATH already exists"
  read -p "Overwrite? [y/N] " -n 1 -r REPLY
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    die "aborted by user"
  fi
  rm -rf "$TARGET_DIR"
fi

mkdir -p "$(dirname "$TARGET_DIR")"

# --- download skill ---
info "downloading skill from $SKILL_REPO_URL..."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Build clone URL: append .git only for HTTP(S) / SSH remotes that need it.
# Local filesystem paths and file:// URLs are left as-is.
CLONE_URL="$SKILL_REPO_URL"
if [[ ! "$CLONE_URL" =~ ^(/|\./|\.\./|file://) ]] && [[ ! "$CLONE_URL" =~ \.git$ ]]; then
  CLONE_URL="$CLONE_URL.git"
fi

# Try shallow clone of a named branch/tag (fast path); fall back to full
# clone + checkout for arbitrary refs (commit SHA, etc.).
if git clone --depth=1 --branch="$SKILL_VERSION" "$CLONE_URL" "$TMP/skill-repo" >/dev/null 2>&1; then
  :
elif git clone "$CLONE_URL" "$TMP/skill-repo" >/dev/null 2>&1 \
  && git -C "$TMP/skill-repo" checkout "$SKILL_VERSION" >/dev/null 2>&1; then
  :
else
  die "clone failed — check OCTO_SKILL_VERSION ($SKILL_VERSION) and OCTO_SKILL_REPO ($SKILL_REPO_URL)"
fi

[ -d "$TMP/skill-repo/octo-api" ] || die "downloaded repo missing skill/ subtree — wrong ref?"

# Capture the actual installed commit
RESOLVED_SHA=$(git -C "$TMP/skill-repo" rev-parse --short HEAD)
ok "downloaded ref $SKILL_VERSION (commit $RESOLVED_SHA)"
echo

# --- copy octo-api/ to target ---
info "installing to $INSTALL_PATH/..."
cp -r "$TMP/skill-repo/octo-api" "$TARGET_DIR"
echo "$SKILL_VERSION ($RESOLVED_SHA)" > "$TARGET_DIR/.skill-version"
ok "skill files installed"
echo

# --- patch Makefile ---
MAKEFILE_LINE="include $TARGET_DIR/assets/openapi.mk"
if [ -f Makefile ] && grep -qF "$MAKEFILE_LINE" Makefile; then
  ok "Makefile already includes openapi.mk — skipping"
else
  if [ -f Makefile ]; then
    printf '\n# OpenAPI toolchain (installed by octo-openapi-dev-skill %s)\n%s\n' "$SKILL_VERSION" "$MAKEFILE_LINE" >> Makefile
    ok "appended openapi.mk include to Makefile"
  else
    cat > Makefile <<EOF
# OpenAPI toolchain (installed by octo-openapi-dev-skill $SKILL_VERSION)
$MAKEFILE_LINE
EOF
    ok "created Makefile with openapi.mk include"
  fi
fi
echo

# --- next steps ---
cat <<EOF
═══════════════════════════════════════════════════════
  ${BOLD}Installed${NC} octo-openapi-dev-skill ($SKILL_VERSION @ $RESOLVED_SHA)
  ${BOLD}Location:${NC}  $INSTALL_PATH/
═══════════════════════════════════════════════════════

Next steps (one-time, manual):

  1. Add swag global annotations to main.go
     (template in $TARGET_DIR/references/api-spec.md, "全局 main.go 必带")

  2. Add @Router + swag annotations to at least one handler
     (workflow in $TARGET_DIR/SKILL.md section 1)

  3. Copy CI workflow + PR template:
       mkdir -p .github/workflows
       cp $TARGET_DIR/assets/templates/openapi-workflow.yml  .github/workflows/openapi.yml
       cp $TARGET_DIR/assets/templates/PR_TEMPLATE.md         .github/PULL_REQUEST_TEMPLATE.md

  4. Generate first baseline (auto-installs swag v2 CLI on first run):
       make openapi-gen
       git add docs/openapi/swagger.yaml docs/openapi/swagger.json docs/openapi/docs.go
       git commit -m "chore: add openapi baseline"

  5. (admin) Configure branch protection — see $TARGET_DIR/references/adoption.md

Discover all commands:

  make openapi-help

Verify:

  make openapi-check

AI assistant integration:

  See README of the upstream skill repo for Claude Code / OpenClaw setup.

Full adoption guide:

  $TARGET_DIR/references/adoption.md

Happy shipping. 🚀
EOF
