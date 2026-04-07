#!/usr/bin/env bash
set -euo pipefail

# Kubernetes 快速采集脚本。
# 优先复用已登录环境和 kubeconfig；如果凭据缺失，也会产出结构化失败说明，方便报告层输出。

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "${script_dir}/lib/common.sh"

: "${RUN_DIR:?RUN_DIR 未设置}"
: "${INSPECT_MODE:=quick}"
: "${K8S_AUTH_AVAILABLE:=false}"

k8s_dir="${RUN_DIR}/k8s"
raw_log="${RUN_DIR}/k8s-raw.log"
evidence_json="${RUN_DIR}/k8s-evidence.json"

ensure_dir "${k8s_dir}"
: > "${raw_log}"

run_capture() {
  local key="$1"
  shift
  local output_file="${k8s_dir}/${key}.txt"
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

write_unavailable_manifest() {
  python3 - "${evidence_json}" "${raw_log}" <<'PY'
import json
import os
import sys

target, raw_log = sys.argv[1:3]
payload = {
    "target": "k8s",
    "mode": os.environ.get("INSPECT_MODE", "quick"),
    "available": False,
    "reason": "未检测到可用的 Kubernetes 登录环境或 kubeconfig",
    "raw_log": raw_log,
    "items": [],
}
with open(target, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
PY
}

collect_quick() {
  run_capture kubectl_client "kubectl version --client"
  run_capture current_context "kubectl config current-context"
  run_capture cluster_info "kubectl cluster-info"
  run_capture nodes "kubectl get nodes -o wide"
  run_capture namespaces "kubectl get ns"
  run_capture pods_all "kubectl get pods -A"
  run_capture events "kubectl get events -A --sort-by=.lastTimestamp | tail -n 80"
}

collect_deep() {
  collect_quick
  run_capture top_nodes "kubectl top nodes"
  run_capture top_pods "kubectl top pods -A"
  run_capture apiservices_false "kubectl get apiservices | grep False || true"
}

build_manifest() {
  python3 - "${k8s_dir}" "${evidence_json}" "${raw_log}" <<'PY'
import json
import os
import sys

k8s_dir, evidence_json, raw_log = sys.argv[1:4]
items = []

for filename in sorted(os.listdir(k8s_dir)):
    path = os.path.join(k8s_dir, filename)
    if not os.path.isfile(path):
        continue
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read().strip()
    lines = [line for line in content.splitlines() if line.strip()]
    snippet = "\n".join(lines[:15])
    items.append({
        "name": filename.rsplit(".", 1)[0],
        "path": path,
        "snippet": snippet,
        "line_count": len(content.splitlines()),
    })

payload = {
    "target": "k8s",
    "mode": os.environ.get("INSPECT_MODE", "quick"),
    "available": True,
    "raw_log": raw_log,
    "items": items,
}

with open(evidence_json, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
PY
}

main() {
  if ! command_exists kubectl || [[ "${K8S_AUTH_AVAILABLE}" != "true" ]]; then
    log_warn "Kubernetes 凭据不可用，输出不可用证据清单"
    write_unavailable_manifest
    cp "${evidence_json}" "${INSPECT_OUTPUT_DIR}/latest/k8s-evidence.json"
    cp "${raw_log}" "${INSPECT_OUTPUT_DIR}/latest/k8s-raw.log"
    return 0
  fi

  log_info "开始采集 Kubernetes 证据，模式: ${INSPECT_MODE}"
  if [[ "${INSPECT_MODE}" == "deep" ]]; then
    collect_deep
  else
    collect_quick
  fi
  build_manifest
  cp "${evidence_json}" "${INSPECT_OUTPUT_DIR}/latest/k8s-evidence.json"
  cp "${raw_log}" "${INSPECT_OUTPUT_DIR}/latest/k8s-raw.log"
}

main "$@"
