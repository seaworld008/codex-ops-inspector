# 运维技能清单

默认模型：`gpt-5.4`

这个文件用于说明当前镜像和巡检场景下，建议优先使用哪些 Codex skills。

## 推荐技能

- `systematic-debugging`
- `senior-devops`
- `kubernetes-specialist`
- `observability-designer`
- `runbook-generator`
- `security-best-practices`
- `qa-expert`
- `github-ops`
- `sentry`
- `weather`

## 使用建议

1. 如果运行时已经统一管理 `CODEX_HOME/skills`，建议把这些技能随镜像一起带上。
2. 如果你挂载了外部的 `CODEX_HOME`，请确保挂载路径下存在同名技能。
3. 对纯 Linux 巡检，优先使用 `systematic-debugging`、`senior-devops`、`runbook-generator`。
4. 对 Kubernetes 巡检，优先使用 `kubernetes-specialist`、`observability-designer`、`security-best-practices`。
