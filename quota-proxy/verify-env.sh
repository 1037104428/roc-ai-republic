#!/bin/bash
# 环境变量验证脚本 - 验证quota-proxy必需的环境变量

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 必需的环境变量
REQUIRED_ENV_VARS=(
  "ADMIN_TOKEN"
  "PORT"
  "DATABASE_PATH"
)

# 可选的环境变量
OPTIONAL_ENV_VARS=(
  "LOG_LEVEL"
  "MAX_REQUESTS_PER_KEY"
  "RATE_LIMIT_WINDOW_MS"
  "ALLOWED_ORIGINS"
)

# 显示帮助信息
show_help() {
  cat << EOH
环境变量验证脚本 - 验证quota-proxy必需的环境变量

用法: $0 [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只检查不设置
  --strict, -s        严格模式，缺少必需变量时退出码为1
  --verbose, -v       详细模式，显示所有检查详情

示例:
  $0                    # 基本验证
  $0 --dry-run         # 干运行模式
  $0 --strict          # 严格模式
  $0 --verbose         # 详细模式

功能:
  - 检查必需环境变量是否已设置
  - 检查可选环境变量是否已设置
  - 验证环境变量格式（如端口号范围）
  - 提供详细的验证报告
EOH
}

# 解析命令行参数
DRY_RUN=false
STRICT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      show_help
      exit 0
      ;;
    --dry-run|-d)
      DRY_RUN=true
      shift
      ;;
    --strict|-s)
      STRICT=true
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    *)
      echo -e "${RED}错误: 未知选项 '$1'${NC}"
      show_help
      exit 1
      ;;
  esac
done

# 验证结果统计
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# 打印验证结果
print_result() {
  local status="$1"
  local message="$2"
  
  case "$status" in
    "PASS")
      echo -e "${GREEN}✅ ${message}${NC}"
      PASS_COUNT=$((PASS_COUNT + 1))
      ;;
    "WARN")
      echo -e "${YELLOW}⚠️  ${message}${NC}"
      WARN_COUNT=$((WARN_COUNT + 1))
      ;;
    "FAIL")
      echo -e "${RED}❌ ${message}${NC}"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ;;
  esac
}

# 验证必需环境变量
echo -e "${BLUE}=== 验证必需环境变量 ===${NC}"
for var in "${REQUIRED_ENV_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    print_result "FAIL" "必需环境变量 $var 未设置"
  else
    if [[ "$VERBOSE" == "true" ]]; then
      print_result "PASS" "必需环境变量 $var 已设置: ${!var}"
    else
      print_result "PASS" "必需环境变量 $var 已设置"
    fi
  fi
done

# 验证可选环境变量
echo -e "${BLUE}=== 验证可选环境变量 ===${NC}"
for var in "${OPTIONAL_ENV_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    print_result "WARN" "可选环境变量 $var 未设置（使用默认值）"
  else
    if [[ "$VERBOSE" == "true" ]]; then
      print_result "PASS" "可选环境变量 $var 已设置: ${!var}"
    else
      print_result "PASS" "可选环境变量 $var 已设置"
    fi
  fi
done

# 验证环境变量格式
echo -e "${BLUE}=== 验证环境变量格式 ===${NC}"

# 验证端口号
if [[ -n "${PORT:-}" ]]; then
  if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
    print_result "PASS" "端口号 $PORT 格式正确"
  else
    print_result "FAIL" "端口号 $PORT 格式错误（必须是1-65535之间的数字）"
  fi
fi

# 验证管理员令牌格式
if [[ -n "${ADMIN_TOKEN:-}" ]]; then
  if [[ "${#ADMIN_TOKEN}" -ge 16 ]]; then
    print_result "PASS" "管理员令牌长度足够（${#ADMIN_TOKEN}字符）"
  else
    print_result "WARN" "管理员令牌长度较短（${#ADMIN_TOKEN}字符），建议至少16字符"
  fi
fi

# 验证数据库路径
if [[ -n "${DATABASE_PATH:-}" ]]; then
  if [[ "$DATABASE_PATH" == *.db ]] || [[ "$DATABASE_PATH" == *.sqlite ]] || [[ "$DATABASE_PATH" == *.sqlite3 ]]; then
    print_result "PASS" "数据库路径 $DATABASE_PATH 格式正确"
  else
    print_result "WARN" "数据库路径 $DATABASE_PATH 建议使用.db、.sqlite或.sqlite3扩展名"
  fi
fi

# 显示验证摘要
echo -e "${BLUE}=== 验证摘要 ===${NC}"
echo -e "通过: ${GREEN}$PASS_COUNT${NC}"
echo -e "警告: ${YELLOW}$WARN_COUNT${NC}"
echo -e "失败: ${RED}$FAIL_COUNT${NC}"

# 根据模式决定退出码
if [[ "$STRICT" == "true" && "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "${RED}严格模式：存在失败项，退出码为1${NC}"
  exit 1
elif [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "${YELLOW}存在失败项，但非严格模式，退出码为0${NC}"
  exit 0
else
  echo -e "${GREEN}所有验证通过！${NC}"
  exit 0
fi
