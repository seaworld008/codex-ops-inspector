#!/usr/bin/env bash
set -euo pipefail

# 组合巡检入口，按统一顺序采集 Linux 与 Kubernetes 证据。

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${script_dir}/collect-linux.sh"
bash "${script_dir}/collect-k8s.sh"

