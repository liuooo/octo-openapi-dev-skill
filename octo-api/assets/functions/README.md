# Spectral Custom Functions

`tools/octo-api/spectral.yaml` 使用的自定义函数。

## 文件

| 文件 | 用途 |
|---|---|
| `octo-list-check.js` | 通用 list 检查（5 种 mode 覆盖黑名单/白名单/前缀/后缀/子串/路径段）|

## octo-list-check.js

替换原本散落在 5 条规则里的 `pattern` regex，让规则以 list + mode 形式表达意图。

### 5 种 mode

| mode | 行为 | 用例 |
|---|---|---|
| `forbidden` | 值等于列表任一项 → 违规 | 禁用 path 参数命名（uid/short_id/...）|
| `forbidden-segment` | 值按 `/` 拆分后任意 segment 在列表里 → 违规 | 路径单数资源检查（matter/group/...）|
| `required-prefix` | 值必须以列表中某项开头 | 布尔字段前缀（is_/has_/can_）|
| `required-suffix` | 值必须以列表中某项结尾 | 时间字段后缀（_at/_date/...）|
| `required-substring` | 值必须包含列表中某项 | envelope $ref（Envelope/Data/Error）|

### 在 spectral.yaml 里用法

```yaml
octo-some-rule:
  given: "$.path.to.target"
  then:
    field: "<optional field>"
    function: octo-list-check
    functionOptions:
      mode: forbidden        # 选 5 种之一
      list:
        - item1
        - item2
      message: "custom violation message (optional)"
```

## 单元测试

`octo-list-check.test.mjs` 是函数级单元测试，覆盖 5 种 mode × happy/sad 路径
+ 无效输入边界。改 JS 时必跑：

```bash
node tools/octo-api/functions/octo-list-check.test.mjs
# 或纳入工具链总测试：
make openapi-toolchain-test
```

加新 mode 时同步加测试 case；删 mode 时同步删 case。

## 如何加新规则

加规则时**不需要**改 JS 文件 —— `octo-list-check` 的 5 种 mode 已覆盖
list 用法。直接在 `spectral.yaml` 用 `function: octo-list-check` +
`functionOptions.mode` 配置即可。

→ 端到端流程见 `../README.md` 的"加新规则（端到端流程）"小节。

## 如果真要写新 function

只有当新规则用 `octo-list-check` + spectral 内置（pattern / truthy / length）
都表达不了时，才写新 JS 函数。流程（同样参见 `../README.md` 的"写新自定义
function"小节）：

1. 放 `functions/<name>.js`，ES Module 风格 `export default function ...`
2. `spectral.yaml` 顶部 `functions: [...]` 加上文件名
3. 配 `<name>.test.mjs` 单元测试
4. `Makefile` 的 `openapi-toolchain-test` 加一行 node 测试
5. 更新本文件的"文件"表

## 历史决策：为何只有 1 个 function

之前考虑过为每条 list 规则写独立 JS 函数（5 个文件），最终合并成 1 个
`octo-list-check.js` —— list 用法都是同类逻辑（list + mode），分散成 5 个
函数维护成本高。规则间的差异通过 `mode` + `list` 参数表达。
