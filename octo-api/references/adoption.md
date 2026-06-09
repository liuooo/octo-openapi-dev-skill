# 接入新仓库

把 `tools/octo-api/` 工具包落地到一个新 API 提供方仓库（如 `octo-matter` / `octo-smart-summary`）。一次性配置，完成后跑通 `make openapi-check` 即接入成功。

## 一次性配置（9 项）

| # | 步骤 | 角色 | 命令 / 说明 |
|---|---|---|---|
| 1 | 装工具包 | 开发者 | `curl -fsSL https://raw.githubusercontent.com/liuooo/octo-openapi-dev-skill/main/install.sh \| bash`（自动装到 `tools/octo-api/` + Makefile include）|
| 2 | 装 swag 依赖 | 开发者 | `go get github.com/swaggo/swag/v2` |
| 3 | 接入 CI workflow | 开发者 | `cp tools/octo-api/assets/templates/openapi-workflow.yml .github/workflows/openapi.yml` |
| 4 | 接入 PR 模板 | 开发者 | `cp tools/octo-api/assets/templates/PR_TEMPLATE.md .github/PULL_REQUEST_TEMPLATE.md` |
| 5 | `main.go` 加 swag 全局注解 | 开发者 | `@title` / `@version` / `@host` / `@BasePath` / Bearer 等 —— 模板见 `api-spec.md` E 章节末尾 "全局 main.go 必带" |
| 6 | 至少一个 handler 加完整 swag 注释 | 开发者 | 按 `SKILL.md` 1 章工作流走一遍（解析需求 → URL → envelope → struct → 错误码 → swag → check）|
| 7 | 生成 + 提交首份 baseline | 开发者 | `make openapi-gen` → `git add docs/openapi/swagger.{yaml,json,docs.go}` → commit |
| 8 | 配置 branch protection | repo admin | repo Settings → Rules → Rulesets 加 4 个 required check：`Detect changed paths` / `Swag Annotation Coverage` / `Generate & Verify OpenAPI 3.1` / `Spectral Lint` / `Toolchain Self-Test`（**不**包含 `Breaking Change Check` —— informational）|
| 9 | release-drafter path filter | repo admin（可选）| 如果用 release-drafter，配置把 `docs/openapi/swagger.*` 改动标 "API Change" 类别 |

## 验证接入

```bash
make openapi-check
```

期望：

```
✅ coverage 1/N（至少 1 个 handler 有 @Router）
✅ verify 通过（spec 跟 git 同步）
✅ lint 通过（spectral 0 error）
```

→ 接入成功。

## AI 工具部署（让 AI 用上本 skill）

SKILL.md + references/ 是 AI 助手知识包。当前支持两个框架，**共用同一份 SKILL.md 格式**（Anthropic Agent Skills 标准）。

### Claude Code

```bash
# 项目共享（推荐，commit 进仓库团队自动可用）
mkdir -p .claude/skills && ln -s ../../tools/octo-api .claude/skills/octo-api

# 个人级
ln -s $(pwd)/tools/octo-api ~/.claude/skills/octo-api
```

### OpenClaw

```bash
# workspace 级（项目内）
openclaw skills install ./tools/octo-api

# 全局级（所有项目可见）
openclaw skills install ./tools/octo-api --global
```

> OpenClaw 不能直接 `openclaw skills install git:liuooo/octo-openapi-dev-skill@main`，因为本仓库的 SKILL.md 在 `octo-api/` 子目录而不是根目录，OpenClaw git 安装要求 root 有 SKILL.md。所以用本地路径安装（指向 install.sh 装好的 `tools/octo-api/`）。

部署后 AI 接到"加 endpoint"等触发场景时，按 SKILL.md 工作流走，按需读 references/ 详细规则。两个框架可以同时安装，互不影响。

## 持续开发

每加 / 改一个 endpoint，按 `SKILL.md` 的工作流走，详细规则查 `references/api-spec.md`，命令速查 `references/toolchain.md`。

## 不接入的仓库

非 API 提供方（如纯前端 / 文档仓库 / SDK）**不需要**做以上配置。本工具链仅针对：
- 写 Go handler 暴露 HTTP API 的 server
- 用 swag 注释生成 OpenAPI spec

接入判断：仓库内**有 `main.go` + `modules/*` 含 gin handler**。
