# templates/

接入新仓库时需要复制到目标位置的文件。

| 模板 | 复制到 | 用途 |
|---|---|---|
| `openapi-workflow.yml` | `.github/workflows/openapi.yml` | CI 6 道闸（changes / coverage / generate+verify / lint / breaking-check / toolchain-self-test） |
| `PR_TEMPLATE.md` | `.github/PULL_REQUEST_TEMPLATE.md` | PR 描述模板，含 API Changes checkbox |

详细接入流程见上一级 `ADOPTION.md`。
