#!/bin/bash

# 环境变量验证脚本
# 验证quota-proxy部署所需的关键环境变量配置

set -e

echo -e "\033[1;36m========================================\033[0m"
echo -e "\033[1;36m   quota-proxy 环境变量验证脚本\033[0m"
echo -e "\033[1;36m========================================\033[0m"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 验证结果计数器
total_checks=0
passed_checks=0
warning_checks=0
failed_checks=0

# 函数：检查环境变量
check_env_var() {
    local var_name="$1"
    local required="$2"
    local description="$3"
    
    total_checks=$((total_checks + 1))
    
    if [ -n "${!var_name}" ]; then
        echo -e "${GREEN}✓${NC} ${var_name}: ${!var_name}"
        echo -e "   ${BLUE}说明:${NC} ${description}"
        passed_checks=$((passed_checks + 1))
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}✗${NC} ${var_name}: 未设置 (必需)"
            echo -e "   ${BLUE}说明:${NC} ${description}"
            failed_checks=$((failed_checks + 1))
        else
            echo -e "${YELLOW}⚠${NC} ${var_name}: 未设置 (可选)"
            echo -e "   ${BLUE}说明:${NC} ${description}"
            warning_checks=$((warning_checks + 1))
        fi
    fi
}

echo -e "\n\033[1;34m1. 必需环境变量检查:\033[0m"

# 必需环境变量
check_env_var "ADMIN_TOKEN" "required" "管理员API访问令牌，用于保护Admin API端点"
check_env_var "DATABASE_URL" "required" "SQLite数据库文件路径，例如: sqlite:///data/quota.db"
check_env_var "PORT" "required" "quota-proxy服务监听端口，默认: 8787"

echo -e "\n\033[1;34m2. 可选环境变量检查:\033[0m"

# 可选环境变量
check_env_var "LOG_LEVEL" "optional" "日志级别: debug, info, warn, error (默认: info)"
check_env_var "MAX_REQUESTS_PER_MINUTE" "optional" "每分钟最大请求数限制 (默认: 60)"
check_env_var "JWT_SECRET" "optional" "JWT令牌签名密钥 (如果使用JWT认证)"
check_env_var "CORS_ORIGIN" "optional" "CORS允许的来源，多个用逗号分隔"
check_env_var "RATE_LIMIT_ENABLED" "optional" "是否启用速率限制: true/false (默认: true)"
check_env_var "TRIAL_KEY_EXPIRY_DAYS" "optional" "试用密钥有效期天数 (默认: 7)"

echo -e "\n\033[1;34m3. 数据库相关环境变量:\033[0m"

check_env_var "DB_PATH" "optional" "SQLite数据库文件路径 (替代DATABASE_URL)"
check_env_var "DB_MIGRATE_ON_START" "optional" "启动时自动迁移数据库: true/false (默认: true)"

echo -e "\n\033[1;34m4. 部署环境变量:\033[0m"

check_env_var "NODE_ENV" "optional" "Node.js环境: development, production, test (默认: production)"
check_env_var "HOST" "optional" "服务绑定主机地址 (默认: 0.0.0.0)"

echo -e "\n\033[1;36m========================================\033[0m"
echo -e "\033[1;36m           验证结果摘要\033[0m"
echo -e "\033[1;36m========================================\033[0m"

echo -e "总检查数: ${total_checks}"
echo -e "${GREEN}通过:${NC} ${passed_checks}"
echo -e "${YELLOW}警告:${NC} ${warning_checks}"
echo -e "${RED}失败:${NC} ${failed_checks}"

if [ $failed_checks -gt 0 ]; then
    echo -e "\n${RED}❌ 验证失败: 必需环境变量未设置${NC}"
    echo -e "请设置上述标记为'必需'的环境变量后再启动服务。"
    echo -e "\n${YELLOW}快速设置示例:${NC}"
    echo -e "export ADMIN_TOKEN=\"your-secure-admin-token-here\""
    echo -e "export DATABASE_URL=\"sqlite:///data/quota.db\""
    echo -e "export PORT=8787"
    exit 1
elif [ $warning_checks -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ 验证通过但有警告: 可选环境变量未设置${NC}"
    echo -e "服务可以正常运行，但某些功能可能使用默认值。"
    echo -e "建议根据需求设置可选环境变量以优化配置。"
    exit 0
else
    echo -e "\n${GREEN}✅ 验证通过: 所有环境变量配置正确${NC}"
    echo -e "可以正常启动quota-proxy服务。"
    exit 0
fi