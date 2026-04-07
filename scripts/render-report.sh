#!/usr/bin/env bash
set -euo pipefail

# 报告渲染脚本。
# 只读取上下文和采集结果，让 Codex 在只读模式下生成中文报告，不再现场跑巡检命令。

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "${script_dir}/lib/common.sh"

: "${WORKSPACE_DIR:?WORKSPACE_DIR 未设置}"
: "${RUN_DIR:?RUN_DIR 未设置}"
: "${INSPECTION_TARGET:?INSPECTION_TARGET 未设置}"
: "${CODEX_MODEL:=gpt-5.4}"

case "${INSPECTION_TARGET}" in
  linux)
    report_name="linux-inspection-report"
    ;;
  k8s)
    report_name="k8s-inspection-report"
    ;;
  composite)
    report_name="composite-inspection-report"
    ;;
  *)
    log_error "不支持的 INSPECTION_TARGET: ${INSPECTION_TARGET}"
    exit 2
    ;;
esac

report_md="${RUN_DIR}/${report_name}.md"
report_docx="${RUN_DIR}/${report_name}.docx"
prompt_file="${RUN_DIR}/report-input.md"
render_log="${RUN_DIR}/render-report.log"

cat > "${prompt_file}" <<EOF
你是生产巡检报告生成代理。
如果本地技能 \`ops-report-standardizer\` 可用，必须遵循它的报告结构与约束。

要求：
1. 只允许基于下面提供的上下文和证据生成报告。
2. 不要执行新的巡检命令。
3. 报告必须全部使用简体中文（zh-CN）。
4. 直接输出完整 Markdown 报告正文，不要输出额外解释。
5. 报告必须包含：
   - 执行摘要
   - 巡检范围与上下文
   - 健康分（0 到 100）
   - Findings，按 Critical / Warning / Info 分组
   - 证据表
   - 建议动作，带优先级与建议责任方
   - 不确定性说明

以下是运行上下文：

\`\`\`json
$(cat "${RUN_DIR}/context.json")
\`\`\`
EOF

if [[ -f "${RUN_DIR}/linux-evidence.json" ]]; then
  cat >> "${prompt_file}" <<EOF

以下是 Linux 巡检证据清单：

\`\`\`json
$(cat "${RUN_DIR}/linux-evidence.json")
\`\`\`
EOF
fi

if [[ -f "${RUN_DIR}/k8s-evidence.json" ]]; then
  cat >> "${prompt_file}" <<EOF

以下是 Kubernetes 巡检证据清单：

\`\`\`json
$(cat "${RUN_DIR}/k8s-evidence.json")
\`\`\`
EOF
fi

if ! codex exec \
  --skip-git-repo-check \
  -s read-only \
  -C "${WORKSPACE_DIR}" \
  -m "${CODEX_MODEL}" \
  --json \
  - < "${prompt_file}" > "${render_log}" 2>&1; then
  log_error "报告生成失败，以下是 Codex 输出日志"
  cat "${render_log}" >&2
  exit 5
fi

python3 - "${render_log}" "${report_md}" <<'PY'
import json
import sys

render_log = sys.argv[1]
report_md = sys.argv[2]
last_text = None

with open(render_log, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "item.completed":
            continue
        item = event.get("item", {})
        if item.get("type") == "agent_message" and item.get("text"):
            last_text = item["text"]

if not last_text:
    raise SystemExit("未从 Codex JSON 事件流中提取到最终报告")

with open(report_md, "w", encoding="utf-8") as f:
    f.write(last_text.rstrip() + "\n")
PY

if [[ "${INSPECT_DOCX}" == "true" ]]; then
  node "${WORKSPACE_DIR}/scripts/generate-docx-report.mjs" "${report_md}" "${report_docx}"
fi

cp "${report_md}" "${RUN_DIR}/report.md"
cp "${report_md}" "${INSPECT_OUTPUT_DIR}/latest/report.md"
if [[ -f "${report_docx}" ]]; then
  cp "${report_docx}" "${RUN_DIR}/report.docx"
  cp "${report_docx}" "${INSPECT_OUTPUT_DIR}/latest/report.docx"
fi
cp "${render_log}" "${INSPECT_OUTPUT_DIR}/latest/render-report.log"

cat "${report_md}"
