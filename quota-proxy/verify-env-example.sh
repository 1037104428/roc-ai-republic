#!/bin/bash
# 验证 .env.example 文件完整性的快速脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== 验证 .env.example 文件完整性 ===${NC}"

# 检查文件是否存在
if [ ! -f ".env.example" ]; then
    echo -e "${RED}❌ 错误: .env.example 文件不存在${NC}"
    exit 1
fi

echo -e "${GREEN}✅ .env.example 文件存在${NC}"

# 检查文件大小
file_size=$(wc -c < ".env.example")
if [ "$file_size" -lt 100 ]; then
    echo -e "${RED}❌ 警告: .env.example 文件过小 (${file_size} 字节)${NC}"
else
    echo -e "${GREEN}✅ 文件大小合适 (${file_size} 字节)${NC}"
fi

# 检查行数
line_count=$(wc -l < ".env.example")
echo -e "${GREEN}✅ 文件包含 ${line_count} 行配置${NC}"

# 检查关键配置项
required_vars=(
    "DATABASE_URL"
    "HOST"
    "PORT"
    "ADMIN_TOKEN"
    "JWT_SECRET"
    "TRIAL_KEY_PREFIX"
    "TRIAL_KEY_EXPIRY_DAYS"
    "TRIAL_REQUESTS_LIMIT"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" ".env.example"; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ 所有关键配置项都存在${NC}"
else
    echo -e "${RED}❌ 缺少以下关键配置项:${NC}"
    for var in "${missing_vars[@]}"; do
        echo -e "  ${RED}- ${var}${NC}"
    done
    exit 1
fi

# 检查注释说明
comment_count=$(grep -c "^#" ".env.example")
if [ "$comment_count" -lt 5 ]; then
    echo -e "${YELLOW}⚠️  注释较少 (${comment_count} 行)，建议增加说明${NC}"
else
    echo -e "${GREEN}✅ 注释充足 (${comment_count} 行)${NC}"
fi

# 检查格式
if grep -q "^\s*=" ".env.example"; then
    echo -e "${RED}❌ 发现格式错误: 有空变量名${NC}"
    grep -n "^\s*=" ".env.example"
    exit 1
else
    echo -e "${GREEN}✅ 变量格式正确${NC}"
fi

# 演示模式
if [ "$1" = "--demo" ]; then
    echo -e "\n${YELLOW}=== 演示模式 ===${NC}"
    echo -e "${GREEN}示例配置内容:${NC}"
    head -20 ".env.example"
    echo -e "\n${GREEN}快速使用指南:${NC}"
    echo "1. 复制配置文件: cp .env.example .env"
    echo "2. 编辑配置: nano .env"
    echo "3. 启动服务: docker compose up -d"
    echo "4. 验证配置: curl http://localhost:8787/healthz"
fi

echo -e "\n${GREEN}✅ 所有验证通过！${NC}"
echo -e "${YELLOW}提示: 使用 --demo 参数查看演示${NC}"
