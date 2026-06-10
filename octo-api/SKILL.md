---
name: octo-api
description: |
  指导 AI 在 OCTO 项目中接入工具链、设计、实现、审查、修改 OpenAPI / swag endpoint。接到任务时先识别场景，再读对应 reference 文档拿详细规则，然后按工作流写代码 + swag 注释，最后跑 `make openapi-check` 校验。

  触发场景（按需读对应 reference）：
  - 实现新 endpoint："加一个 X 接口" / "设计 API" / "新建 endpoint" → 读 references/api-spec.md，按本文工作流走
  - 修改/审查 endpoint："改这个接口" / "审查这个 endpoint" → 读 references/api-spec.md，跑 `make openapi-diff` 识别 breaking
  - 接入新仓库："给 X 仓库加入这套工具链" → 读 references/adoption.md（6 必做 + 可选增强）
  - 工具命令咨询："openapi-check 是什么"、"怎么跑 lint" → 读 references/toolchain.md

  范围：API 设计 + 实现 + 接入 + 本地校验。AI 直接生成 Go 代码 + swag 注释 + spec 修改 + 跑 make 命令。breaking change 由 `make openapi-diff`（oasdiff）自动检测。**不在范围**：部署、contract test。
---

# Octo API skill

设计 endpoint 时按工作流写 Go struct + swag 注释，跑 `make openapi-check` 校验，错误按提示修。详细规则按需读 `references/`。

## 何时读什么

| 场景 | 读 | 然后做 |
|---|---|---|
| 实现新 endpoint | `references/api-spec.md`（A-H 章节按要点用）| 按 1 章 8 步工作流走 |
| 修改 endpoint | `references/api-spec.md` 相关章节 | 跑 `make openapi-diff` 识别 breaking |
| 审查 endpoint | `references/api-spec.md` | 按要点逐项检查 + 跑 `make openapi-check` |
| 接入新仓库到本工具链 | `references/adoption.md` | 10 项一次性配置 |
| 工具命令 / 配置咨询 | `references/toolchain.md` | 按命令清单跑 |

---

## 1. 实现 / 修改 / 审查 endpoint 工作流

接到 "加 / 改 / 审查 X 接口" 都按这套顺序 8 步走。详细规则在 `references/api-spec.md` 各章节，按步骤遇到决策点时读。审查场景 = 逐项对照本工作流 + 引用 R 编号报告通过 / 违规；修改场景 = 同步跑 §2 的 breaking 识别。

| 步骤 | 决策内容 | 详见 |
|---|---|---|
| 1.1 | 解析需求（资源/动作/调用方/鉴权） | 见下 |
| 1.2 | URL & operationId | `references/api-spec.md` A |
| 1.3 | envelope 选型 | `references/api-spec.md` B |
| 1.4 | 字段 / 参数命名 | `references/api-spec.md` C |
| 1.5 | 错误码选择 | `references/api-spec.md` D |
| 1.6 | swag 注释 | `references/api-spec.md` E |
| 1.7 | 列表分页（list 时）| `references/api-spec.md` F |
| 1.7 | 批量操作（_batch 时）| `references/api-spec.md` G |
| 1.8 | 本地校验：`make openapi-check` | — |

### 1.1 解析需求

| 维度 | 取值 |
|---|---|
| **资源** | 见 `references/api-spec.md` A.1 各服务资源表（参考用，非穷尽） |
| **动作** | create / list / get / update / delete / 状态机动词（close / reopen / archive / extract） |
| **调用方** | Bot / User / Admin |
| **鉴权** | Bearer（普通） / Bearer + OBO（代发） |
| **状态机** | 是 → RPC verb；否 → REST 标准 |

> **示例（贯穿 1.2-1.7）**：用户说"删除 matter 接口" → 资源 = matter，动作 = delete，调用方 = Bot/User，鉴权 = Bearer，非状态机 → REST DELETE

### 1.2-1.7 决策示例（接续示例）

| 要点 | 值 |
|---|---|
| 客户端实际 URL | `DELETE /v1/matters/{matter_id}` |
| swag `@Router` 写法 | `/matters/{matter_id} [delete]`（**不含 `/v1`** —— 由 `@BasePath /v1` 提供前缀，否则 servers + path 双 `/v1` 会重复成 `/v1/v1/...`）|
| operationId | `matter.delete` |
| 成功 envelope | `envelope.Data[EmptyResp]` |
| 失败 envelope | `envelope.Error` |
| 字段 | 仅 path 参数 `matter_id`（无 body / 无响应字段）|
| 错误码 | 401 `AUTH_REQUIRED` / 403 `FORBIDDEN` / 404 `NOT_FOUND` / 429 `RATE_LIMITED` / 500 `INTERNAL_ERROR` |
| swag | 9 个必带标签按 E 模板填 |
| 分页 / 批量 | 不涉及 |

### 1.8 本地校验

```bash
make openapi-check
# 4 道闸：coverage → verify (gen + drift) → lint
```

跑通后业务代码跟 swag 自动生成的 spec 文件一起进 git。CI 6 道闸会自动跑全套。

失败处理：
- **coverage 失败**：handler 缺 `@Router` 注释（按 api-spec.md E 章节模板补）
- **verify 失败**：spec 没重生，跑 `make openapi-gen`
- **lint 失败**：spectral 报具体规则 ID + 位置，按错误信息修
- **改了现有 endpoint**：另跑 `make openapi-diff` 看 breaking change（详见下面 2 章）

---

## 2. 修改 endpoint + breaking 识别

根据改动范围对应不同路径：

| 改了什么 | 必走 |
|---|---|
| 字段名 / 类型 | 重读 api-spec.md C → 更新 swag @Param/@Success → `make openapi-check` |
| 错误码 | 重读 api-spec.md D → 更新 swag @Failure → `make openapi-check` |
| 鉴权 | 更新 swag @Security + @Failure 401/403 → `make openapi-check` |
| 请求体 schema | 重读 api-spec.md C → 更新 swag @Param → `make openapi-check` |
| URL 路径 | ⚠️ 必 breaking → 走 deprecate 流程（见 api-spec.md H） |

### 识别 breaking change

修改 endpoint 后**必跑** `make openapi-diff`（默认对比 `origin/main`），oasdiff 按 OpenAPI 语义自动分类每个改动：

- 🔴 `error` 严重度 = breaking → 命令 exit 1，CI 阻断
- 🟡 `warning` / 🟢 `info` = non-breaking → 通过

AI 看到 🔴 输出时**主动提示用户**：

> 本次修改 oasdiff 报告 N 个 breaking change：[转述 oasdiff error 列表]
> 建议：(a) 走 Deprecate 流程（见 api-spec.md H）/ (b) 暴露新版本 endpoint / (c) 跟 octo-cli 等客户端对齐后再合并。

---

## 3. AI 工作元规约

接 endpoint 任务时除工作流外的元行为约束：

- **引用规则编号说明设计依据**（"按 R6 资源段要复数所以用 `/matters`"）—— 让用户能追溯
- **遇决策点先读 `references/api-spec.md` 对应章节再下结论** —— 不要凭印象
- **不发明"规范没说的"** —— 不确定的让 `make openapi-check` 报错指出，而非编规则
- **handler 业务实现不规定** —— 本 skill 只管 API 形态（URL / schema / 错误码 / swag），实现交给开发者
