# Development

贡献本 skill 的开发指南。

## 项目布局

| 目录 | 内容 | 谁会用到 |
|---|---|---|
| `octo-api/` | 用户安装时被复制到 `tools/octo-api/` 的内容 | API 仓库（用户）|
| `tests/` | 工具自身回归测试（JS 单测 / fixture / spectral 规则触发回归 / coverage 脚本单测）| 本仓库 CI / 维护者 |
| `docs/` | 本项目的开发 + 发布文档 | 维护者 |
| `install.sh` | 用户一键安装脚本 | 用户 |
| `Makefile` | 维护者用（test / lint / package / publish） | 维护者 |

## 本地开发循环

```bash
make lint        # 检查 octo-api/ 必须的文件都在
make test        # 跑所有自测（4 道闸）
```

```bash
# 改某个文件后跑对应单测
node tests/functions/octo-list-check.test.mjs           # 改 octo-api/assets/functions/octo-list-check.js 后
bash tests/fixtures/test-coverage-script.sh             # 改 octo-api/scripts/check-swag-coverage.sh 后
bash tests/fixtures/verify-rules-fire.sh                # 改 octo-api/assets/spectral.yaml 或 fixture 后
```

## 加新 spectral 规则

完整流程在 `octo-api/references/api-spec.md` 内嵌的「加规则」节里（用户也用得到）。维护者额外注意：

1. **测试 fixture 同步**：`tests/fixtures/violations.yaml` 加触发样本，`tests/fixtures/valid.yaml` 确认不误报，`tests/fixtures/verify-rules-fire.sh` 的 `expected` set 加 `(rule, endpoint)` 项
2. **跑回归**：`make test`
3. **更新 CHANGELOG.md** 描述新规则
4. **bump VERSION** 按 semver（新规则属 minor）

## 加新 reference 文档

`octo-api/references/<topic>.md` 新建后：

1. 在 `octo-api/SKILL.md` 的"何时读什么"表加一行
2. 更新 `Makefile` 的 `lint` target 加 `test -f octo-api/references/<topic>.md` 检查
3. **不需要**改 install.sh（整目录 cp）
4. **不需要**改 CHANGELOG.md 直接体现（属 minor change）

## 加新 script

`octo-api/scripts/<name>.sh` 新建后：

1. 加可执行位：`chmod +x octo-api/scripts/<name>.sh`
2. 在 `octo-api/assets/openapi.mk` 加对应的 `openapi-<verb>` target，引用 `$(OCTO_API_DIR)/scripts/<name>.sh`
3. 在 `octo-api/references/toolchain.md` 命令清单表加一行
4. 在 `Makefile` 的 `lint` target 加 `test -x octo-api/scripts/<name>.sh` 检查
5. 加单测（`tests/fixtures/<name>-test.sh` 或类似），加到 `tests/run.sh`

## 修改 swag 版本

`octo-api/assets/openapi.mk` 顶部 `SWAG_VERSION` 改默认值。注意：

- swag 大版本升级（如 v2 → v3）可能改输出格式，需要全链回归
- 把改动放独立 PR，CHANGELOG 标注
- 用户升级时通过 `make openapi-gen` + spec diff 看影响

## 路径约束

为了 install.sh 能正确把 `octo-api/` 复制到用户的 `tools/octo-api/`，**`octo-api/` 内部路径必须自洽**：

- `octo-api/assets/openapi.mk` 用 `$(OCTO_API_DIR)/...` 变量引用，默认 `tools/octo-api`
- `octo-api/assets/spectral.yaml` 的 `functionsDir: ./functions` 是相对 yaml 自身的（保持不变）
- `octo-api/scripts/*.sh` 内部如果引用其它文件，用相对 `$0` 路径或环境变量

**禁止**：`octo-api/` 内部任何文件硬编码 `tools/octo-api/...`（这是用户侧路径）。

## CI

`.github/workflows/self-test.yml` 跑两个 job：

1. **test**：lint + 自测套件（必过）
2. **install-smoke**：拿当前 commit 当 "已发布版本"，在临时 fake API 目录跑 `install.sh`，验证安装后 layout 正确（必过）

PR 必须两个 job 都过才能合。

## Release

见 [PUBLISHING.md](PUBLISHING.md)。
