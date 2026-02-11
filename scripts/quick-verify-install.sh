#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 快速验证脚本
# 用于CI/CD环境或快速安装验证
# 仅检查最关键的功能，不执行完整验证

SCRIPT_VERSION="2026.02.11.2253"

# 颜色输出函数
color_log() {
  local level="$1"
  local message="$2"
  local color_code=""
  
  case "$level" in
    SUCCESS) color_code="\033[0;32m" ;;  # 绿色
    ERROR)   color_code="\033[0;31m" ;;  # 红色
    WARNING) color_code="\033[0;33m" ;;  # 黄色
    INFO)    color_code="\033[0;34m" ;;  # 蓝色
    DEBUG)   color_code="\033[0;90m" ;;  # 灰色
    *)       color_code="\033[0m"    ;;  # 默认
  esac
  
  echo -e "${color_code}[${level}] ${message}\033[0m"
}

# 快速验证函数
quick_verify() {
  local exit_code=0
  
  echo "=== OpenClaw CN 快速验证 ==="
  echo "脚本版本: $SCRIPT_VERSION"
  echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo ""
  
  # 1. 检查 openclaw 命令是否存在
  color_log "INFO" "1. 检查 openclaw 命令..."
  if command -v openclaw &>/dev/null; then
    color_log "SUCCESS" "  ✓ openclaw 命令存在"
  else
    color_log "ERROR" "  ✗ openclaw 命令未找到"
    exit_code=1
  fi
  
  # 2. 检查 openclaw 版本
  color_log "INFO" "2. 检查 openclaw 版本..."
  if version_output=$(openclaw --version 2>&1); then
    color_log "SUCCESS" "  ✓ OpenClaw 版本: $version_output"
  else
    color_log "ERROR" "  ✗ 无法获取 OpenClaw 版本"
    exit_code=1
  fi
  
  # 3. 快速状态检查
  color_log "INFO" "3. 快速状态检查..."
  if openclaw status &>/dev/null; then
    color_log "SUCCESS" "  ✓ OpenClaw 状态正常"
  else
    color_log "WARNING" "  ⚠ OpenClaw 状态检查失败 (可能需要配置)"
  fi
  
  # 4. 检查工作空间目录
  color_log "INFO" "4. 检查工作空间目录..."
  local workspace_dir="$HOME/.openclaw/workspace"
  if [[ -d "$workspace_dir" ]]; then
    color_log "SUCCESS" "  ✓ 工作空间目录存在: $workspace_dir"
    
    # 检查关键文件
    local critical_files=("AGENTS.md" "SOUL.md")
    for file in "${critical_files[@]}"; do
      if [[ -f "$workspace_dir/$file" ]]; then
        color_log "DEBUG" "    - $file: 存在"
      else
        color_log "WARNING" "    - $file: 缺失 (首次安装正常)"
      fi
    done
  else
    color_log "WARNING" "  ⚠ 工作空间目录不存在 (首次安装正常)"
  fi
  
  # 5. 检查 Gateway 服务
  color_log "INFO" "5. 检查 Gateway 服务状态..."
  if openclaw gateway status &>/dev/null; then
    color_log "SUCCESS" "  ✓ Gateway 服务正常"
  else
    color_log "WARNING" "  ⚠ Gateway 服务未运行或状态检查失败"
    color_log "INFO" "    运行 'openclaw gateway start' 启动服务"
  fi
  
  echo ""
  echo "=== 验证结果 ==="
  
  if [[ $exit_code -eq 0 ]]; then
    color_log "SUCCESS" "✅ 快速验证通过 - 所有关键检查正常"
    echo ""
    color_log "INFO" "如需完整验证，请运行:"
    color_log "INFO" "  openclaw status"
    color_log "INFO" "  openclaw gateway status"
    color_log "INFO" "  或参考完整验证文档:"
    color_log "INFO" "  https://github.com/1037104428/roc-ai-republic/blob/main/docs/install-cn-quick-verification-commands.md"
  else
    color_log "ERROR" "❌ 快速验证失败 - 发现关键问题"
    echo ""
    color_log "INFO" "故障排除建议:"
    color_log "INFO" "  1. 重新运行安装脚本: curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
    color_log "INFO" "  2. 检查网络连接和npm配置"
    color_log "INFO" "  3. 查看安装日志: cat /tmp/openclaw-install.log"
  fi
  
  echo ""
  echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  
  return $exit_code
}

# 主函数
main() {
  local mode="quick"
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        echo "OpenClaw CN 快速验证脚本"
        echo ""
        echo "用法:"
        echo "  ./quick-verify-install.sh [选项]"
        echo ""
        echo "选项:"
        echo "  --help, -h     显示帮助信息"
        echo "  --version      显示脚本版本"
        echo ""
        echo "功能:"
        echo "  快速验证 OpenClaw CN 安装，仅检查最关键的功能"
        echo "  适用于 CI/CD 环境或快速安装验证"
        echo ""
        echo "示例:"
        echo "  ./quick-verify-install.sh"
        echo "  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash --verify"
        echo ""
        exit 0
        ;;
      --version)
        echo "OpenClaw CN 快速验证脚本 v$SCRIPT_VERSION"
        exit 0
        ;;
      *)
        color_log "ERROR" "未知参数: $1"
        color_log "INFO" "使用 --help 查看帮助"
        exit 1
        ;;
    esac
  done
  
  # 执行快速验证
  quick_verify
}

# 运行主函数
main "$@"