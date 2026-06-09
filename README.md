# octo-openapi-dev-skill

OpenAPI / swag 接口治理工具链 + AI 助手知识包，供 OCTO 项目 Go API 仓库使用（octo-server / octo-matter / octo-smart-summary / 其它）。

一份代码两种用法：

- **作为工具**：装到 API 仓库后提供 `make openapi-check` 等命令做本地校验、生成 spec、识别 breaking change
- **作为 AI skill**：SKILL.md + references/ 让 Claude Code / OpenClaw 等 AI 助手按规范设计、实现、审查 endpoint

无版本发布概念 —— 各 API 仓库直接拉 main 分支（或某个 commit SHA），用 `install.sh` 安装到本地。

---

## 一键安装

在 API 仓库根目录执行：

```bash
curl -fsSL https://raw.githubusercontent.com/liuooo/octo-openapi-dev-skill/main/install.sh | bash
```

可选环境变量：

| 变量 | 默认值 | 用途 |
|---|---|---|
| `OCTO_SKILL_VERSION` | `main` | 锁定 branch / tag / commit SHA |
| `OCTO_SKILL_TARGET` | `tools/octo-api` | 自定义安装位置 |
| `OCTO_SKILL_REPO` | `https://github.com/liuooo/octo-openapi-dev-skill` | 自定义上游 |

示例：

```bash
# 锁 commit
OCTO_SKILL_VERSION=abc1234 curl -fsSL https://raw.githubusercontent.com/liuooo/octo-openapi-dev-skill/main/install.sh | bash

# 装到 vendor/ 而非 tools/
OCTO_SKILL_TARGET=vendor/octo-api curl -fsSL .../install.sh | bash
```

**install.sh 做什么**：

1. 校验当前目录是 Go API 项目（有 `main.go` + `modules/`）
2. **明显打印安装位置**（如 `/path/to/your/repo/tools/octo-api/`）
3. clone 指定 ref → 复制 `octo-api/` 子树到目标目录
4. 给主 Makefile 追加 `include tools/octo-api/assets/openapi.mk`
5. 打印后续手动配置步骤

---

## 安装后还要做什么（9 项一次性配置）

`install.sh` 只装了文件 + Makefile include。让工具链真正在仓库跑起来，**还要做 9 项手动配置**：

| # | 步骤 | 角色 | 命令 / 说明 |
|---|---|---|---|
| 1 | `main.go` 加 swag 全局注解 | 开发者 | `@title` / `@version` / `@host` / `@BasePath` / `@externalDocs.url` / Bearer 等 —— 模板见 `tools/octo-api/references/api-spec.md` E 章节末尾 |
| 2 | 至少 1 个 handler 加完整 swag 注释 | 开发者 | 按 `tools/octo-api/SKILL.md` 1 章工作流走一遍 |
| 3 | 复制 CI workflow | 开发者 | `cp tools/octo-api/assets/templates/openapi-workflow.yml .github/workflows/openapi.yml` |
| 4 | 复制 PR 模板 | 开发者 | `cp tools/octo-api/assets/templates/PR_TEMPLATE.md .github/PULL_REQUEST_TEMPLATE.md` |
| 5 | 生成首份 baseline | 开发者 | `make openapi-gen`（首次自动装 swag v2 CLI）|
| 6 | 提交 baseline | 开发者 | `git add docs/openapi/ && git commit -m "chore: add openapi baseline"` |
| 7 | 配置 branch protection（4 个 required check）| repo admin | repo Settings → Rules → Rulesets：`Swag Annotation Coverage` / `Generate & Verify OpenAPI 3.1` / `Spectral Lint` / `Toolchain Self-Test` |
| 8 | 验证接入 | 开发者 | `make openapi-check` 全过（**coverage 必须 100%**；存量大仓库见 `tools/octo-api/references/adoption.md` "存量仓库接入" 分阶段路径）|
| 9 | 接入 AI 助手 | 按需 | 见下面 "AI 助手接入" |

跑通 `make openapi-check` 即接入成功。详细每一步见 `tools/octo-api/references/adoption.md`（安装后）。

---

## 安装后能用的命令

```bash
make openapi-help        # 列所有命令
make openapi-check       # 4 道闸：coverage → verify → lint
make openapi-gen         # 重生 docs/openapi/swagger.{yaml,json,docs.go}
make openapi-lint        # spectral 校验
make openapi-verify      # gen + drift 检测
make openapi-coverage    # handler @Router 覆盖
make openapi-diff        # 跟 base ref diff，oasdiff 检测 breaking
make openapi-preview     # 本地生成 HTML 预览（Redoc）
```

> swag v2 CLI 和 oasdiff CLI 在首次 `make openapi-gen` / `make openapi-diff` 时自动 `go install`，不需要单独装。

完整命令清单见 `tools/octo-api/references/toolchain.md`（安装后）。

---

## AI 助手接入

skill 内容（`SKILL.md` + `references/`）对所有 AI 框架是同一份。差异只在"如何让 AI 在合适时机读到它"。当前明确支持两个框架。

### Claude Code

软链 skill 目录到 Claude Code 的 skill 路径：

```bash
# 项目级（推荐：团队成员 clone 后自动可用，跟仓库一起 commit）
mkdir -p .claude/skills
ln -s "../../tools/octo-api" .claude/skills/octo-api

# 个人级（只对当前开发者生效）
ln -s "$(pwd)/tools/octo-api" ~/.claude/skills/octo-api
```

SKILL.md 的 frontmatter 描述了触发场景，Claude Code 接到"加一个 endpoint"等任务时**自动激活**本 skill。

### OpenClaw

OpenClaw 用**同款 [Anthropic Agent Skills 格式](https://docs.openclaw.ai/tools/skills)**（SKILL.md + frontmatter + references/ + scripts/ + assets/），跟 Claude Code 共享同一份内容。

安装路径：

- `<workspace>/skills/<name>/` — workspace 级，优先级最高
- `~/.openclaw/skills/<name>/` — 全局级（加 `--global`）

由于本仓库的 `SKILL.md` 在 `octo-api/` 子目录（不在 root），不能直接 `openclaw skills install git:liuooo/octo-openapi-dev-skill@main`（git 安装期望 root 有 SKILL.md）。改用**本地路径安装**，两种用法：

```bash
# 方式 1（推荐，复用 install.sh 装好的 tools/octo-api/）
curl -fsSL https://raw.githubusercontent.com/liuooo/octo-openapi-dev-skill/main/install.sh | bash
openclaw skills install ./tools/octo-api            # workspace 级
openclaw skills install ./tools/octo-api --global   # 全局级

# 方式 2（仅装 OpenClaw skill，不要工具集成）
git clone https://github.com/liuooo/octo-openapi-dev-skill
openclaw skills install ./octo-openapi-dev-skill/octo-api
```

SKILL.md frontmatter `name: octo-api` 自动识别成 skill slug，无需 `--as`。OpenClaw 接到对应触发场景时自动激活。

---

## 项目结构

```
octo-openapi-dev-skill/                    上游 skill 仓库
├── octo-api/                              ← 被 install.sh 复制到用户项目的 tools/octo-api/
│   ├── SKILL.md                        AI skill 入口（含 frontmatter）
│   ├── references/
│   │   ├── api-spec.md                 OpenAPI 规范 A-H 章节
│   │   ├── adoption.md                 接入流程（跟本 README 上面一致，装后看）
│   │   └── toolchain.md                Make target / 配置参考
│   ├── scripts/
│   │   ├── check-swag-coverage.sh
│   │   ├── diff-openapi.sh
│   │   └── normalize-spec.sh           swag v2 输出后处理（删空 externalDocs）
│   └── assets/
│       ├── openapi.mk                  Makefile target
│       ├── spectral.yaml               spectral 规则集
│       ├── functions/                  spectral 自定义 JS function
│       └── templates/
│           ├── openapi-workflow.yml    → .github/workflows/openapi.yml
│           └── PR_TEMPLATE.md          → .github/PULL_REQUEST_TEMPLATE.md
├── tests/                              ← 工具自身回归测试（不装给用户）
│   ├── run.sh                          一键跑 4 道闸自测
│   ├── functions/octo-list-check.test.mjs
│   ├── fixtures/violations.yaml + valid.yaml + 测试脚本
│   └── sample-api/                     Go fixture（验证 install + check 端到端）
├── install.sh                          ← 用户一键安装
├── Makefile                            ← 维护者用（make test / make lint）
├── README.md                           本文件
├── LICENSE
├── docs/DEVELOPMENT.md                 贡献者文档
└── .github/workflows/self-test.yml     CI 跑 test job + install-smoke job
```

---

## 卸载

如果要从 API 仓库移除：

```bash
rm -rf tools/octo-api/
rm -f .github/workflows/openapi.yml .github/PULL_REQUEST_TEMPLATE.md
# 从主 Makefile 删 "include tools/octo-api/assets/openapi.mk" 那行
# 决定是否删 docs/openapi/ 的 baseline（已被 git 跟踪的 spec 历史）
```

---

## 工具开发（维护者用）

```bash
make test       # 跑所有自测
make lint       # 检查 octo-api/ 结构完整
```

详见 `docs/DEVELOPMENT.md`。

---

## License

Apache-2.0
