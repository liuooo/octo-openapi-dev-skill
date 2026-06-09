# 接入新仓库

把 `tools/octo-api/` 工具包落地到一个新 API 提供方仓库（如 `octo-matter` / `octo-smart-summary`）。分两组：**必做** 让本地工具链可用，**可选增强** 按需启用。

## 必做（6 项）

| # | 步骤 | 角色 | 命令 / 说明 |
|---|---|---|---|
| 1 | 装工具包 | 开发者 | `curl -fsSL https://raw.githubusercontent.com/liuooo/octo-openapi-dev-skill/main/install.sh \| bash`（装到 `tools/octo-api/` + Makefile include）|
| 2 | `main.go` 加 swag 全局注解 | 开发者 | `@title` / `@version` / `@host` / `@BasePath` / Bearer 等 —— 模板见 `api-spec.md` E 章节末尾 |
| 3 | 至少一个 handler 加完整 swag 注释 | 开发者 | 按 `SKILL.md` 1 章工作流走一遍 |
| 4 | 生成首份 baseline | 开发者 | `make openapi-gen`（首次自动装 swag v2 CLI）|
| 5 | 提交 baseline | 开发者 | `git add docs/openapi/ && git commit -m "chore: add openapi baseline"` |
| 6 | 验证接入 | 开发者 | `make openapi-check` 全过 |

做完 6 项 = 本地能跑 `make openapi-check` / `diff` / `gen` / `lint` 全套。

## 可选增强（按需启用）

| 项 | 何时启用 | 做法 |
|---|---|---|
| **CI workflow** | 想让 PR 自动跑 4 道闸 + breaking check | `cp tools/octo-api/assets/templates/openapi-workflow.yml .github/workflows/openapi.yml` |
| **PR 模板** | 想让 PR 描述有 API Change 提示 | 把 `tools/octo-api/assets/templates/PR_TEMPLATE.md` 的 "API Changes" 段**合并**到现有 `.github/PULL_REQUEST_TEMPLATE.md`（**不要**直接覆盖；仓库通常已有 PR template）|
| **branch protection** | 想让 CI 失败时阻断 PR 合并 | repo Settings → Rules → Rulesets 加 required check：`Detect changed paths` / `Swag Annotation Coverage` / `Generate & Verify OpenAPI 3.1` / `Spectral Lint` / `Toolchain Self-Test`（**不**含 `Breaking Change Check` — 它是 informational）|
| **release-drafter** path filter | 用 release-drafter 想让 spec 改动单独分类 | 配置把 `docs/openapi/swagger.*` 改动标 "API Change" |
| **AI 助手接入** | 想让 Claude Code / OpenClaw 自动按 SKILL 工作流写 endpoint | 见下面 "AI 工具部署" |

## 验证接入

```bash
make openapi-check
```

期望：

```
✅ coverage N/N（100%，每个 gin handler 都有 @Router 注释）
✅ verify 通过（spec 跟 git 同步）
✅ lint 通过（spectral 0 error）
```

→ 接入成功。

> ⚠️ **coverage 必须 100%**。`check-swag-coverage.sh` 任一 handler 缺 `@Router` 就 fail，没有部分覆盖 / 阈值机制。空仓库（0 handler）天然过；存量大仓库需要先把全部 handler 注释完，见下面"存量仓库接入"。

## 存量仓库接入（已有大量 handler 缺 @Router）

新仓库装上就能 100% 覆盖（0/0 或 1/1）。存量大仓库（如 octo-server 444 handler）一次性注释完不现实，分阶段走：

| 阶段 | 动作 |
|---|---|
| **1. 装工具但不进 required check** | 跑 install.sh 装 `tools/octo-api/`，但**不要**配置 branch protection 的 `Swag Annotation Coverage` required check |
| **2. 看缺什么** | `make openapi-coverage` 输出所有缺 `@Router` 的 handler 清单 |
| **3. 批量补注释** | 按 module 拆 PR，每个 PR 把一组 handler 都补完 swag 注释（参考 `SKILL.md` 1 章工作流，用 AI 助手批量做更快）|
| **4. 持续跑** | 每个 PR 后 `make openapi-coverage` 看进度，逐步从 N/M 爬到 N/N |
| **5. 100% 后启用 required check** | coverage 跑出 100%，repo admin 配 branch protection 加上 `Swag Annotation Coverage` |
| **6. 同步装 baseline + 其它闸** | `make openapi-gen` 生成 baseline，commit；启用 lint / verify required check |

期间 PR 仍能合（因为 coverage 没进 required check），不会卡所有人。等 100% 达成再启用，保证未来 PR 不退化。

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
