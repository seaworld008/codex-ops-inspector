[![CI](https://github.com/seaworld008/codex-ops-inspector/actions/workflows/ci.yml/badge.svg)](https://github.com/seaworld008/codex-ops-inspector/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/seaworld008/codex-ops-inspector)](./LICENSE)
[![Codex](https://img.shields.io/badge/Codex-Ready-111111)](https://github.com/seaworld008/codex-ops-inspector)
[![Automation](https://img.shields.io/badge/Automation-CronJob-0F766E)](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Supported-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Bash](https://img.shields.io/badge/Bash-Scripts-121011?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Node](https://img.shields.io/badge/node-24.x-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Last Commit](https://img.shields.io/github/last-commit/seaworld008/codex-ops-inspector)](https://github.com/seaworld008/codex-ops-inspector/commits/main)

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
  README.md
  runtime.env.example
  credentials/
    README.md
    model.env.example
    kubernetes.env.example
    ssh.env.example

k8s/
  README.md
  cronjob-linux-inspection.yaml
  cronjob-composite-inspection.yaml
  configmap-runtime-env.yaml
  configmap-runtime-composite.yaml
  secret-openai-compatible.example.yaml
  secret-kubeconfig.example.yaml

prompts/
  README.md
  linux-inspection.prompt.md
  k8s-inspection.prompt.md
  composite-inspection.prompt.md

skills/
  README.md
  ops-report-standardizer/
    SKILL.md
  ops-skill-bundle.md

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

## 快速开始

如果你第一次使用，建议按下面顺序操作。

### 第一步：克隆仓库

```bash
git clone git@github.com:seaworld008/codex-ops-inspector.git
cd codex-ops-inspector
```

### 第二步：确认本机依赖

至少确认下面几项：

```bash
node -v
npm -v
docker -v
```

推荐版本：

- Node.js `24`
- npm 使用随 Node.js 24 自带版本即可
- Docker 使用当前稳定版

如果你要在宿主机直接调用 Codex，也建议确认：

```bash
codex --version
```

如果你只用 Docker 镜像运行，则宿主机不一定必须安装 `codex`。

### 第三步：安装项目依赖

```bash
npm ci
```

这个步骤主要用于：

- 生成 DOCX 报告
- 做本地语法校验
- 便于你直接在宿主机运行脚本

### 第四步：准备配置文件

推荐从主模板开始：

```bash
cp config/runtime.env.example config/runtime.env
```

然后编辑 `config/runtime.env`。

最小 Linux 本地巡检示例：

```env
AUTH_MODE=auto
INSPECTION_TARGET=linux
INSPECT_MODE=quick
INSPECT_RETENTION_RUNS=20
INSPECT_DOCX=true
CODEX_MODEL=gpt-5.4
CODEX_BASE_URL=https://your-openai-compatible-endpoint.example.com
OPENAI_API_KEY=your-key
INSPECT_OUTPUT_DIR=./output
```

更详细的配置说明见：

- [`config/README.md`](./config/README.md)

### 第五步：根据你的环境准备认证

你可以用三种方式：

#### 方式 A：本机已登录环境

适合：

- 你已经登录了 `kubectl`
- 你已经有 `~/.kube/config`
- 你已经有 `SSH_AUTH_SOCK`
- 你已经导出了 `OPENAI_API_KEY`

推荐设置：

```env
AUTH_MODE=auto
```

#### 方式 B：显式环境变量

适合：

- 本地测试
- CI
- 手工运行容器

例如：

```bash
export OPENAI_API_KEY=your-key
export KUBECONFIG=~/.kube/config
```

#### 方式 C：文件挂载 / Secret 注入

适合：

- Docker
- Kubernetes CronJob
- 有安全边界要求的生产环境

例如：

- `MODEL_OPENAI_API_KEY_FILE=/run/secrets/openai_api_key`
- `K8S_KUBECONFIG_FILE=/run/secrets/kubeconfig`
- `SSH_PRIVATE_KEY_FILE=/run/secrets/ssh_private_key`

### 第六步：选择巡检目标

支持三种：

- `linux`
- `k8s`
- `composite`

含义：

- `linux`：只巡检 Linux
- `k8s`：只巡检 Kubernetes
- `composite`：Linux 和 Kubernetes 一起巡检

### 第七步：选择巡检模式

支持两种：

- `quick`
- `deep`

建议：

- 高频任务用 `quick`
- 低频任务用 `deep`

### 第八步：开始运行

#### 宿主机直接运行

```bash
bash scripts/run-inspection.sh
```

如果你使用自定义运行配置：

```bash
RUNTIME_ENV_FILE=./config/runtime.env bash scripts/run-inspection.sh
```

#### Docker 运行

先构建镜像：

```bash
docker build -t codex-ops-inspector:latest .
```

再运行：

```bash
docker run --rm \
  -e OPENAI_API_KEY=your-key \
  -e AUTH_MODE=auto \
  -e INSPECTION_TARGET=linux \
  -e INSPECT_MODE=quick \
  -e CODEX_MODEL=gpt-5.4 \
  -e CODEX_BASE_URL=https://your-openai-compatible-endpoint.example.com \
  -v "$(pwd)/output:/workspace/output" \
  -v "$(pwd)/config/runtime.env:/workspace/config/runtime.env:ro" \
  codex-ops-inspector:latest
```

#### Kubernetes CronJob 运行

建议先看：

- [`k8s/README.md`](./k8s/README.md)

参考以下文件：

- [`k8s/README.md`](./k8s/README.md)
- [`k8s/cronjob-linux-inspection.yaml`](./k8s/cronjob-linux-inspection.yaml)
- [`k8s/cronjob-composite-inspection.yaml`](./k8s/cronjob-composite-inspection.yaml)
- [`k8s/configmap-runtime-env.yaml`](./k8s/configmap-runtime-env.yaml)
- [`k8s/configmap-runtime-composite.yaml`](./k8s/configmap-runtime-composite.yaml)
- [`k8s/secret-openai-compatible.example.yaml`](./k8s/secret-openai-compatible.example.yaml)
- [`k8s/secret-kubeconfig.example.yaml`](./k8s/secret-kubeconfig.example.yaml)

## 不同环境如何使用

### 场景 1：只巡检本机 Linux

适合：

- 本地开发机
- 运维工作站
- 跳板机

你需要：

1. 配好 `OPENAI_API_KEY`
2. `INSPECTION_TARGET=linux`
3. `INSPECT_MODE=quick` 或 `deep`

启动：

```bash
bash scripts/run-inspection.sh
```

### 场景 2：巡检 Kubernetes 集群

适合：

- 已登录 `kubectl` 的机器
- 有 kubeconfig 的容器
- K8S 内部 CronJob

你需要：

1. 配好 `OPENAI_API_KEY`
2. 保证 `kubectl` 可用
3. 保证 kubeconfig 可用
4. `INSPECTION_TARGET=k8s`

如果本机已经登录：

```bash
kubectl config current-context
AUTH_MODE=auto INSPECTION_TARGET=k8s bash scripts/run-inspection.sh
```

如果使用显式 kubeconfig：

```bash
export KUBECONFIG=/path/to/kubeconfig
AUTH_MODE=config INSPECTION_TARGET=k8s bash scripts/run-inspection.sh
```

### 场景 3：Linux + Kubernetes 组合巡检

适合：

- 需要一份统一的巡检报告
- 宿主机和集群一起巡检

你需要：

1. 配好 `OPENAI_API_KEY`
2. Linux 本机命令可执行
3. kubeconfig 或 `kubectl` 登录环境可用
4. `INSPECTION_TARGET=composite`

启动：

```bash
AUTH_MODE=auto INSPECTION_TARGET=composite bash scripts/run-inspection.sh
```

### 场景 4：Kubernetes CronJob 无人值守运行

适合：

- 生产定时巡检
- 固定频率报告归档

你需要：

1. 构建并推送镜像
2. 创建 ConfigMap
3. 创建 Secret
4. 创建 CronJob

建议顺序：

```bash
kubectl apply -f k8s/secret-openai-compatible.example.yaml
kubectl apply -f k8s/secret-kubeconfig.example.yaml
kubectl apply -f k8s/configmap-runtime-composite.yaml
kubectl apply -f k8s/cronjob-composite-inspection.yaml
```

注意：

- 示例里的 Secret 内容需要替换成你的真实值
- `example.yaml` 只是模板，不能直接用于生产
- 如果你不确定该选哪套，先读 [`k8s/README.md`](./k8s/README.md)

## 输出结果如何查看

每次运行都会创建独立目录：

```text
output/runs/<时间戳>/
```

同时维护：

```text
output/latest/
```

常见产物：

- `context.json`
- `linux-evidence.json`
- `linux-raw.log`
- `k8s-evidence.json`
- `k8s-raw.log`
- `report.md`
- `report.docx`
- `render-report.log`

你通常先看：

1. `output/latest/report.md`
2. 如果报告异常，再看 `output/latest/render-report.log`
3. 如果采集异常，再看 `linux-raw.log` 或 `k8s-raw.log`

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

## 配置说明

完整说明见：

- [`config/README.md`](./config/README.md)
- [`config/runtime.env.example`](./config/runtime.env.example)
- [`config/credentials/README.md`](./config/credentials/README.md)

## 提示词与技能说明

如果你后续要维护提示词或本地 skills，建议先看：

- [`prompts/README.md`](./prompts/README.md)
- [`skills/README.md`](./skills/README.md)

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

## 本地技能

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
