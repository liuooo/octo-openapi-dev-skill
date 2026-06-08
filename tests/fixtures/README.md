# Spectral Ruleset Regression Fixtures

测试 `tools/octo-api/spectral.yaml` 规则集和支撑脚本的回归 fixture。

## 文件

| 文件 | 用途 | 期望结果 |
|---|---|---|
| `violations.yaml` | 故意违反每条规则（含边界 case） | 每条规则都命中至少 1 处 |
| `valid.yaml` | 完全合规的 OpenAPI 3.1（含边界 pass case）| 0 errors |
| `test-coverage-script.sh` | `check-swag-coverage.sh` 单元测试（5 scenarios）| 全部 pass |
| `verify-rules-fire.sh` | 验证每条 OCTO 规则在 violations.yaml 上的命中点 | 25 个规则命中点 |

## 跑全部回归

```bash
make openapi-toolchain-test
```

跑下面 4 项:

1. `check-swag-coverage.sh` 单元测试(handler 注释扫描的 5 个场景)
2. `octo-list-check.js` 单元测试(5 种 mode + 无效输入 = 36 个 case)
3. spectral rule fire-test(对 violations.yaml 跑 spectral,验证 25 个规则点命中)
4. spectral clean-test(对 valid.yaml 跑 spectral,验证 0 errors)

## OCTO 规则触发表

| 规则 | violations.yaml 触发点(主要 + 边界) |
|---|---|
| `octo-openapi-version` | `openapi: 3.0.0` |
| `octo-summary-required` | `/no_summary`(缺 summary) + `/empty_summary`(空字符串) |
| `octo-summary-length-exceeded` | `/long_summary` + `/summary_81_chars`(边界 81) |
| `octo-summary-english-verb` | `/lowercase_summary` |
| `octo-tags-single` | `/multi_tags`(2 tag) + `/zero_tags`(空数组) + `/three_tags`(3 tag) |
| `octo-tags-lowercase` | `/upper_tag`(`Matter` 大写) |
| `octo-operation-id-format` | `/bad_id`(camelCase) + `/opid_one_part`(1 层) + `/opid_four_parts`(4 层) |
| `octo-path-snake-case` | `/Users`(大写) |
| `octo-path-resource-singular` | `/matter/{...}` + `/groups/{group_id}/user/{user_id}`(嵌套单数) |
| `octo-path-param-id-suffix` | `/matters/{matter_no}` |
| `octo-path-param-no-uid` | `/matters/{uid}` |
| `octo-response-uses-envelope` | `/raw_success`(BadSchema) + `/raw_error`(BadSchema for 4xx) |
| `octo-auth-has-401` | `/auth_no_401` |
| `octo-auth-has-403` | `/auth_no_401` |
| `octo-schema-property-snake-case` | `BadSchema.userId` / `createdTime`(camelCase) |
| `octo-schema-time-at-suffix` | `BadSchema.createdTime`(缺 `_at`) |
| `octo-schema-url-suffix` | `BadSchema.avatar`(缺 `_url`) |
| `octo-schema-boolean-prefix` | `BadSchema.active`(无 `is_/has_/can_`) |

## valid.yaml 边界 pass case

| 场景 | 路径 |
|---|---|
| 正好 80 字符 summary | `/summary_80_chars` |
| 3 段 operationId(`resource.sub.verb`)| `/matters/{matter_id}/assignees` |
| 嵌套复数路径段 | `/matters/{matter_id}/assignees` |

## 维护

修改 `spectral.yaml` / `violations.yaml` / `valid.yaml` 后跑 `make openapi-toolchain-test`:
- 任何规则未命中 → 规则坏了或 fixture 没盖到
- `valid.yaml` 出现 error → 规则误报

## 加新规则时的 fixture 配套

→ 端到端流程参见 `../README.md` 的"加新规则（端到端流程）"小节。本目录在
其中的角色是步骤 4-6：触发样本、合规样本、命中点注册。

- `violations.yaml` — 加一个故意违反新规则的端点 / schema 节点
- `valid.yaml` — 如果是边界 case，加一个 pass 样本
- `verify-rules-fire.sh` — 端点类规则在 `expected` set 加 `(rule_code, endpoint)`；
  schema 类规则在 `schema_expected` set 加规则 ID
