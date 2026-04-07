#!/usr/bin/env bash
set -euo pipefail

# 中文日志输出函数，统一控制脚本风格，方便排查问题。

log_info() {
  printf '[INFO] %s\n' "$*" >&2
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

