#!/usr/bin/env bash
set -euo pipefail

# Linux 快速采集脚本。
# 只读执行，输出结构化证据和原始日志，尽量减少对系统的额外压力。

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "${script_dir}/lib/common.sh"

: "${RUN_DIR:?RUN_DIR 未设置}"
: "${INSPECT_MODE:=quick}"

linux_dir="${RUN_DIR}/linux"
raw_log="${RUN_DIR}/linux-raw.log"
evidence_json="${RUN_DIR}/linux-evidence.json"

ensure_dir "${linux_dir}"
: > "${raw_log}"

run_capture() {
  local key="$1"
  shift
  local output_file="${linux_dir}/${key}.txt"
  local cmd="$*"

  {
    printf -- '===== %s =====\n' "${key}"
    printf -- 'COMMAND: %s\n' "${cmd}"
  } >> "${raw_log}"

  if bash -lc "${cmd}" > "${output_file}" 2>&1; then
    printf -- 'STATUS: ok\n\n' >> "${raw_log}"
  else
    printf -- 'STATUS: failed\n\n' >> "${raw_log}"
  fi

  {
    printf -- '----- OUTPUT (%s) -----\n' "${key}"
    cat "${output_file}"
    printf -- '\n\n'
  } >> "${raw_log}"
}

collect_quick() {
  run_capture date "date"
  run_capture hostname "hostnamectl || hostname"
  run_capture uname "uname -a"
  run_capture os_release "cat /etc/os-release"
  run_capture uptime "uptime"
  run_capture free "free -h"
  run_capture df_h "df -h"
  run_capture df_ih "df -ih"
  run_capture ps_cpu "ps aux --sort=-%cpu | head -n 12"
  run_capture ps_mem "ps aux --sort=-%mem | head -n 12"
  run_capture ss "ss -tulpn || netstat -tulpn"
  run_capture systemctl_failed "systemctl --failed --no-pager"
  run_capture journal_errors "journalctl -p 3 -xb --no-pager | tail -n 40"
  run_capture dmesg_tail "dmesg -T | tail -n 40"
}

collect_deep() {
  collect_quick
  run_capture system_state "systemctl is-system-running"
  run_capture virt_detect "systemd-detect-virt || true"
  run_capture cgroup "cat /proc/1/cgroup"
  run_capture journal_errors_deep "journalctl -p 3 -xb --no-pager | tail -n 120"
  run_capture dmesg_tail_deep "dmesg -T | tail -n 120"
}

build_manifest() {
  python3 - "${linux_dir}" "${evidence_json}" "${raw_log}" <<'PY'
import json
import os
import sys

linux_dir, evidence_json, raw_log = sys.argv[1:4]
items = []

for filename in sorted(os.listdir(linux_dir)):
    path = os.path.join(linux_dir, filename)
    if not os.path.isfile(path):
        continue
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read().strip()
    lines = [line for line in content.splitlines() if line.strip()]
    snippet = "\n".join(lines[:12])
    items.append({
        "name": filename.rsplit(".", 1)[0],
        "path": path,
        "snippet": snippet,
        "line_count": len(content.splitlines()),
    })

payload = {
    "target": "linux",
    "mode": os.environ.get("INSPECT_MODE", "quick"),
    "raw_log": raw_log,
    "items": items,
}

with open(evidence_json, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
PY
}

main() {
  log_info "开始采集 Linux 证据，模式: ${INSPECT_MODE}"
  if [[ "${INSPECT_MODE}" == "deep" ]]; then
    collect_deep
  else
    collect_quick
  fi
  build_manifest
  cp "${evidence_json}" "${INSPECT_OUTPUT_DIR}/latest/linux-evidence.json"
  cp "${raw_log}" "${INSPECT_OUTPUT_DIR}/latest/linux-raw.log"
}

main "$@"
