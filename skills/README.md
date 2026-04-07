# skills 目录说明

这个目录存放项目内置的本地 skills 和辅助说明文件。

## 设计定位

本项目里：

- 脚本负责采集
- skills 负责帮助 Codex 稳定输出

也就是说，skills 主要用来统一：

- 报告结构
- 风险分级表达
- 建议动作表达方式

## 文件说明

### `ops-report-standardizer/SKILL.md`

这是当前最核心的本地 skill。

作用：

- 约束巡检报告结构
- 强调证据、风险分级、责任归属和不确定性说明

适用场景：

- Linux 巡检报告
- Kubernetes 巡检报告
- 组合巡检报告

### `ops-skill-bundle.md`

这是一个说明文件。

作用：

- 告诉你当前场景下推荐优先使用哪些 Codex skills

它不是执行型 skill，更像维护参考。

## 本地 skill 怎么生效

默认流程里：

- `scripts/run-inspection.sh`

会把仓库里的 `skills/` 内容同步到：

```text
$CODEX_HOME/skills
```

这样 `render-report.sh` 调用 Codex 时，就能读取本地 skills。

## 修改 skills 时的建议

### 1. 中文说明为主

可以中文化，但建议保留关键术语原文：

- `Critical`
- `Warning`
- `Info`
- `Markdown`
- `Codex`

### 2. 不要让 skill 接管采集

采集职责仍然应该留在：

- `collect-linux.sh`
- `collect-k8s.sh`

skill 更适合做“规范化表达”，不适合做“执行采集”。

### 3. 保持数量克制

项目私有 skill 不要太多。

建议原则：

- 少而稳
- 语义清晰
- 能长期复用

