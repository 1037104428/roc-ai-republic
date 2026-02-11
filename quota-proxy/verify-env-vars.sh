#!/bin/bash

# 环境变量验证脚本
# 验证quota-proxy关键环境变量是否已正确设置
# 支持快速验证模式：使用 --quick 参数仅检查必需环境变量

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 参数解析
QUICK_MODE=false
if [[ "$1" == "--quick" ]]; then
  QUICK_MODE=true
fi

echo -e "${BLUE}=== 环境变量验证脚本 ===${NC}"
if [[ "$QUICK_MODE" == "true" ]]; then
  echo -e "${YELLOW}快速验证模式${NC}"
fi
echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 必需的环境变量列表
REQUIRED_VARS=(
  "ADMIN_TOKEN"
  "DATABASE_URL"
  "PORT"
)

# 可选的环境变量列表
OPTIONAL_VARS=(
  "LOG_LEVEL"
  "CORS_ORIGIN"
  "RATE_LIMIT_WINDOW"
  "RATE_LIMIT_MAX"
)

# 验证必需环境变量
echo -e "${BLUE}=== 必需环境变量检查 ===${NC}"
missing_count=0
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo -e "${RED}✗ ${var}: 未设置${NC}"
    missing_count=$((missing_count + 1))
  else
    # 隐藏敏感信息的值
    if [[ "$var" == "ADMIN_TOKEN" || "$var" == "DATABASE_URL" ]]; then
      echo -e "${GREEN}✓ ${var}: 已设置 (值已隐藏)${NC}"
    else
      echo -e "${GREEN}✓ ${var}: ${!var}${NC}"
    fi
  fi
done

echo ""

# 验证可选环境变量（仅在非快速模式下）
if [[ "$QUICK_MODE" == "false" ]]; then
  echo -e "${BLUE}=== 可选环境变量检查 ===${NC}"
  for var in "${OPTIONAL_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
      echo -e "${YELLOW}⚠ ${var}: 未设置 (可选)${NC}"
    else
      echo -e "${GREEN}✓ ${var}: ${!var}${NC}"
    fi
  done
  echo ""
fi

# 验证结果总结
if [[ $missing_count -eq 0 ]]; then
  echo -e "${GREEN}✅ 所有必需环境变量已正确设置${NC}"
  echo -e "${GREEN}环境变量配置验证通过，可以启动服务${NC}"
  exit 0
else
  echo -e "${RED}❌ 缺少 ${missing_count} 个必需环境变量${NC}"
  echo -e "${YELLOW}请设置以下环境变量：${NC}"
  for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
      echo "  - ${var}"
    fi
  done
  echo ""
  echo -e "${YELLOW}设置示例：${NC}"
  echo "  export ADMIN_TOKEN=\"your-secret-token\""
  echo "  export DATABASE_URL=\"sqlite:///data/quota.db\""
  echo "  export PORT=8787"
  exit 1
fi

# 使用说明（仅在非快速模式下）
if [[ "$QUICK_MODE" == "false" ]]; then
  echo -e "${BLUE}=== 使用说明 ===${NC}"
  echo "使用方法："
  echo "  1. 完整验证：./verify-env-vars.sh"
  echo "  2. 快速验证：./verify-env-vars.sh --quick"
  echo ""
  echo "快速验证模式仅检查必需环境变量，适合CI/CD流水线或快速部署验证。"
  echo "完整验证模式包含可选环境变量检查，适合详细环境配置验证。"
fi
