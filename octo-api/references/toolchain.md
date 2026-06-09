# 工具链命令 / 配置参考

本工具集所有 `make openapi-*` target、可覆盖变量、spec 输出路径、版本约束的速查。日常开发只需要 `make openapi-check`，其它命令是细分场景。

## 命令清单

| 命令 | 用途 | 何时跑 |
|---|---|---|
| `make openapi-check` | 一键 4 道闸（coverage → verify → lint） | 提交代码前 |
| `make openapi-gen` | 重生 `docs/openapi/swagger.{yaml,json,docs.go}` | 改了 API 注释后 |
| `make openapi-lint` | 单独跑 spectral 校验 | debug lint 错误时迭代用 |
| `make openapi-verify` | gen + drift 检测 | 单独验证 spec 跟 git 同步 |
| `make openapi-coverage` | 检查 handler 是否都有 `@Router` | 排查 coverage 失败 |
| `make openapi-diff` | 跟 base ref（默认 origin/main）的 spec diff，识别 breaking | 修改现有 endpoint 后 |
| `make openapi-preview` | gen + 用 Redoc 生成 `docs/openapi/index.html` 静态预览 | 本地想看渲染后的 API 文档 |
| `make openapi-install` | 装 swag v2 CLI（pin v2.0.0-rc5） | 首次接入或 swag 缺失 |

> 工具自身的回归测试（spectral 规则集 / JS function 单测 / coverage 脚本单测）由上游仓库 [octo-openapi-dev-skill](https://github.com/liuooo/octo-openapi-dev-skill) 维护和 CI 跑，**用户项目不需要本地执行**。

## 可覆盖变量

`assets/openapi.mk` 顶部声明，环境变量或 `make VAR=...` 覆盖：

| 变量 | 默认值 | 何时改 |
|---|---|---|
| `OPENAPI_OUT_DIR` | `docs/openapi` | spec 想放别的目录（如 `api/`）|
| `SWAG_VERSION` | `v2.0.0-rc5` | 升级 swag |
| `BASE_REF` | `origin/main` | `make openapi-diff` 对比其它分支 / tag |
| `OCTO_API_DIR` | `tools/octo-api` | skill 包根目录位置（罕见改动）|

用法：

```bash
# 临时
OPENAPI_OUT_DIR=api/ make openapi-gen
BASE_REF=origin/release/v1.0 make openapi-diff

# 永久（主 Makefile include 之前设）
OPENAPI_OUT_DIR := api
include tools/octo-api/assets/openapi.mk
```

## 工具版本

| 工具 | 版本 | 升级方式 |
|---|---|---|
| `swag` | v2.0.0-rc5（pin）| 改 `assets/openapi.mk` 的 `SWAG_VERSION`，跑 `make openapi-gen` 看 schema diff |
| `spectral-cli` | `@latest`（npx）| 不主动 pin，每次 CI 拉最新 |

升级注意：swag 版本变化可能影响生成的 yaml 内容（schema 结构 / 命名）。升级 PR 必须跑 `make openapi-check` 跟 base 对比，确认 spec 兼容。

## Spec 路径

| 项 | 路径 / 说明 |
|---|---|
| 输出目录 | `docs/openapi/`（机器生成产物，跟人工写的 `docs/*.md` 不混）|
| spec 文件 | `swagger.yaml` / `swagger.json` —— swag 工具的硬编码命名，**内容是 OpenAPI 3.1**（非 Swagger 2.0）|
| `docs.go` | swag 生成的 Go 注册器代码 —— 见下节"运行时暴露 /swagger endpoint" |
| `index.html` | `make openapi-preview` 生成的本地预览，不 commit（加到 `.gitignore`）|

## CI 集成

`templates/openapi-workflow.yml` 是 CI 模板，复制到 `.github/workflows/openapi.yml` 后包含 6 道闸：

| Gate | 角色 | 阻塞 PR？ |
|---|---|---|
| Detect changed paths | docs-only PR 跳过整套 | — |
| Swag Annotation Coverage | handler @Router 覆盖 | ✅ |
| Generate & Verify OpenAPI 3.1 | swag 生成 + drift 检测 | ✅ |
| Spectral Lint | 19 条 OCTO 规则 + spectral:oas | ✅ |
| Breaking Change Check | PR diff vs base，写 step summary | ❌ informational |
| Toolchain Self-Test | 工具链自身回归 | ✅ |

repo admin 需把 4 个 ✅ 的 job + Changes 加入 branch ruleset 的 required check（详见 `adoption.md` Step 9）。

## 运行时暴露 /swagger endpoint（可选）

设计意图是让客户端（octo-cli / app / SDK 生成器）**运行时拉 spec**，跟 server 部署版本天然对齐。

**当前默认状态**：未启用。`docs/openapi/docs.go` 由 swag 自动生成但**没人 import**。

**启用步骤**：

1. `main.go` 加 swag 全局注解（详见 `api-spec.md` E 章节末尾 "全局 main.go 必带"）
2. `main.go` 加 import：
   ```go
   import (
       _ "github.com/<org>/<repo>/docs/openapi"  // 触发 swag.Register
       "github.com/swaggo/gin-swagger"
       "github.com/swaggo/files"
   )
   ```
3. router 注册：
   ```go
   r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
   ```
4. 装依赖：`go get github.com/swaggo/gin-swagger github.com/swaggo/files`
5. 起服务，访问 `/swagger/index.html` 看 UI / `/swagger/doc.json` 拉 spec

**触发实施的条件**（满足任一）：
- 客户端方明确要求运行时拉 spec
- 接入 OpenAPI viewer（如 Stoplight Studio）
- 多个客户端 SDK 自动生成需要

在那之前 `docs.go` 留着不动 —— swag 必然产物，不影响其它流程。

## 文件位置约定

skill 包 `tools/octo-api/` 内部结构（按 skill-creator 标准）：

```
tools/octo-api/
├── SKILL.md                   入口（AI 触发 + 工作流）
├── references/                按需加载的详细文档
│   ├── api-spec.md            OpenAPI 规范 A-H 章节
│   ├── adoption.md            接入新仓库的 10 项步骤
│   └── toolchain.md           本文件 — 命令 / 配置参考
├── scripts/                   AI / 开发者可执行脚本
│   ├── check-swag-coverage.sh
│   └── diff-openapi.sh
└── assets/                    配置 / 模板 / fixture
    ├── openapi.mk             Makefile target（被项目 include）
    ├── spectral.yaml          spectral 规则集
    ├── functions/             spectral 自定义 JS function
    ├── templates/             CI workflow + PR template 模板
    └── test-fixtures/         规则集回归测试
```

接入到新仓库时整目录复制（详见 `adoption.md`）。
