# prompts 目录说明

这个目录存放的是**报告生成提示词**。

它们不负责采集证据，主要负责约束 Codex 最终报告的结构、表达方式和输出边界。

## 设计定位

在这个项目里：

- 采集由脚本负责
- 报告由提示词约束

所以提示词的职责主要是：

- 明确报告语言
- 明确必须包含哪些章节
- 明确风险分组方式
- 明确不能越权做什么

## 文件说明

### `linux-inspection.prompt.md`

用于 Linux 主机巡检报告。

适合：

- 本机巡检
- 跳板机巡检
- 只看 Linux 的场景

重点约束：

- 聚焦 CPU、内存、磁盘、inode、load、kernel、监听端口、失败服务、日志错误
- 报告必须包含 `Critical` / `Warning` / `Info`

### `k8s-inspection.prompt.md`

用于 Kubernetes 集群巡检报告。

适合：

- 已有有效 `kubectl` 访问能力
- 只看集群健康的场景

重点约束：

- 聚焦 nodes、pods、events、metrics、API 可用性
- 如果凭据不可用，必须明确写访问限制

### `composite-inspection.prompt.md`

用于 Linux + Kubernetes 组合巡检报告。

适合：

- 主机和集群一起巡检
- 需要统一报告的场景

重点约束：

- Linux 与 Kubernetes Findings 分开整理
- 最后补充跨层风险分析

## 什么时候会用到这些提示词

默认由下面脚本自动选择：

- `scripts/render-report.sh`

选择规则：

- `INSPECTION_TARGET=linux` -> `linux-inspection.prompt.md`
- `INSPECTION_TARGET=k8s` -> `k8s-inspection.prompt.md`
- `INSPECTION_TARGET=composite` -> `composite-inspection.prompt.md`

## 修改提示词时的建议

### 1. 可以中文化，但不要硬翻关键术语

建议保留原文：

- `Critical`
- `Warning`
- `Info`
- `Markdown`
- `kubectl`
- `metrics-server`
- `kubeconfig`
- `CronJob`

### 2. 不要把采集逻辑写进提示词

采集逻辑应该留给脚本：

- `collect-linux.sh`
- `collect-k8s.sh`

提示词只负责报告约束。

### 3. 不要让提示词要求修改系统

这个项目的原则是：

- 采集层只读
- 报告层只总结

所以提示词里不要写“自动修复”“自动重启”“自动变更配置”。

