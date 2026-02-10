#!/bin/bash
# 快速验证脚本汇总 - 一键运行所有核心验证
# 用于快速检查系统各组件状态

set -e

echo "=== 中华AI共和国 / OpenClaw 小白中文包 - 快速验证汇总 ==="
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 验证结果统计
PASS=0
FAIL=0
SKIP=0

# 运行验证函数
run_verify() {
    local name="$1"
    local script="$2"
    local args="$3"
    
    echo -n "🔍 验证 $name... "
    
    if [ -f "$script" ]; then
        if bash "$script" $args >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 通过${NC}"
            ((PASS++))
            return 0
        else
            echo -e "${RED}✗ 失败${NC}"
            ((FAIL++))
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ 跳过（脚本不存在）${NC}"
        ((SKIP++))
        return 2
    fi
}

# 1. 基础环境验证
echo "📦 1. 基础环境验证"
run_verify "Node.js环境" "scripts/verify-node-env.sh" "--quick"
run_verify "Docker环境" "scripts/verify-docker-env.sh" "--quick"
run_verify "Git仓库" "scripts/verify-git-repo.sh" "--quick"
echo ""

# 2. 核心组件验证
echo "🔧 2. 核心组件验证"
run_verify "SQLite数据库" "scripts/verify-sqlite-quick.sh" ""
run_verify "API网关健康" "scripts/verify-api-gateway-health.sh" "--quick"
run_verify "试用密钥" "scripts/verify-trial-key.sh" "--quick"
echo ""

# 3. 部署验证
echo "🚀 3. 部署验证"
run_verify "快速配置向导" "scripts/verify-quick-config.sh" "--dry-run"
run_verify "安装脚本" "scripts/verify-install-cn.sh" "--dry-run"
run_verify "快速入门指南" "scripts/verify-quickstart.sh" "--no-key"
echo ""

# 4. 高级功能验证
echo "⚡ 4. 高级功能验证"
run_verify "统计API" "scripts/verify-stats-api.sh" "--dry-run"
run_verify "密钥过期" "scripts/verify-key-expiration.sh" "--dry-run"
run_verify "下载统计" "scripts/verify-download-stats.sh" "--dry-run"
echo ""

# 5. 服务器验证（可选）
echo "🌐 5. 服务器验证（可选）"
read -p "是否测试远程服务器？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    run_verify "服务器部署" "scripts/verify-sqlite-deployment-full.sh" "--dry-run"
    run_verify "论坛502修复" "scripts/verify-forum-502-fix.sh" "--dry-run"
else
    echo "⚠ 跳过服务器验证"
    ((SKIP+=2))
fi
echo ""

# 汇总结果
echo "📊 验证结果汇总"
echo "=================="
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"
echo -e "${YELLOW}跳过: $SKIP${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ 所有验证通过！系统运行正常。${NC}"
    echo "提示：运行 './scripts/verify-quickstart.sh' 进行完整验证"
    exit 0
else
    echo -e "${RED}❌ 有 $FAIL 项验证失败，请检查相关组件。${NC}"
    echo "提示：查看具体验证脚本的输出以获取详细信息"
    exit 1
fi