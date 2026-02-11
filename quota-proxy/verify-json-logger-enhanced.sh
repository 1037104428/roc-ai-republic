#!/bin/bash

# verify-json-logger-enhanced.sh - JSON格式日志增强验证脚本
# 验证JSON格式日志增强功能，包括日志级别控制、结构化日志输出等

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  JSON格式日志增强验证脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查日志目录
echo -e "${BLUE}[1/8] 检查日志目录结构...${NC}"
if [ -d "${PROJECT_ROOT}/logs" ]; then
    echo -e "  ${GREEN}✓ 日志目录存在: ${PROJECT_ROOT}/logs${NC}"
    ls -la "${PROJECT_ROOT}/logs/" 2>/dev/null || echo "  ℹ️ 日志目录为空"
else
    echo -e "  ${YELLOW}⚠ 日志目录不存在，创建中...${NC}"
    mkdir -p "${PROJECT_ROOT}/logs"
    echo -e "  ${GREEN}✓ 日志目录已创建${NC}"
fi

# 检查JSON日志中间件文件
echo -e "${BLUE}[2/8] 检查JSON日志中间件文件...${NC}"
JSON_LOGGER_FILE="${PROJECT_ROOT}/middleware/json-logger.js"
if [ -f "${JSON_LOGGER_FILE}" ]; then
    echo -e "  ${GREEN}✓ JSON日志中间件文件存在: ${JSON_LOGGER_FILE}${NC}"
    
    # 检查文件内容
    if grep -q "JSON.stringify" "${JSON_LOGGER_FILE}"; then
        echo -e "  ${GREEN}✓ 文件包含JSON.stringify调用${NC}"
    else
        echo -e "  ${YELLOW}⚠ 文件可能不包含JSON格式化代码${NC}"
    fi
    
    if grep -q "logLevel" "${JSON_LOGGER_FILE}"; then
        echo -e "  ${GREEN}✓ 文件包含日志级别控制${NC}"
    else
        echo -e "  ${YELLOW}⚠ 文件可能不包含日志级别控制${NC}"
    fi
else
    echo -e "  ${RED}✗ JSON日志中间件文件不存在${NC}"
    echo -e "  ${YELLOW}建议创建 ${JSON_LOGGER_FILE}${NC}"
fi

# 检查服务器文件中的日志中间件集成
echo -e "${BLUE}[3/8] 检查服务器文件中的日志中间件集成...${NC}"
SERVER_FILES=(
    "server-sqlite-admin.js"
    "server-sqlite.js"
    "server.js"
)

for server_file in "${SERVER_FILES[@]}"; do
    if [ -f "${PROJECT_ROOT}/${server_file}" ]; then
        echo -e "  ${BLUE}检查 ${server_file}...${NC}"
        if grep -q "json-logger" "${PROJECT_ROOT}/${server_file}" || grep -q "jsonLogger" "${PROJECT_ROOT}/${server_file}"; then
            echo -e "    ${GREEN}✓ 包含JSON日志中间件引用${NC}"
        else
            echo -e "    ${YELLOW}⚠ 不包含JSON日志中间件引用${NC}"
        fi
    fi
done

# 检查环境变量配置
echo -e "${BLUE}[4/8] 检查环境变量配置...${NC}"
ENV_FILES=(
    ".env"
    ".env.example"
)

for env_file in "${ENV_FILES[@]}"; do
    if [ -f "${PROJECT_ROOT}/${env_file}" ]; then
        echo -e "  ${BLUE}检查 ${env_file}...${NC}"
        if grep -q "LOG_LEVEL" "${PROJECT_ROOT}/${env_file}"; then
            echo -e "    ${GREEN}✓ 包含LOG_LEVEL环境变量${NC}"
        else
            echo -e "    ${YELLOW}⚠ 不包含LOG_LEVEL环境变量${NC}"
        fi
        
        if grep -q "JSON_LOGS" "${PROJECT_ROOT}/${env_file}"; then
            echo -e "    ${GREEN}✓ 包含JSON_LOGS环境变量${NC}"
        else
            echo -e "    ${YELLOW}⚠ 不包含JSON_LOGS环境变量${NC}"
        fi
    fi
done

# 检查日志级别控制文档
echo -e "${BLUE}[5/8] 检查日志级别控制文档...${NC}"
LOG_LEVEL_DOC="${PROJECT_ROOT}/LOG-LEVEL-CONTROL.md"
if [ -f "${LOG_LEVEL_DOC}" ]; then
    echo -e "  ${GREEN}✓ 日志级别控制文档存在: ${LOG_LEVEL_DOC}${NC}"
    
    # 检查文档内容
    if grep -q "日志级别" "${LOG_LEVEL_DOC}"; then
        echo -e "  ${GREEN}✓ 文档包含日志级别说明${NC}"
    fi
    
    if grep -q "debug\|info\|warn\|error" "${LOG_LEVEL_DOC}"; then
        echo -e "  ${GREEN}✓ 文档包含标准日志级别${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ 日志级别控制文档不存在${NC}"
    echo -e "  ${YELLOW}建议创建 ${LOG_LEVEL_DOC}${NC}"
fi

# 检查结构化日志示例
echo -e "${BLUE}[6/8] 检查结构化日志示例...${NC}"
STRUCTURED_LOG_EXAMPLE="${PROJECT_ROOT}/STRUCTURED-LOG-EXAMPLES.md"
if [ -f "${STRUCTURED_LOG_EXAMPLE}" ]; then
    echo -e "  ${GREEN}✓ 结构化日志示例文档存在: ${STRUCTURED_LOG_EXAMPLE}${NC}"
    
    # 检查示例内容
    if grep -q "timestamp\|level\|message" "${STRUCTURED_LOG_EXAMPLE}"; then
        echo -e "  ${GREEN}✓ 文档包含结构化日志字段${NC}"
    fi
    
    if grep -q "JSON" "${STRUCTURED_LOG_EXAMPLE}"; then
        echo -e "  ${GREEN}✓ 文档包含JSON格式示例${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ 结构化日志示例文档不存在${NC}"
    echo -e "  ${YELLOW}建议创建 ${STRUCTURED_LOG_EXAMPLE}${NC}"
fi

# 检查验证工具链集成
echo -e "${BLUE}[7/8] 检查验证工具链集成...${NC}"
VALIDATION_INDEX="${PROJECT_ROOT}/VALIDATION-TOOLS-INDEX.md"
if [ -f "${VALIDATION_INDEX}" ]; then
    if grep -q "verify-json-logger-enhanced.sh" "${VALIDATION_INDEX}"; then
        echo -e "  ${GREEN}✓ 验证工具索引包含本脚本${NC}"
    else
        echo -e "  ${YELLOW}⚠ 验证工具索引不包含本脚本${NC}"
    fi
fi

ENHANCED_CHECK="${PROJECT_ROOT}/verify-validation-docs-enhanced.sh"
if [ -f "${ENHANCED_CHECK}" ]; then
    if grep -q "verify-json-logger-enhanced.sh" "${ENHANCED_CHECK}"; then
        echo -e "  ${GREEN}✓ 增强版检查脚本包含本脚本检查${NC}"
    else
        echo -e "  ${YELLOW}⚠ 增强版检查脚本不包含本脚本检查${NC}"
    fi
fi

# 验证总结
echo -e "${BLUE}[8/8] 验证总结...${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  JSON格式日志增强验证完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✅ 验证项目:${NC}"
echo "  1. 日志目录结构检查"
echo "  2. JSON日志中间件文件检查"
echo "  3. 服务器文件集成检查"
echo "  4. 环境变量配置检查"
echo "  5. 日志级别控制文档检查"
echo "  6. 结构化日志示例检查"
echo "  7. 验证工具链集成检查"
echo ""
echo -e "${YELLOW}📋 建议改进:${NC}"
echo "  1. 创建JSON日志中间件文件 (middleware/json-logger.js)"
echo "  2. 更新服务器文件集成JSON日志中间件"
echo "  3. 添加LOG_LEVEL和JSON_LOGS环境变量"
echo "  4. 创建日志级别控制文档 (LOG-LEVEL-CONTROL.md)"
echo "  5. 创建结构化日志示例文档 (STRUCTURED-LOG-EXAMPLES.md)"
echo "  6. 更新验证工具链索引"
echo ""
echo -e "${BLUE}💡 使用提示:${NC}"
echo "  运行此脚本验证JSON格式日志增强功能:"
echo "  $ cd quota-proxy && ./verify-json-logger-enhanced.sh"
echo ""
echo -e "${GREEN}✅ JSON格式日志增强验证脚本创建完成${NC}"

# 添加执行权限
chmod +x "${PROJECT_ROOT}/verify-json-logger-enhanced.sh"
echo -e "${GREEN}✅ 脚本已添加执行权限${NC}"