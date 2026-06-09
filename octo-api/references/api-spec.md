# Octo API 详细规范

OCTO 项目 OpenAPI 接口规范的完整定义。

| 章节 | 主题 |
|---|---|
| [A. URL 设计](#a-url-设计r6--r10) | R6 + R10 |
| [B. Envelope 类型](#b-envelope-类型r1) | R1 |
| [C. 字段与参数命名](#c-字段与参数命名r3--r7--r8) | R3 + R7 + R8 |
| [D. 错误码](#d-错误码r2) | R2 |
| [E. swag 注释](#e-swag-注释r13) | R13 |
| [F. 分页](#f-分页r5) | R5 |
| [G. 批量操作](#g-批量操作r11) | R11 |
| [H. Deprecate 流程](#h-deprecate-流程) | — |

---

## A. URL 设计（R6 + R10）

设计 endpoint 的 URL 路径和 operationId 时按本章。

> **本节是设计建议，不是 lint 规则**。spectral 在 URL 上只 lint 字符级格式（`octo-path-snake-case`：路径段 snake_case），不会检查"该不该复数 / 前缀是否合理 / 该不该走中间件"。这些是 PR review 范畴，本节给判断框架。

### 仓库 = 服务命名空间

OCTO 是多服务架构，**每个模块仓库一个独立服务，各自一套 API 表面**。客户端走统一 `OCTO_API_BASE_URL` 网关，由网关分流到对应 service。

| 服务（仓库）| 主要资源 / 动作（示意，非穷尽）|
|---|---|
| `octo-server` | matters / users / groups / bots / channels / threads / spaces / messages / files / events / sessions / grants / scopes / clients / app_bots / robots / integrations 等 |
| `octo-matter` | matters / `_extract`（LLM 抽取动作）|
| `octo-smart-summary` | summaries / summary/templates / summary/schedules / summary/chat_candidates / summary/member_candidates / summary/`_infer` |
| _未来新模块_ | 自有资源域，仓库自决 |

**URL 一致性约束（不管网关怎么部署）**：

- **`/v1/` 永远是 base URL 之后的第一段** —— 版本号位置不能被服务名挤后。`https://<host>/<service>/v1/<resource>` ❌（version 在第三段）；正确是 `https://<host>/v1/...` ✅
- **服务名要么不进 URL，要么在 `/v1/` 之后**。两种合法形态：
  - Flat（资源名跨服务唯一）：`https://api.octo/v1/matters` —— 网关按资源名路由到对应 service
  - 服务段在 `/v1/` 之后：`https://api.octo/v1/matter/matters` —— 网关按第二段路由
- **服务内部的 spec 永远写 `/v1/<resource>`**（不带服务段）。客户端看到的 `/v1/matter/...` 这种"服务段"是**网关层加的路由前缀**，不属于服务 spec 的范畴。
- **单服务内没有命名空间概念**。前缀段（`/v1/internal/...` `/v1/admin/...`）按下一节"四角色"判断属 audience / domain / 动作，**不是 namespace**。
- 本规范**逐仓库适用**：每个 OCTO API 服务仓库都按此规范设计自家 spec；规则在每仓库 CI 独立跑。

> **历史拓扑警告**：现有 nginx 把 octo-matter 挂在 `/matter/` 下（早于 `/v1/`），加上 octo-matter 内部又用 `/api/v1/matters`，客户端看到 `/matter/api/v1/matters` 这种**三层冗余**，违反"`/v1/` 第一段"约束。属历史遗留拓扑（网关 + 服务双层定义），规范立场是迁移到 `/v1/matter/matters`（service 段在 `/v1/` 后）或 `/v1/matters`（flat 路由），不再保留 `/matter/api/v1/` 嵌套。

### URL 段的四种角色

OCTO URL 一般形态：

```
/v1/[<audience>/][<domain>/]<resource_plural>[/{id}][/<sub_plural>...][/_action]
```

四种段角色（可叠加，每种最多一段）：

| 角色 | 形态 | 作用 | 例 |
|---|---|---|---|
| **资源**（resource） | 复数 snake_case | 核心 entity | `/v1/users` `/v1/matters` |
| **域限定**（domain qualifier） | 单数 / 复数均可 | 紧跟资源时，资源名脱离域就歧义 | `/v1/obo/grants` `/v1/auth/sessions` `/v1/oidc/clients` |
| **受众标记**（audience prefix） | 单数 / 复数均可 | 声明 API 契约的消费方（SLA / 文档可见性 / 网关路由）| `/v1/internal/notifications` `/v1/admin/users` |
| **资源动作**（resource action） | `_` 前缀 | 非 CRUD 动词 | `/v1/users/_search` `/v1/matters/_batch` |

URL 例：
- `/v1/users` —— 纯资源
- `/v1/users/_search` —— 资源 + 动作
- `/v1/obo/grants` —— 域限定 + 资源
- `/v1/internal/notifications` —— 受众 + 资源
- `/v1/internal/auth/sessions/{session_id}` —— 受众 + 域限定 + 资源 + id（罕见但合法）

### URL 段判断 heuristic

**1. 资源**：复数，snake_case，紧跟版本或前缀段。

OCTO 已知资源**建议复数形态**（参考用，**非穷尽，新模块自扩**）：

```
matters / users / groups / bots / threads / spaces / messages / files
channels / events / backups / assignees / members / notifications
sessions / grants / scopes / clients / tokens / app_bots / robots
integrations / reports / reactions / friends / apps / webhooks
```

⚠️ doc 反例：`/v1/user`、`/v1/matter/{id}`、`/v1/app_bot`、`/v1/conversation` —— 已知 OCTO 资源单数化。

**2. 域限定**（domain qualifier）：

> **把前缀拿掉，剩下的资源名在 OCTO 范围内还能唯一定位语义吗？**
> - 能 → 不需要前缀
> - 不能 → 需要 domain qualifier

例：
- `/v1/obo/grants` ✅ —— `grants` 单独看歧义（OAuth / RBAC / 文件权限）
- `/v1/auth/sessions` ✅ —— `sessions` 单独看歧义（用户 / 语音 / 认证）
- `/v1/oidc/clients` ✅ —— `clients` 单独看歧义

**3. 受众标记**（audience prefix）：

> **API 契约对不同消费方是否本质不同？**（SLA / breaking change policy / 文档可见性 / SDK 生成与否）
> - 是 → 用 audience prefix
> - 否 → 走中间件 / header，不进 URL

例：
- `/v1/internal/notifications` ✅ —— internal 与外部 API 是不同契约（不公开 SLA、可破坏性变更）
- `/v1/admin/users` ✅ —— 若 admin view 返回字段集 / 审计 / 文档分类与端用户 API 实际不同
- `/v1/admin/users` ⚠️ —— 若只是 admin 权限多读写几个字段、同一文档同一 SDK，走中间件
- `/v1/manager/backups` ✅ —— `backups` 是后台专属概念，audience 同时具备 domain 含义

**4. 资源动作**：非 CRUD 动词，`_` 前缀紧跟资源段。

例：`/v1/matters/_batch`、`/v1/users/_search`、`/v1/matters/{id}/close`（状态机用 RPC verb 不加 `_`）

### 通用要点（R6）

- 路径段一律 **snake_case**，禁 camelCase / PascalCase —— **规则 lint**
- 资源名**建议复数**（matters / users / groups），单数化是 doc 反例 ⚠️ —— 规则不报
- URL 一律以 `/v1/` 开头（R12 — 当前阶段唯一版本）
- 嵌套层级建议 ≤ 3 级（含 `/v1/` 起算）
- 状态 / 枚举值不进路径 —— 走 body 或 query
- CRUD 用标准 HTTP 动词；**只有状态机**才用 RPC 动词（close / reopen / archive / extract）

> **URL 设计层 vs swag `@Router` 写法**：上面 URL 是**客户端实际请求**的形态（含 `/v1`）。但 Go handler 的 `@Router` 注释里写**相对路径**（不含 `/v1`），由 main.go 的 `@BasePath /v1` 提供前缀。否则 swag v2 会让 servers + path 都含 `/v1` 导致 `/v1/v1/...` 重复。详见 E 章节"`@Router` 写法"。

### 存量改造

仓库历史路径含 `/v1/manager/...`、`/v1/admin/...` 等 audience 前缀但本质只做权限分流的（如 `/v1/manager/spaces` 跟 `/v1/spaces` 实际同契约），按模块逐步迁移到"资源 + 中间件"。详见 `adoption.md` "存量仓库接入"。

### operationId 规则（R10）

| 层数 | 格式 | 例 |
|---|---|---|
| 2 层（标准 CRUD） | `<resource>.<verb>` | `matter.create` / `matter.list` / `matter.delete` |
| 3 层（子资源 / 状态机） | `<resource>.<sub>.<verb>` | `matter.assignee.add` / `matter.transition` / `matter.close` |

要求：
- 一律 lowercase snake_case
- 用点号 `.` 分隔（不是 `_` 也不是 `-`）
- verb 用动词原形（add / remove / create / list / get / update / delete）
- 跟 swag `@ID` 标签的值完全一致

### 反模式

⚠️ doc 反例（设计建议、PR review 拦截）：

| ⚠️ doc 反例 | ✅ 建议 | 备注 |
|---|---|---|
| `/v1/matter/{id}` | `/v1/matters/{matter_id}` | R6 资源单数 + R7 裸 id |
| `/v1/manager/backup/{id}` | `/v1/manager/backups/{backup_id}` | 嵌套资源单数 |
| `/v1/manager/adduser` | `POST /v1/manager/users` | 动词进 URL |
| `/v1/common/appconfig` | `/v1/app_configs` | "common" 不表 audience / domain |
| `/v1/admin/users`（同契约）| `/v1/users` + 鉴权中间件 | audience 仅做权限分流，无契约差 |
| `/v1/manager/login` | `POST /v1/auth/sessions` 或单独 `/v1/auth/login` | 认证流程跑错 audience |
| `/v1/summary/summary_templates` | `/v1/summary/templates` | domain 段已说明域，资源名再带 `summary_` 是冗余 |
| `/v1/summary-templates` | `/v1/summary/templates` 或 `/v1/templates` | kebab-case 违 R6（同时也会触发规则）；compound 命名歧义 |
| `/v1/spaces/{id}/status/{status}` | `PATCH /v1/spaces/{id}` body 带 status | 参数塞路径 |
| `/a/{1}/b/{2}/c/{3}/d/{4}` | 拆独立资源 | 嵌套 > 3 级 |

❌ 规则违例（lint 阻断）：

| ❌ 错 | ✅ 对 | 触发规则 |
|---|---|---|
| `/sendMessage` | `POST /v1/messages` | `octo-path-snake-case` |
| `/Users` | `/users` | `octo-path-snake-case` |
| `/matters/{uid}` | `/matters/{matter_id}` | `octo-path-param-no-uid` + `octo-path-param-id-suffix` |
| `/matters/{matter_no}` | `/matters/{matter_id}` | 同上 |
| `getMatters` (operationId) | `matter.list` | `octo-operation-id-format` |
| `matter_create` | `matter.create` | 同上（`_` 当分隔符）|
| `matter` (1 层) / `a.b.c.d` (4 层) | `matter.<verb>` / 拆 | 同上（层数）|

### 速查例

> "删除一个 matter" → 资源 = matter，动作 = delete，标准 CRUD
> → `DELETE /v1/matters/{matter_id}` + `matter.delete`

> "关闭一个 matter"（状态机）→ 资源 = matter，动作 = close（RPC verb）
> → `POST /v1/matters/{matter_id}/close` + `matter.close`

> "给 matter 添加 assignee"（子资源）
> → `POST /v1/matters/{matter_id}/assignees` + `matter.assignee.add`

---

## B. Envelope 类型（R1）

所有响应必须通过 octo-lib 的 envelope 类型包装 —— 永远不要裸返 `{...}` / `[...]` / 自造 `{msg: ...}` 结构。

### 5 种类型（octo-lib 统一定义）

```go
envelope.Data[T]            // { "data": T }
envelope.CursorList[T]      // { "data": [T], "pagination": {has_more, next_cursor} }
envelope.OffsetList[T]      // { "data": [T], "pagination": {total, page, page_size} }
envelope.Error              // { "error": {code, message, details, hint} }
envelope.EmptyResp          // 空对象，用于 Data[EmptyResp]（delete / 状态机操作的成功响应）
```

### 选型对照

| 响应形态 | 用 | swag `@Success` 写法 |
|---|---|---|
| 单条对象 / 创建后返回新建对象 | `Data[T]` | `{object} envelope.Data[MatterResp]` |
| 列表 + 无限滚动 / cursor 分页 | `CursorList[T]` | `{object} envelope.CursorList[MatterResp]` |
| 列表 + 页码分页 / offset 分页 | `OffsetList[T]` | `{object} envelope.OffsetList[MatterResp]` |
| delete / close / archive / 状态机动作成功 | `Data[EmptyResp]` | `{object} envelope.Data[EmptyResp]` |
| 所有 4xx / 5xx 失败 | `Error` | `{object} envelope.Error` |

### 分页模式选择（R5）

| 用 cursor 当 | 用 offset 当 |
|---|---|
| 数据量大，无限滚动 UI | 数据量小到中，需要跳页 |
| 列表会插入新数据，offset 漂移 | 列表稳定，靠 page 跳 |
| 客户端不需要总数 | 客户端要显示"共 N 条" |
| 例：消息流 / 通知 / event log | 例：matter 列表 / 用户管理表格 |

### handler 用法

octo-lib 提供 envelope helper，所有响应必须通过它（不要直接 `c.JSON`）：

```go
// 成功响应：单条
c.ResponseData(matter)                  // → envelope.Data[MatterResp]

// 成功响应：空（delete / 状态机）
c.ResponseOK()                          // → envelope.Data[EmptyResp]

// 成功响应：cursor 列表
c.ResponseCursor(matters, hasMore, nextCursor)

// 成功响应：offset 列表
c.ResponseOffset(matters, total, page, pageSize)

// 失败响应：永远走 httperr 包（详见 D 章节）
httperr.ResponseErrorL(c, errcode.ErrNotFound,
    map[string]any{"resource": "matter"}, nil)
```

### 反模式

```go
❌ c.JSON(200, gin.H{"matters": matters})           // 裸返
❌ c.JSON(200, matters)                             // 裸返数组
❌ c.AbortWithStatusJSON(400, gin.H{"msg": "..."}) // 不用 envelope.Error
❌ 自造 type Response struct { Code int; Data ...} // 重复造轮子
✅ c.ResponseData(matter)
✅ httperr.ResponseErrorL(c, errcode.ErrValidation, ...)
```

---

## C. 字段与参数命名（R3 + R7 + R8）

所有 schema 字段、path/query 参数都必须遵守命名约定。spectral lint 会强制检查，不合规则 PR 阻断。

### 字段类型 → 命名规则

| 字段类型 | 规则 | 例 |
|---|---|---|
| 路径参数 | `<resource>_id` 必（R7） | `matter_id` / `user_id` / `group_id` |
| 普通字段 | snake_case 必（R8） | `title` / `description` / `page_size` |
| 布尔字段 | `is_` / `has_` / `can_` 前缀必（R8） | `is_active` / `has_more` / `can_edit` |
| 时间字段 | `_at` 后缀（R3）；类型 `string`，format `date-time`，RFC3339 | `created_at` / `closed_at` / `due_at` |
| URL 字段 | `_url` 后缀（R8）；类型 `string`，format `uri` | `avatar_url` / `download_url` |
| ID 字段（响应里） | `<resource>_id` 形式（R7） | `matter_id` / `creator_uid` |
| 数组字段 | 跟元素相关的复数名 | `assignee_uids` / `tag_ids` |

> `creator_uid` 是历史保留 —— 跟 octo-lib 的 user/uid 跨域语义对应；新增字段一律用 `_id`，不要新造 `_uid` 字段。

### Go struct 示例（请求 + 响应）

```go
type CreateMatterReq struct {
    Title        string   `json:"title"          binding:"required,max=200"`
    Description  string   `json:"description,omitempty"`
    AssigneeUIDs []string `json:"assignee_uids,omitempty"`
    DueAt        *string  `json:"due_at,omitempty"   swaggertype:"string,date-time"`
    IsUrgent     bool     `json:"is_urgent,omitempty"`
}

type MatterResp struct {
    MatterID     string   `json:"matter_id"`
    Title        string   `json:"title"`
    Description  string   `json:"description"`
    AssigneeUIDs []string `json:"assignee_uids"`
    DueAt        *string  `json:"due_at,omitempty"`
    AvatarURL    string   `json:"avatar_url,omitempty"   swaggertype:"string,uri"`
    IsUrgent     bool     `json:"is_urgent"`
    CreatedAt    string   `json:"created_at"             swaggertype:"string,date-time"`
    UpdatedAt    string   `json:"updated_at"             swaggertype:"string,date-time"`
}
```

要点：
- Go 标识符按 Go 风格（`AssigneeUIDs` / `AvatarURL`），**json tag 必须 snake_case**（这是 OpenAPI yaml 里的字段名）
- 时间字段：Go 用 `string`（或 `*string` 可空）+ `swaggertype:"string,date-time"` —— 让 swag 生成 RFC3339 + `format: date-time`
- URL 字段：Go 用 `string` + `swaggertype:"string,uri"` —— 让 swag 生成 `format: uri`
- 可选字段：json tag 加 `omitempty`，Go 类型用指针（`*string`）表示语义上的 null
- 入参校验：`binding:"required,max=200"` 等 gin 标签

### 关键 swaggertype 速查

| 字段语义 | Go 类型 | json tag | swaggertype |
|---|---|---|---|
| 时间（RFC3339）| `string` 或 `*string` | `<name>_at` | `"string,date-time"` |
| URL | `string` | `<name>_url` | `"string,uri"` |
| UUID | `string` | `<resource>_id` | `"string,uuid"`（如需要）|
| 枚举 | `string` | snake_case | 通常不需要 swaggertype，用 enum binding |
| 大整数 | `int64` | snake_case | `"integer,int64"` |

### 反模式

| ❌ 错 | ✅ 对 | 违反 |
|---|---|---|
| `pageSize` / `createTime` | `page_size` / `created_at` | R8 camelCase |
| `active` / `more` | `is_active` / `has_more` | R8 无前缀布尔 |
| `avatar` | `avatar_url` | R8 URL 无后缀 |
| `created_time` / `create_at` | `created_at` | R3 时间后缀拼错 |
| `created_ts` / `created` | `created_at` | R3 必须 `_at` 后缀 |
| `id` (path param) | `matter_id` | R7 裸 id |
| `uid` / `short_id` / `*_no` | `<resource>_id` | R7 历史命名全禁 |
| json tag `MatterID` / `matterId` | json tag `matter_id` | R8 — json tag 必须 snake_case（Go 字段名是 PascalCase 没事）|

### 速查例

> 字段类型是布尔 → 必须 `is_` / `has_` / `can_` 前缀

> 字段是时间 → 后缀 `_at` + Go `string`（或 `*string`）+ `swaggertype:"string,date-time"`

> 字段是 URL → 后缀 `_url` + Go `string` + `swaggertype:"string,uri"`

> 路径参数 → 一律 `<resource>_id`，不准 `id` / `uid` / `*_no`

---

## D. 错误码（R2）

12 项固定 enum + `details` 双层结构。**永远** 从这 12 项选，不要新造 code。子分类通过 `details` 字段表达。

### 12 项错误码 enum

| HTTP | code | 何时用 | details 建议字段 |
|---|---|---|---|
| 401 | `AUTH_REQUIRED` | token 缺/过期/无效 | `details.reason: missing\|expired\|invalid` |
| 403 | `FORBIDDEN` | 鉴权过但无权限 | `details.required_role` / `details.resource` |
| 404 | `NOT_FOUND` | 资源不存在 | `details.resource: "matter"` |
| 409 | `CONFLICT` | 状态/版本冲突 | `details.conflict_reason` / `details.current_state` |
| 409 | `DUPLICATE` | 重复创建 | `details.existing_id` |
| 400 | `VALIDATION_ERROR` | 入参校验失败 | `details.field` / `details.reason` |
| 413 | `PAYLOAD_TOO_LARGE` | body / 文件过大 | `details.max_bytes` / `details.actual_bytes` |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Content-Type 不支持 | `details.expected` / `details.actual` |
| 426 | `CLIENT_VERSION_TOO_OLD` | 客户端版本低 | `details.min_version` |
| 429 | `RATE_LIMITED` | 频控 | `details.retry_after_seconds` |
| 500 | `INTERNAL_ERROR` | 兜底 | 不暴露内部细节 |
| 503 | `UPSTREAM_UNAVAILABLE` | 上游故障 | `details.upstream` / `details.upstream_status` |

### 响应结构

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Matter not found",
    "details": { "resource": "matter" },
    "hint": "Verify the matter_id and try again."
  }
}
```

字段语义：
- `code` — 12 项 enum 之一
- `message` — 一句话英文描述（i18n 在客户端做）
- `details` — 结构化子分类信息，机器读
- `hint` — 给用户的修复建议，人读（可选）

### handler 用法

```go
import (
    "github.com/Mininglamp-OSS/octo-server/pkg/errcode"
    "github.com/Mininglamp-OSS/octo-server/pkg/httperr"
)

// 简单错误（无 details）
httperr.ResponseErrorL(c, errcode.ErrAuthRequired, nil, nil)

// 带 details 的错误
httperr.ResponseErrorL(c, errcode.ErrValidation,
    map[string]any{"field": "title", "reason": "exceeds 200 chars"}, nil)

// 带 hint 的错误
httperr.ResponseErrorL(c, errcode.ErrNotFound,
    map[string]any{"resource": "matter"},
    map[string]any{"hint": "Verify matter_id"})
```

参数：`httperr.ResponseErrorL(c, errCode, detailsMap, hintMap)` —— details 跟 hint 都用 `map[string]any{...}`，传 `nil` 跳过。

### 业务情形 → code 映射

| 业务情形 | code |
|---|---|
| 用户没 token / token 失效 | `AUTH_REQUIRED` (401) |
| 用户有 token 但不是 matter 创建者 | `FORBIDDEN` (403) |
| matter_id 在 DB 里查不到 | `NOT_FOUND` (404) |
| matter 已经被删除 / 已关闭 不能再操作 | `CONFLICT` (409) |
| 创建时发现 title 重复 | `DUPLICATE` (409) |
| 入参 title 超过 200 字符 | `VALIDATION_ERROR` (400) |
| 上传文件 > 10MB | `PAYLOAD_TOO_LARGE` (413) |
| POST body 用了 application/xml | `UNSUPPORTED_MEDIA_TYPE` (415) |
| 客户端版本太老不支持新字段 | `CLIENT_VERSION_TOO_OLD` (426) |
| 1 秒内超过 10 次请求 | `RATE_LIMITED` (429) |
| DB / 内部 panic | `INTERNAL_ERROR` (500) |
| WuKongIM / 外部 API 挂了 | `UPSTREAM_UNAVAILABLE` (503) |

### swag @Failure 标签

每个鉴权 endpoint 至少声明这些响应：

```go
// @Failure 400 {object} envelope.Error "VALIDATION_ERROR"
// @Failure 401 {object} envelope.Error "AUTH_REQUIRED"
// @Failure 403 {object} envelope.Error "FORBIDDEN: not owner"
// @Failure 404 {object} envelope.Error "NOT_FOUND"
// @Failure 429 {object} envelope.Error "RATE_LIMITED"
```

根据 endpoint 的实际错误集合补 409 / 413 等。

### 反模式

```
❌ 自造 code: "BAD_REQUEST" / "INVALID_PARAMETER" / "USER_NOT_FOUND"
   → 都属 VALIDATION_ERROR 或 NOT_FOUND；details 字段区分

❌ HTTP code 全用 400 或 500 一把梭
   → 404/403/409 等是协议含义，客户端依赖

❌ details 写成字符串: details: "field title too long"
   → 必须结构化对象，机器要读

❌ message 写中文
   → i18n 在客户端做，server 返英文
```

---

## E. swag 注释（R13）

每个 gin handler 上方必须有完整的 swag godoc 注释。9 个必带标签全部写齐，spectral lint 会强制检查。

### 9 个必带标签

| 标签 | 必带 | 规则 |
|---|---|---|
| `@Summary` | ✅ | ≤80 字符，英文动词大写开头 |
| `@Description` | ✅ | 1-3 句补充，不重复 Summary；含幂等性/副作用提示 |
| `@Tags` | ✅ | 单值，lowercase snake_case，跟 module 名一致 |
| `@ID` | ✅ | operationId，`<resource>.<verb>` 或 `<resource>.<sub>.<verb>` |
| `@Accept` / `@Produce` | ✅ | 一般 `json`（文件上传时 `multipart/form-data`）|
| `@Security` | ✅（鉴权时）| 用 `Bearer` |
| `@Param` | ✅（有参时）| 所有 path/query/body 参数都列 |
| `@Success` | ✅ | 至少 1 个 + envelope 类型 |
| `@Failure` | ✅（鉴权时）| 至少 401/403/404/500 |
| `@Router` | ✅ | **相对路径**（不带 `/v1` 前缀）+ method —— 见下方"⚠️ @Router 写法" |

> ⚠️ **`@Router` 写法**：swag v2 把 main.go 的 `@BasePath /v1` 转成 OpenAPI `servers: [{url: /v1}]`。如果 `@Router` 又写完整 `/v1/matters`，客户端实际请求会变成 `/v1/v1/matters`（重复）。
>
> **正确**：`@Router /matters/{matter_id} [delete]`（不含 `/v1`，由 `@BasePath` 提供）
> **错误**：`@Router /v1/matters/{matter_id} [delete]`

### 完整模板

```go
// MatterDelete godoc
// @Summary       Delete matter
// @Description   Delete a matter the caller owns. Idempotent: returns 200 even if already deleted.
// @Tags          matter
// @ID            matter.delete
// @Accept        json
// @Produce       json
// @Security      Bearer
// @Param         matter_id path string true "Matter ID"
// @Success       200 {object} envelope.Data[EmptyResp] "Matter deleted"
// @Failure       400 {object} envelope.Error            "VALIDATION_ERROR"
// @Failure       401 {object} envelope.Error            "AUTH_REQUIRED"
// @Failure       403 {object} envelope.Error            "FORBIDDEN: not owner"
// @Failure       404 {object} envelope.Error            "NOT_FOUND"
// @Failure       429 {object} envelope.Error            "RATE_LIMITED"
// @Router        /matters/{matter_id} [delete]
func (h *MatterHandler) Delete(c *wkhttp.Context) { ... }
```

> 客户端实际请求是 `DELETE /v1/matters/{matter_id}`（servers `/v1` + path `/matters/{matter_id}` 拼接）。

### @Param 写法

```go
// path 参数
// @Param matter_id path string true "Matter ID"

// query 参数
// @Param page_size query int false "Page size, default 20"
// @Param cursor    query string false "Cursor for next page"

// body 参数
// @Param body body CreateMatterReq true "Request body"

// header
// @Param X-Request-ID header string false "Request trace ID"

// 文件上传
// @Param file formData file true "Upload file"
```

参数格式：`@Param <name> <in> <type> <required> <"description">`

### @Success / @Failure 写法

```go
// 单条
// @Success 200 {object} envelope.Data[MatterResp]

// 列表（cursor）
// @Success 200 {object} envelope.CursorList[MatterResp]

// 列表（offset）
// @Success 200 {object} envelope.OffsetList[MatterResp]

// 空响应（delete / 状态机）
// @Success 200 {object} envelope.Data[EmptyResp] "Matter deleted"

// 失败
// @Failure 404 {object} envelope.Error "NOT_FOUND"
```

格式：`@Success/@Failure <http_code> {object} <envelope_type>[<inner_type>] "<message>"`

### 全局 main.go 必带

每个仓库的 `main.go` 必须有一次性的全局注解：

```go
// @title       Octo Server API
// @version     1.0.0
// @host        api.octo.example
// @BasePath    /v1
// @tag.name        matter
// @tag.description Task and todo management
// @tag.name        message
// @tag.description IM messaging
// @securityDefinitions.apikey Bearer
// @in     header
// @name   Authorization
```

每个 tag 必须在 `@tag.name` 声明 + `@tag.description` 描述，handler 用 `@Tags <name>` 引用。

### 反模式

```
❌ 中文 Summary: @Summary 创建 matter
✅ @Summary Create matter

❌ Summary > 80 字符
✅ ≤ 80，写不下用 Description

❌ Description 跟 Summary 重复
✅ Description 补充关键语义（幂等？副作用？默认值？）

❌ camelCase ID: @ID createMatter
✅ @ID matter.create

❌ 多个 tag: @Tags matter, admin
✅ 单 tag

❌ 漏 @Failure
✅ 401/403/404/500 至少齐

❌ @Success 不用 envelope: @Success 200 {object} MatterResp
✅ @Success 200 {object} envelope.Data[MatterResp]
```

---

## F. 分页（R5）

列表 endpoint 必须选 cursor 或 offset 之一，跟 B 部分的 envelope 选型对应。

### 请求参数

| 模式 | query 参数 | Go struct |
|---|---|---|
| cursor | `cursor` (string, optional) + `page_size` (int, optional, default 20, max 100) | `Cursor string \`form:"cursor"\`` + `PageSize int \`form:"page_size,default=20" binding:"min=1,max=100"\`` |
| offset | `page` (int, optional, default 1) + `page_size` (int, optional, default 20, max 100) | `Page int \`form:"page,default=1" binding:"min=1"\`` + `PageSize int \`form:"page_size,default=20" binding:"min=1,max=100"\`` |

### 响应结构

cursor：
```json
{
  "data": [...],
  "pagination": {
    "has_more": true,
    "next_cursor": "eyJpZCI6MTIzfQ=="
  }
}
```

`next_cursor` 是不透明字符串（base64 编码的服务端状态），客户端原样回传。`has_more: false` 时 `next_cursor` 可省略或 null。

offset：
```json
{
  "data": [...],
  "pagination": {
    "total": 1234,
    "page": 1,
    "page_size": 20
  }
}
```

### swag 注释

```go
// @Param cursor    query string false "Cursor for next page"
// @Param page_size query int    false "Page size, default 20, max 100"
// @Success 200 {object} envelope.CursorList[MatterResp]
```

```go
// @Param page      query int false "Page number, default 1"
// @Param page_size query int false "Page size, default 20, max 100"
// @Success 200 {object} envelope.OffsetList[MatterResp]
```

### 反模式

```
❌ cursor 是 JSON 字符串明文（客户端可破解）
✅ base64 编码 + 服务端签名 / 加密

❌ has_more 不返回，客户端拿空数组判断结束
✅ 永远显式返 has_more 字段

❌ page_size 无上限（DOS 风险）
✅ 设上限（一般 100）+ binding 校验

❌ cursor 模式还返 total（多余且性能开销）
✅ cursor 只返 has_more + next_cursor
```

---

## G. 批量操作（R11）

批量操作走 `_batch` 后缀的独立 endpoint，**全或无**（all-or-nothing）语义。

### URL 模板

```
POST /v1/<resource_plural>/_batch
```

例：
- `POST /v1/matters/_batch` — 批量创建 matter
- `POST /v1/messages/_batch` — 批量发消息

operationId 用 `<resource>.batch_create` / `<resource>.batch_update` 等。

### all-or-nothing 语义

- 入参数组里**任一项**校验失败 → 整批拒绝，返 400 `VALIDATION_ERROR`，`details.failed_index` 指向第一个失败项
- 入参数组里**任一项**业务失败 → 整批回滚，返对应 error code，`details.failed_index` 指向失败项
- 全部成功 → 返 200 + 全部新建对象数组

不允许"部分成功部分失败"的混合结果 —— 简化客户端错误处理。

### 请求/响应结构

```go
type BatchCreateMattersReq struct {
    Items []CreateMatterReq `json:"items" binding:"required,min=1,max=100,dive"`
}

type BatchCreateMattersResp struct {
    Items []MatterResp `json:"items"`
}
```

```go
// @Param body body BatchCreateMattersReq true "Batch request"
// @Success 201 {object} envelope.Data[BatchCreateMattersResp]
// @Failure 400 {object} envelope.Error "VALIDATION_ERROR: details.failed_index"
```

### 错误响应（部分失败时）

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Batch validation failed",
    "details": {
      "failed_index": 3,
      "field": "title",
      "reason": "exceeds 200 chars"
    }
  }
}
```

### 反模式

```
❌ 部分成功部分失败的混合响应（{succeeded: [...], failed: [...]}）
✅ all-or-nothing，要么全成要么全失败

❌ 批量上限不设（一次塞 10000 个）
✅ 设上限（一般 100）+ binding 校验

❌ 用 query 参数传批量数据
✅ 永远走 POST body

❌ 没有 _batch 后缀，跟单条创建用同一个 URL
✅ 独立 endpoint，URL 显式标 _batch
```

---

## H. Deprecate 流程

废弃一个 endpoint 或字段而不直接删除（保留过渡期，让客户端有时间迁移）。

### swag 注释

```go
// MatterCreateLegacy godoc
// @Summary       Create matter (legacy)
// @Description   Deprecated as of 2026-06-01. Removal planned 2026-09-01. Use POST /v1/matters instead.
// @Deprecated    true
// @Tags          matter
// @ID            matter.create_legacy
// @Router        /matter [post]
// ... 其它标签照常
func (h *MatterHandler) CreateLegacy(c *wkhttp.Context) { ... }
```

swag 看到 `@Deprecated true` 会在生成的 OpenAPI 里给该 operation 加 `deprecated: true`，客户端 SDK 生成器看到这个标志会发出 warning。

### HTTP 响应 header

废弃 endpoint 的 handler 实际响应时**必带**两个 header，告诉客户端何时停止用：

```go
c.Header("Deprecation", "true")
c.Header("Sunset", "Wed, 01 Sep 2026 00:00:00 GMT")  // RFC 3339 / IMF-fixdate
c.Header("Link", `</v1/matters>; rel="successor-version"`)  // 替代 endpoint
```

- `Deprecation: true` — 标记已废弃（RFC draft）
- `Sunset: <HTTP-date>` — 计划移除日期（RFC 8594）
- `Link: <url>; rel="successor-version"` — 替代方案

客户端拿到这些 header 应该记录日志 / 提示用户升级。

### 字段级 deprecate

字段单独废弃（保留 endpoint，但某字段要移除），在 Go struct 的 swag 注释 / json tag 描述里标：

```go
type MatterResp struct {
    MatterID  string  `json:"matter_id"`
    Title     string  `json:"title"`
    // Deprecated: use `creator_id` instead. Removal planned 2026-09-01.
    CreatorUID string `json:"creator_uid,omitempty" extensions:"x-deprecated=true"`
    CreatorID  string `json:"creator_id"`
}
```

swag 会把 `extensions` 透传到 spec property 上（如 `x-deprecated: true`）。

### 移除时机

| 类型 | 推荐过渡期 |
|---|---|
| endpoint 整体废弃 | ≥ 90 天 + 客户端确认升级完成 |
| 字段废弃 | ≥ 60 天 |
| 错误码改 | 不允许直接改（属 breaking）；新增 code 不算 |

在 `Sunset` 到期之前不要删 —— 实际删的 PR 是另一次 breaking change。

### 反模式

```
❌ 直接删 endpoint / 字段（没标 deprecate 就移除）
✅ 先 deprecate → 等过渡期 → 再删

❌ swag 标 @Deprecated 但 handler 没加 Deprecation / Sunset header
✅ 标记 + header 一起做，客户端运行时能感知

❌ Description 没说替代方案 / 移除日期
✅ Description 写明：何时废弃 + 何时移除 + 替代是什么
```
