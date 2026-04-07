# config 目录说明

这个目录用于管理公开仓库中的配置样例和配置说明。

这里的文件都是“模板”和“示例”，不会包含真实密钥、真实网关地址、真实 kubeconfig 或真实 SSH 私钥。

如果你是第一次使用这个项目，建议先读完本文件，再决定使用哪一种配置方式。

## 配置总原则

本项目支持三类配置来源：

1. 环境变量
2. Secret 文件
3. 已登录环境

脚本会通过 `AUTH_MODE` 决定优先使用哪一类来源：

- `auto`
  优先复用已登录环境，缺失时再回退到显式配置
- `login`
  只使用已登录环境
- `config`
  只使用环境变量或 Secret 文件

统一优先级是：

1. 显式环境变量
2. 显式文件路径
3. 已登录环境探测

## 文件说明

### `runtime.env.example`

这是**主运行配置模板**，也是最推荐你复制和修改的文件。

适合场景：

- 本地开发测试
- Docker 单容器运行
- Kubernetes ConfigMap 挂载
- 统一管理运行模式、目标、输出目录等参数

主要配置项：

- `AUTH_MODE`
- `INSPECTION_TARGET`
- `INSPECT_MODE`
- `INSPECT_OUTPUT_DIR`
- `INSPECT_RETENTION_RUNS`
- `INSPECT_DOCX`
- `CODEX_MODEL`
- `CODEX_BASE_URL`
- `OPENAI_API_KEY` 或 `MODEL_OPENAI_API_KEY_FILE`
- `KUBECONFIG` 或 `K8S_KUBECONFIG_FILE`
- `SSH_AUTH_SOCK` 或 `SSH_PRIVATE_KEY_FILE`

推荐用法：

1. 复制为你自己的运行文件，例如 `config/runtime.env`
2. 按你的环境填写值
3. 运行时通过环境变量 `RUNTIME_ENV_FILE` 指向它，或者直接挂载到 `/workspace/config/runtime.env`

示例：

```bash
cp config/runtime.env.example config/runtime.env
```

### `env.example`

这是**兼容旧方式的简化模板**。

适合场景：

- 只想快速验证项目能跑起来
- 已经熟悉环境变量方式，不想维护完整 runtime 文件

注意：

- 新项目建议优先使用 `runtime.env.example`
- `env.example` 保留主要是为了兼容更简单的调用方式

### `codex.config.toml.example`

这是 Codex CLI 的配置模板。

适合场景：

- 你想手动管理 `~/.codex/config.toml`
- 你想在宿主机直接运行 `codex`
- 你想调试 Codex 兼容 OpenAI 网关时的 provider 配置

主要内容：

- 默认模型 `gpt-5.4`
- 默认 provider `OpenAI`
- `responses` 线路
- 示例 profile

注意：

- 在镜像默认运行路径下，脚本会**自动生成实际的 `config.toml`**
- 所以大多数情况下你不需要手工复制这个文件
- 这个文件更适合调试和理解 Codex provider 配置

## `credentials/` 目录说明

这个目录下放的是按领域拆分的样例，不是运行时必须要逐个加载的目录。

它的主要作用是：

- 帮你理解不同类型的凭据有哪些变量
- 方便你按业务拆分配置来源
- 方便团队内部做文档化和交接

### `credentials/model.env.example`

用于模型网关相关配置。

包含：

- `CODEX_MODEL`
- `CODEX_BASE_URL`
- `OPENAI_API_KEY`
- `MODEL_OPENAI_API_KEY_FILE`

适合场景：

- 你们的模型网关由专门团队维护
- 想把模型配置独立于 Kubernetes/SSH 配置管理

### `credentials/kubernetes.env.example`

用于 Kubernetes 认证相关配置。

包含：

- `KUBECONFIG`
- `K8S_KUBECONFIG_FILE`
- `K8S_CONTEXT`

适合场景：

- 本地 kubeconfig 已登录
- 通过 Secret 文件注入 kubeconfig
- 一个镜像对多个 context 运行巡检

### `credentials/ssh.env.example`

用于 SSH 认证相关配置。

包含：

- `SSH_AUTH_SOCK`
- `SSH_PRIVATE_KEY_FILE`
- `SSH_KNOWN_HOSTS_FILE`

适合场景：

- Linux 巡检需要通过 SSH 跳板机或远程主机采集
- 容器中挂载 SSH 私钥
- 已存在 SSH Agent

## 推荐配置方式

### 方式 1：本地开发推荐

1. 复制 `runtime.env.example` 为 `config/runtime.env`
2. 填写你的 `OPENAI_API_KEY`
3. 如果巡检 K8S，则准备好本机 `kubectl` 已登录环境或 kubeconfig
4. 运行脚本

### 方式 2：Docker 推荐

1. 准备 `runtime.env`
2. 用 `-v` 挂载到容器
3. 用环境变量或 Secret 文件注入真实密钥

### 方式 3：Kubernetes CronJob 推荐

1. 用 ConfigMap 管理 `runtime.env`
2. 用 Secret 管理 `OPENAI_API_KEY`、`kubeconfig`、SSH 密钥
3. 容器启动后由脚本自动解析

## 配置时的常见问题

### 1. 什么时候用环境变量，什么时候用文件？

- 值很短、注入方便：优先环境变量
- 内容很长、结构复杂：优先文件
- Kubernetes Secret：文件和环境变量都可以，但 kubeconfig 更推荐文件挂载

### 2. `AUTH_MODE=auto` 会不会覆盖我的显式配置？

不会。

只要你显式设置了环境变量或文件路径，它们会优先于“已登录环境探测”。

### 3. `codex.config.toml.example` 要不要复制到 `~/.codex/`？

大多数情况下不需要。

项目默认通过 `scripts/run-inspection.sh` 在运行时生成实际配置。

### 4. 公开仓库为什么只保留占位地址？

因为这是公开仓库，不应该暴露真实网关、真实密钥或真实租户信息。

## 最小可用配置

如果你只想先跑通 Linux 本地巡检，最小只需要：

```bash
AUTH_MODE=auto
INSPECTION_TARGET=linux
INSPECT_MODE=quick
CODEX_MODEL=gpt-5.4
CODEX_BASE_URL=https://your-openai-compatible-endpoint.example.com
OPENAI_API_KEY=your-key
```

如果你还要跑 K8S 巡检，再额外保证下面二选一即可：

1. 本机已经 `kubectl` 登录可用
2. 提供 `KUBECONFIG` 或 `K8S_KUBECONFIG_FILE`

