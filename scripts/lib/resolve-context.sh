#!/usr/bin/env bash
set -euo pipefail

# 统一运行上下文解析层。
# 负责从环境变量、Secret 文件、已登录环境中解析出标准化上下文，供采集脚本和报告脚本复用。

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${lib_dir}/common.sh"

WORKSPACE_DIR="${WORKSPACE_DIR:-$(cd "${lib_dir}/../.." && pwd)}"
: "${RUNTIME_ENV_FILE:=${WORKSPACE_DIR}/config/runtime.env}"
: "${AUTH_MODE:=auto}"
: "${INSPECTION_TARGET:=linux}"
: "${INSPECT_MODE:=quick}"
: "${INSPECT_OUTPUT_DIR:=${WORKSPACE_DIR}/output}"
: "${INSPECT_RETENTION_RUNS:=20}"
: "${INSPECT_DOCX:=true}"
: "${CODEX_HOME:=/root/.codex}"
: "${CODEX_MODEL:=gpt-5.4}"
: "${CODEX_BASE_URL:=https://your-openai-compatible-endpoint.example.com}"

export WORKSPACE_DIR
export RUNTIME_ENV_FILE
export AUTH_MODE
export INSPECTION_TARGET
export INSPECT_MODE
export INSPECT_OUTPUT_DIR
export INSPECT_RETENTION_RUNS
export INSPECT_DOCX
export CODEX_HOME
export CODEX_MODEL
export CODEX_BASE_URL

load_optional_env_file "${RUNTIME_ENV_FILE}"

resolve_model_auth() {
  local auth_source=""
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    auth_source="env:OPENAI_API_KEY"
  elif [[ -n "${MODEL_OPENAI_API_KEY_FILE:-}" ]] && read_secret_value "${MODEL_OPENAI_API_KEY_FILE}" >/tmp/model_openai_api_key; then
    export OPENAI_API_KEY
    OPENAI_API_KEY="$(cat /tmp/model_openai_api_key)"
    rm -f /tmp/model_openai_api_key
    auth_source="file:${MODEL_OPENAI_API_KEY_FILE}"
  fi

  if [[ -z "${auth_source}" ]]; then
    return 1
  fi

  export MODEL_AUTH_SOURCE="${auth_source}"
  return 0
}

resolve_k8s_auth() {
  export K8S_AUTH_AVAILABLE=false
  export K8S_AUTH_SOURCE=""
  export RESOLVED_KUBECONFIG="${KUBECONFIG:-}"
  export RESOLVED_K8S_CONTEXT="${K8S_CONTEXT:-}"

  if [[ -n "${RESOLVED_KUBECONFIG}" && -f "${RESOLVED_KUBECONFIG}" ]]; then
    K8S_AUTH_AVAILABLE=true
    K8S_AUTH_SOURCE="env:KUBECONFIG"
  elif [[ -n "${K8S_KUBECONFIG_FILE:-}" && -f "${K8S_KUBECONFIG_FILE}" ]]; then
    RESOLVED_KUBECONFIG="${K8S_KUBECONFIG_FILE}"
    K8S_AUTH_AVAILABLE=true
    K8S_AUTH_SOURCE="file:${K8S_KUBECONFIG_FILE}"
  elif [[ "${AUTH_MODE}" != "config" && -f "${HOME}/.kube/config" ]]; then
    RESOLVED_KUBECONFIG="${HOME}/.kube/config"
    K8S_AUTH_AVAILABLE=true
    K8S_AUTH_SOURCE="login:${HOME}/.kube/config"
  fi

  if [[ "${K8S_AUTH_AVAILABLE}" == "true" ]]; then
    export KUBECONFIG="${RESOLVED_KUBECONFIG}"
    if command_exists kubectl; then
      if [[ -z "${RESOLVED_K8S_CONTEXT}" ]]; then
        RESOLVED_K8S_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
      fi
    fi
    export RESOLVED_K8S_CONTEXT
  fi
}

resolve_ssh_auth() {
  export SSH_AUTH_AVAILABLE=false
  export SSH_AUTH_SOURCE=""

  if [[ -n "${SSH_AUTH_SOCK:-}" && -S "${SSH_AUTH_SOCK}" ]]; then
    SSH_AUTH_AVAILABLE=true
    SSH_AUTH_SOURCE="env:SSH_AUTH_SOCK"
  elif [[ -n "${SSH_PRIVATE_KEY_FILE:-}" && -f "${SSH_PRIVATE_KEY_FILE}" ]]; then
    SSH_AUTH_AVAILABLE=true
    SSH_AUTH_SOURCE="file:${SSH_PRIVATE_KEY_FILE}"
  elif [[ "${AUTH_MODE}" != "config" && -d "${HOME}/.ssh" ]]; then
    SSH_AUTH_AVAILABLE=true
    SSH_AUTH_SOURCE="login:${HOME}/.ssh"
  fi
}

validate_auth_mode() {
  case "${AUTH_MODE}" in
    auto|login|config)
      ;;
    *)
      log_error "不支持的 AUTH_MODE: ${AUTH_MODE}"
      exit 2
      ;;
  esac
}

prepare_run_dirs() {
  export RUNS_DIR="${INSPECT_OUTPUT_DIR}/runs"
  export RUN_ID="${RUN_ID:-$(now_compact_ts)}"
  export RUN_DIR="${RUNS_DIR}/${RUN_ID}"
  export LATEST_DIR="${INSPECT_OUTPUT_DIR}/latest"

  ensure_dir "${INSPECT_OUTPUT_DIR}"
  ensure_dir "${RUNS_DIR}"
  ensure_dir "${RUN_DIR}"
  cleanup_old_runs "${RUNS_DIR}" "${INSPECT_RETENTION_RUNS}"
}

write_context_json() {
  local target_file="${RUN_DIR}/context.json"
  python3 - "${target_file}" <<PY
import json
import os
import sys

target_file = sys.argv[1]

data = {
    "auth_mode": os.environ["AUTH_MODE"],
    "inspection_target": os.environ["INSPECTION_TARGET"],
    "inspect_mode": os.environ["INSPECT_MODE"],
    "inspect_docx": os.environ["INSPECT_DOCX"].lower() == "true",
    "codex_model": os.environ["CODEX_MODEL"],
    "codex_base_url": os.environ["CODEX_BASE_URL"],
    "workspace_dir": os.environ["WORKSPACE_DIR"],
    "output_dir": os.environ["INSPECT_OUTPUT_DIR"],
    "run_id": os.environ["RUN_ID"],
    "run_dir": os.environ["RUN_DIR"],
    "latest_dir": os.environ["LATEST_DIR"],
    "model_auth_available": bool(os.environ.get("OPENAI_API_KEY")),
    "model_auth_source": os.environ.get("MODEL_AUTH_SOURCE", ""),
    "k8s_auth_available": os.environ.get("K8S_AUTH_AVAILABLE", "false") == "true",
    "k8s_auth_source": os.environ.get("K8S_AUTH_SOURCE", ""),
    "resolved_kubeconfig": os.environ.get("RESOLVED_KUBECONFIG", ""),
    "resolved_k8s_context": os.environ.get("RESOLVED_K8S_CONTEXT", ""),
    "ssh_auth_available": os.environ.get("SSH_AUTH_AVAILABLE", "false") == "true",
    "ssh_auth_source": os.environ.get("SSH_AUTH_SOURCE", ""),
}

with open(target_file, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PY
}

link_latest_dir() {
  rm -rf "${LATEST_DIR}"
  mkdir -p "${LATEST_DIR}"
  cp "${RUN_DIR}/context.json" "${LATEST_DIR}/context.json"
}

main() {
  validate_auth_mode
  resolve_model_auth || {
    log_error "未解析到模型鉴权，请提供 OPENAI_API_KEY 或 MODEL_OPENAI_API_KEY_FILE"
    exit 3
  }
  resolve_k8s_auth
  resolve_ssh_auth
  prepare_run_dirs
  write_context_json
  link_latest_dir

  log_info "运行上下文已解析"
  log_info "运行目录: ${RUN_DIR}"
}

main "$@"
