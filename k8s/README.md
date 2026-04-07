# k8s 目录使用说明

这个目录用于 Kubernetes 场景下部署 `codex-ops-inspector`。

当前采用的是“克制拆分”的结构，不会拆得很细，也不会把所有资源都塞进一个超长 YAML。

你只需要掌握一件事：

- Linux 巡检用一组文件
- 组合巡检用一组文件

## 文件用途总览

### 通用 Secret

#### `secret-openai-compatible.example.yaml`

作用：

- 存放模型网关 API Key

必须修改：

- `OPENAI_API_KEY`

适用范围：

- 所有模式都需要

#### `secret-kubeconfig.example.yaml`

作用：

- 存放 Kubernetes 的 kubeconfig

必须修改：

- `kubeconfig`

适用范围：

- `k8s`
- `composite`

如果你只是巡检 Linux，这个文件通常不需要。

### Linux 巡检相关

#### `configmap-runtime-env.yaml`

作用：

- 提供 Linux 巡检的运行参数

默认重点：

- `INSPECTION_TARGET=linux`

主要需要确认：

- `CODEX_BASE_URL`
- `INSPECT_MODE`
- `INSPECT_RETENTION_RUNS`

#### `cronjob-linux-inspection.yaml`

作用：

- 创建 Linux 巡检 CronJob

主要需要确认：

- `image`
- `schedule`

### 组合巡检相关

#### `configmap-runtime-composite.yaml`

作用：

- 提供 Linux + Kubernetes 组合巡检参数

默认重点：

- `INSPECTION_TARGET=composite`

主要需要确认：

- `CODEX_BASE_URL`
- `INSPECT_MODE`
- `INSPECT_RETENTION_RUNS`

#### `cronjob-composite-inspection.yaml`

作用：

- 创建 Linux + Kubernetes 组合巡检 CronJob

主要需要确认：

- `image`
- `schedule`

## 我该用哪一套

### 场景 1：只巡检 Linux

使用下面 3 个文件：

1. `secret-openai-compatible.example.yaml`
2. `configmap-runtime-env.yaml`
3. `cronjob-linux-inspection.yaml`

### 场景 2：Linux + Kubernetes 一起巡检

使用下面 4 个文件：

1. `secret-openai-compatible.example.yaml`
2. `secret-kubeconfig.example.yaml`
3. `configmap-runtime-composite.yaml`
4. `cronjob-composite-inspection.yaml`

### 场景 3：只巡检 Kubernetes

当前仓库没有单独拆一个 `k8s-only` CronJob。

建议做法：

- 直接用组合巡检这套
- 把 Linux 部分视为额外上下文

原因是这样更统一，后续维护成本更低。

## 推荐操作步骤

### Linux 巡检

#### 第一步：准备模型网关 Secret

```bash
cp k8s/secret-openai-compatible.example.yaml /tmp/secret-openai-compatible.yaml
vim /tmp/secret-openai-compatible.yaml
```

修改：

```yaml
OPENAI_API_KEY: replace-with-real-key
```

#### 第二步：准备 Linux 运行参数

```bash
cp k8s/configmap-runtime-env.yaml /tmp/configmap-runtime-env.yaml
vim /tmp/configmap-runtime-env.yaml
```

至少确认：

```yaml
CODEX_BASE_URL: "https://your-openai-compatible-endpoint.example.com"
```

如果你想调整模式和保留数量，也在这里改。

#### 第三步：准备 Linux CronJob

```bash
cp k8s/cronjob-linux-inspection.yaml /tmp/cronjob-linux-inspection.yaml
vim /tmp/cronjob-linux-inspection.yaml
```

至少修改：

```yaml
image: your-registry/codex-ops-inspector:latest
schedule: "0 */6 * * *"
```

#### 第四步：应用

```bash
kubectl apply -f /tmp/secret-openai-compatible.yaml
kubectl apply -f /tmp/configmap-runtime-env.yaml
kubectl apply -f /tmp/cronjob-linux-inspection.yaml
```

### 组合巡检

#### 第一步：准备模型网关 Secret

```bash
cp k8s/secret-openai-compatible.example.yaml /tmp/secret-openai-compatible.yaml
vim /tmp/secret-openai-compatible.yaml
```

#### 第二步：准备 kubeconfig Secret

```bash
cp k8s/secret-kubeconfig.example.yaml /tmp/secret-kubeconfig.yaml
vim /tmp/secret-kubeconfig.yaml
```

把 `kubeconfig` 替换成真实内容。

#### 第三步：准备组合巡检运行参数

```bash
cp k8s/configmap-runtime-composite.yaml /tmp/configmap-runtime-composite.yaml
vim /tmp/configmap-runtime-composite.yaml
```

至少确认：

```yaml
INSPECTION_TARGET: "composite"
CODEX_BASE_URL: "https://your-openai-compatible-endpoint.example.com"
```

#### 第四步：准备组合巡检 CronJob

```bash
cp k8s/cronjob-composite-inspection.yaml /tmp/cronjob-composite-inspection.yaml
vim /tmp/cronjob-composite-inspection.yaml
```

至少修改：

```yaml
image: your-registry/codex-ops-inspector:latest
schedule: "0 */6 * * *"
```

#### 第五步：应用

```bash
kubectl apply -f /tmp/secret-openai-compatible.yaml
kubectl apply -f /tmp/secret-kubeconfig.yaml
kubectl apply -f /tmp/configmap-runtime-composite.yaml
kubectl apply -f /tmp/cronjob-composite-inspection.yaml
```

## 应用完成后怎么验证

查看资源：

```bash
kubectl get secret
kubectl get configmap
kubectl get cronjob
```

手动触发一次 Linux 巡检：

```bash
kubectl create job --from=cronjob/codex-linux-inspection codex-linux-inspection-manual-001
kubectl logs -f job/codex-linux-inspection-manual-001
```

手动触发一次组合巡检：

```bash
kubectl create job --from=cronjob/codex-composite-inspection codex-composite-inspection-manual-001
kubectl logs -f job/codex-composite-inspection-manual-001
```

## 你们实际最常改哪些值

通常只会改这几类：

1. `image`
2. `schedule`
3. `OPENAI_API_KEY`
4. `CODEX_BASE_URL`
5. `kubeconfig`

其余大多数默认值都可以先保持不动。

## 注意事项

1. 这些 YAML 是公开模板，不包含真实密钥。
2. 示例里的 `example.yaml` 不能直接用于生产，必须先改成真实值。
3. 如果后面要加 PVC、对象存储、ServiceAccount 或 namespace 限制，建议在现有文件基础上演进，不要再平行复制一套模板。

