#!/usr/bin/env bash
set -euo pipefail

# 通用函数库，尽量保持无副作用，便于各采集脚本复用。

common_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./log.sh
source "${common_lib_dir}/log.sh"

now_compact_ts() {
  date '+%Y%m%dT%H%M%S%z'
}

ensure_dir() {
  mkdir -p "$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

load_optional_env_file() {
  local env_file="$1"
  if [[ -f "${env_file}" ]]; then
    log_info "加载环境文件: ${env_file}"
    # shellcheck disable=SC1090
    set -a && source "${env_file}" && set +a
  fi
}

read_secret_value() {
  local file_path="$1"
  if [[ -n "${file_path}" && -f "${file_path}" ]]; then
    tr -d '\r' < "${file_path}" | sed 's/[[:space:]]*$//'
    return 0
  fi
  return 1
}

cleanup_old_runs() {
  local runs_dir="$1"
  local keep_count="$2"

  if [[ ! -d "${runs_dir}" ]]; then
    return 0
  fi

  mapfile -t stale_runs < <(find "${runs_dir}" -mindepth 1 -maxdepth 1 -type d | sort | head -n -"${keep_count}" 2>/dev/null || true)
  if [[ "${#stale_runs[@]}" -eq 0 ]]; then
    return 0
  fi

  for run_dir in "${stale_runs[@]}"; do
    log_info "清理历史运行目录: ${run_dir}"
    rm -rf "${run_dir}"
  done
}

write_json_file() {
  local target_file="$1"
  shift
  python3 - "$target_file" "$@" <<'PY'
import json
import sys

target = sys.argv[1]
items = sys.argv[2:]
data = {}
for item in items:
    key, value = item.split("=", 1)
    if value in {"true", "false"}:
        data[key] = value == "true"
    else:
        data[key] = value

with open(target, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PY
}
