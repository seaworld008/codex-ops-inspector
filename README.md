[![CI](https://github.com/seaworld008/codex-ops-inspector/actions/workflows/ci.yml/badge.svg)](https://github.com/seaworld008/codex-ops-inspector/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/seaworld008/codex-ops-inspector)](./LICENSE)
[![Node](https://img.shields.io/badge/node-24.x-339933?logo=node.js&logoColor=white)](https://nodejs.org/)

# Codex Ops Inspector

一个面向生产环境的 `Node.js 24 + Codex CLI` 巡检镜像方案，用于通过 `CronJob` 或手工触发的方式，对 Linux 主机和 Kubernetes 集群做标准化巡检，并输出中文报告。

这个仓库的目标不是“让大模型现场自由发挥执行巡检”，而是把方案拆成三层：

- 统一解析层：解析凭据、运行模式、已登录环境
- 快速采集层：脚本只读采集证据，追求快和稳定
- 报告生成层：Codex 基于证据生成标准化中文报告

这样做的好处是：

- 更快：采集主要靠脚本，不靠模型临场探索
- 更稳：同一套输入生成同类输出，行为可预期
- 更安全：凭据统一管理，不把运行时内容直接写死进镜像
- 更好维护：目录结构、配置方式、输出格式都标准化

## 特性

- 基于 `Node.js 24`
- 默认 `Codex CLI 0.118.0`
- 默认模型 `gpt-5.4`
- 支持 OpenAI 兼容网关
- Linux / Kubernetes / 组合巡检
- 全中文 `zh-CN` 报告输出
- 支持 `quick` / `deep` 两种模式
- 支持 `auto` / `login` / `config` 三种认证模式
- 支持时间戳归档和 `latest` 最新结果目录
- 支持 Markdown 和 DOCX 输出

## 架构设计

### 1. 统一解析层

负责解析运行上下文与凭据来源：

- 环境变量
- Secret 文件
- 已登录环境

主要脚本：

- [`scripts/lib/resolve-context.sh`](./scripts/lib/resolve-context.sh)

### 2. 快速采集层

负责只读采集证据，不做系统变更。

主要脚本：

- [`scripts/collect-linux.sh`](./scripts/collect-linux.sh)
- [`scripts/collect-k8s.sh`](./scripts/collect-k8s.sh)
- [`scripts/collect-composite.sh`](./scripts/collect-composite.sh)

输出内容：

- 结构化证据 JSON
- 原始采集日志

### 3. 报告生成层

负责把证据转成标准化中文报告。

主要脚本：

- [`scripts/render-report.sh`](./scripts/render-report.sh)

本地技能：

- [`skills/ops-report-standardizer/SKILL.md`](./skills/ops-report-standardizer/SKILL.md)

## 目录结构

```text
config/
  runtime.env.example
  credentials/
    README.md
    model.env.example
    kubernetes.env.example
    ssh.env.example

k8s/
  cronjob-linux-inspection.yaml
  configmap-runtime-env.yaml
  secret-openai-compatible.example.yaml

prompts/
  linux-inspection.prompt.md
  k8s-inspection.prompt.md
  composite-inspection.prompt.md

scripts/
  lib/
    log.sh
    common.sh
    resolve-context.sh
  collect-linux.sh
  collect-k8s.sh
  collect-composite.sh
  render-report.sh
  run-inspection.sh
  generate-docx-report.mjs

skills/
  ops-report-standardizer/
    SKILL.md
  ops-skill-bundle.md
```

## 认证模式

通过 `AUTH_MODE` 控制：

- `auto`
  先尝试已登录环境，再回退到显式配置
- `login`
  只使用已登录环境
- `config`
  只使用环境变量或 Secret 文件

统一优先级：

1. 环境变量
2. Secret 文件路径
3. 已登录环境探测

## 关键环境变量

- `AUTH_MODE`
- `INSPECTION_TARGET=linux|k8s|composite`
- `INSPECT_MODE=quick|deep`
- `INSPECT_OUTPUT_DIR`
- `INSPECT_RETENTION_RUNS`
- `INSPECT_DOCX=true|false`
- `CODEX_MODEL`
- `CODEX_BASE_URL`
- `OPENAI_API_KEY`
- `MODEL_OPENAI_API_KEY_FILE`
- `KUBECONFIG`
- `K8S_KUBECONFIG_FILE`
- `K8S_CONTEXT`
- `SSH_AUTH_SOCK`
- `SSH_PRIVATE_KEY_FILE`
- `SSH_KNOWN_HOSTS_FILE`

完整说明见：

- [`config/runtime.env.example`](./config/runtime.env.example)
- [`config/credentials/README.md`](./config/credentials/README.md)

## 巡检模式

### quick

适合高频 `CronJob`。

特点：

- 只采集核心指标
- 只取日志尾部
- 速度更快
- 对系统压力更小

### deep

适合低频深度巡检。

特点：

- 采集更长日志
- 上下文更完整
- 报告更细

## 输出结果

每次运行都会创建独立目录：

```text
output/runs/<时间戳>/
```

同时维护：

```text
output/latest/
```

典型产物：

- `context.json`
- `linux-evidence.json`
- `linux-raw.log`
- `k8s-evidence.json`
- `k8s-raw.log`
- `report.md`
- `report.docx`
- `render-report.log`

## 幂等性

这个方案按幂等运行设计。

含义是：

- 默认巡检命令只读
- 不修改 Linux 配置
- 不修改 Kubernetes 资源
- 每次运行都重新采集当前证据
- 最新结果始终写入 `latest`
- 历史结果按时间戳归档

需要区分两件事：

- 执行行为是幂等的
- 输出内容不一定相同，因为系统状态本来就在变化

也就是说，每次运行都会拿到“当下最新”的结果，但脚本本身不会因为重复执行去改变系统状态。

## 长时间运行压力

默认设计已经尽量压低系统压力：

- 只做点时采集，不做常驻轮询
- 不启动后台守护进程
- 只取必要命令和日志尾部
- `quick` 模式更适合高频任务

建议频率：

- `quick`：15 分钟到 1 小时一次
- `deep`：6 小时到 24 小时一次

不建议：

- 每分钟执行一次 `deep`
- 在超大集群无筛选执行全量深度巡检

如果后续集群规模更大，建议继续加：

- namespace 白名单
- 节点白名单
- 事件数量上限
- Pod 数量上限

## 构建镜像

```bash
docker build -t codex-ops-inspector:latest .
```

## 本地运行

```bash
docker run --rm \
  -e OPENAI_API_KEY=your-key \
  -e AUTH_MODE=auto \
  -e INSPECTION_TARGET=linux \
  -e INSPECT_MODE=quick \
  -e CODEX_MODEL=gpt-5.4 \
  -e CODEX_BASE_URL=https://your-openai-compatible-endpoint.example.com \
  -v "$(pwd)/output:/workspace/output" \
  codex-ops-inspector:latest
```

## Kubernetes 示例

参考以下文件：

- [`k8s/cronjob-linux-inspection.yaml`](./k8s/cronjob-linux-inspection.yaml)
- [`k8s/cronjob-composite-inspection.yaml`](./k8s/cronjob-composite-inspection.yaml)
- [`k8s/configmap-runtime-env.yaml`](./k8s/configmap-runtime-env.yaml)
- [`k8s/configmap-runtime-composite.yaml`](./k8s/configmap-runtime-composite.yaml)
- [`k8s/secret-openai-compatible.example.yaml`](./k8s/secret-openai-compatible.example.yaml)
- [`k8s/secret-kubeconfig.example.yaml`](./k8s/secret-kubeconfig.example.yaml)

## 默认技能

镜像启动时会把仓库中的本地技能同步到 `CODEX_HOME/skills`。

当前内置：

- [`skills/ops-report-standardizer/SKILL.md`](./skills/ops-report-standardizer/SKILL.md)

它负责统一巡检报告结构，不负责实际采集。

## 安全说明

这个仓库是公开仓库，默认不包含：

- 实际 API Key
- 实际 kubeconfig
- 实际 SSH 私钥
- 实际运行日志
- 实际巡检报告
- 真实网关域名

请通过环境变量、Secret 或挂载文件注入你自己的配置。

## License

本项目采用 [Apache-2.0](./LICENSE) 许可证。
