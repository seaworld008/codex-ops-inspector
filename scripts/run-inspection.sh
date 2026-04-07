#!/usr/bin/env bash
set -euo pipefail

# 总调度脚本。
# 标准流程：
# 1. 解析运行上下文
# 2. 写入 Codex 配置
# 3. 采集证据
# 4. 生成中文报告

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "${script_dir}/lib/common.sh"

export WORKSPACE_DIR="${WORKSPACE_DIR:-$(cd "${script_dir}/.." && pwd)}"

log_info "开始执行标准化巡检流程"

# shellcheck source=./lib/resolve-context.sh
source "${script_dir}/lib/resolve-context.sh"

context_file="${INSPECT_OUTPUT_DIR}/latest/context.json"
if [[ ! -f "${context_file}" ]]; then
  log_error "上下文文件不存在: ${context_file}"
  exit 4
fi

export RUN_ID
RUN_ID="$(python3 - <<PY
import json
with open("${context_file}", "r", encoding="utf-8") as f:
    data = json.load(f)
print(data["run_id"])
PY
)"
export RUN_DIR="${INSPECT_OUTPUT_DIR}/runs/${RUN_ID}"
export LATEST_DIR="${INSPECT_OUTPUT_DIR}/latest"

ensure_dir "${CODEX_HOME}"
ensure_dir "${CODEX_HOME}/skills"
if [[ -d "${WORKSPACE_DIR}/skills" ]]; then
  cp -R "${WORKSPACE_DIR}/skills/." "${CODEX_HOME}/skills/"
fi
cat > "${CODEX_HOME}/config.toml" <<EOF
model_provider = "OpenAI"
model = "${CODEX_MODEL}"
review_model = "${CODEX_MODEL}"
model_reasoning_effort = "high"
disable_response_storage = true
network_access = "enabled"
model_context_window = 1000000
model_auto_compact_token_limit = 900000

[model_providers.OpenAI]
name = "OpenAI"
base_url = "${CODEX_BASE_URL}"
wire_api = "responses"
requires_openai_auth = true
EOF

case "${INSPECTION_TARGET}" in
  linux)
    bash "${script_dir}/collect-linux.sh"
    ;;
  k8s)
    bash "${script_dir}/collect-k8s.sh"
    ;;
  composite)
    bash "${script_dir}/collect-composite.sh"
    ;;
  *)
    log_error "不支持的 INSPECTION_TARGET: ${INSPECTION_TARGET}"
    exit 2
    ;;
esac

bash "${script_dir}/render-report.sh"

log_info "巡检完成，结果目录: ${RUN_DIR}"
