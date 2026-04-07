# scripts 目录说明

这个目录是项目的执行核心。

如果说：

- `config/` 负责配置
- `prompts/` 负责报告提示
- `skills/` 负责报告规范

那么 `scripts/` 就负责真正把流程串起来。

## 整体执行链路

默认流程如下：

1. `run-inspection.sh`
2. `lib/resolve-context.sh`
3. `collect-linux.sh` / `collect-k8s.sh` / `collect-composite.sh`
4. `render-report.sh`
5. `generate-docx-report.mjs`（可选）

也就是说：

- `run-inspection.sh` 是总入口
- 其他脚本大多是子步骤

## 文件说明

### `run-inspection.sh`

这是总调度入口。

职责：

1. 解析运行上下文
2. 准备 Codex 配置
3. 同步本地 skills
4. 根据 `INSPECTION_TARGET` 选择采集脚本
5. 调用报告生成脚本

一般情况下，你应该直接运行这个脚本：

```bash
bash scripts/run-inspection.sh
```

### `render-report.sh`

这是报告生成入口。

职责：

1. 读取上下文文件
2. 读取采集证据
3. 组装报告生成提示
4. 调用 Codex
5. 落地 `report.md`
6. 可选生成 `report.docx`

这个脚本通常不建议单独直接运行，除非你已经准备好了：

- `context.json`
- `linux-evidence.json` 或 `k8s-evidence.json`

### `collect-linux.sh`

Linux 采集脚本。

职责：

- 执行 Linux 只读采集命令
- 输出结构化证据
- 输出原始日志

典型产物：

- `linux-evidence.json`
- `linux-raw.log`
- `linux/*.txt`

### `collect-k8s.sh`

Kubernetes 采集脚本。

职责：

- 检查 `kubectl` 和 K8S 凭据是否可用
- 执行 Kubernetes 只读采集命令
- 输出结构化证据
- 如果凭据不可用，输出结构化“不可用说明”

典型产物：

- `k8s-evidence.json`
- `k8s-raw.log`
- `k8s/*.txt`

### `collect-composite.sh`

组合采集脚本。

职责：

- 先采集 Linux
- 再采集 Kubernetes

它本身不做太多逻辑，只是把两边串起来。

### `generate-docx-report.mjs`

Markdown 转 DOCX 工具。

职责：

- 读取报告 Markdown
- 生成 Word 文档

适合场景：

- 需要发送正式报告
- 需要归档 DOCX 文件

### `lib/log.sh`

日志工具库。

职责：

- 统一输出 `[INFO]` / `[WARN]` / `[ERROR]`

### `lib/common.sh`

通用函数库。

职责：

- 目录创建
- 环境文件加载
- Secret 文件读取
- 运行目录清理

### `lib/resolve-context.sh`

上下文解析层。

职责：

- 解析 `AUTH_MODE`
- 解析模型网关凭据
- 解析 K8S 凭据
- 解析 SSH 环境
- 生成 `context.json`
- 创建运行目录和 `latest`

## 哪些脚本建议直接运行

建议直接运行：

- `run-inspection.sh`

按需调试可以运行：

- `collect-linux.sh`
- `collect-k8s.sh`
- `render-report.sh`

不建议直接单独运行，除非你知道自己在做什么：

- `lib/common.sh`
- `lib/log.sh`
- `lib/resolve-context.sh`

## 输入输出关系

### 运行输入

主要输入来自：

- 环境变量
- `config/runtime.env`
- Secret 文件
- 已登录环境

### 运行输出

主要输出到：

```text
output/runs/<时间戳>/
output/latest/
```

常见文件：

- `context.json`
- `linux-evidence.json`
- `linux-raw.log`
- `k8s-evidence.json`
- `k8s-raw.log`
- `report.md`
- `report.docx`
- `render-report.log`

## 排障建议

如果运行失败，建议按这个顺序排查：

### 1. 看总入口输出

直接看终端输出，通常能先判断是：

- 配置问题
- 凭据问题
- 采集问题
- 报告生成问题

### 2. 看 `context.json`

看这里能判断：

- 当前 `AUTH_MODE`
- 当前 `INSPECTION_TARGET`
- 当前 `INSPECT_MODE`
- 模型鉴权是否生效
- K8S 鉴权是否生效
- SSH 环境是否被识别

### 3. 看采集日志

Linux 问题：

- `linux-raw.log`

K8S 问题：

- `k8s-raw.log`

### 4. 看报告生成日志

如果采集正常但报告没出来，优先看：

- `render-report.log`

### 5. 看结构化证据

如果你怀疑报告内容和证据不一致，可以对照：

- `linux-evidence.json`
- `k8s-evidence.json`

## 后续维护建议

建议你们后面维护脚本时遵循：

1. 注释尽量中文
2. 采集逻辑放采集脚本
3. 报告逻辑放提示词和 skill
4. 通用逻辑放 `lib/`
5. 不要把大量业务判断堆到 `run-inspection.sh`

