# sample-api

最小化的 Go API 项目，用作 octo-openapi-dev-skill 的端到端测试 fixture。

**用途**：

1. CI 的 `install-smoke` job 复制到临时目录，跑 `install.sh` 验证安装链路
2. 维护者本地手动测：`cd /tmp && cp -r .../tests/sample-api . && cd sample-api && bash ../install.sh`
3. 当 spectral 规则改动后，验证规则在真实 Go-生成的 spec 上跑得对（不只是 fixture yaml）

**它不是**真实业务代码，handler 没业务逻辑，只满足以下条件：

- 有 `main.go` + `modules/<module>/*.go` 结构（满足 install.sh preflight）
- 每个 handler 有完整的 9 个 swag 标签（让 swag init 生成非空 spec）
- 字段命名、URL、operationId、错误码全部合规（让 spectral lint 通过）

跑示例：

```bash
cd /tmp
cp -r /path/to/octo-openapi-dev-skill/tests/sample-api .
cd sample-api
git init -q && git add -A && git commit -q -m bootstrap
bash /path/to/octo-openapi-dev-skill/install.sh
# 完成后：
make openapi-check     # 应通过
```
