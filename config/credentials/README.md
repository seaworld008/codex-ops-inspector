# 凭据目录约定

这个目录只放样例和说明，不放真实密钥。

## 设计目标

- 优先复用已登录环境
- 缺失时回退到显式配置
- 在同一套脚本里统一解析
- 便于 CronJob、人工运维、跳板机、已登录主机复用

## 推荐注入方式

1. Kubernetes Secret 挂载到 `/run/secrets/*`
2. 宿主机环境变量
3. 已登录环境
   - `kubectl` 当前 context
   - `~/.kube/config`
   - `SSH_AUTH_SOCK`
   - 已导出的 `OPENAI_API_KEY`

## 统一优先级

1. 显式环境变量
2. 显式文件路径
3. 已登录环境自动探测

## 文件样例

- `model.env.example`
- `kubernetes.env.example`
- `ssh.env.example`

