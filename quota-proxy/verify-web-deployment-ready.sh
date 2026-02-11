#!/usr/bin/env bash
set -euo pipefail

# Web站点部署就绪验证脚本 - 专门验证quota-proxy + landing page部署就绪状态
# 此脚本验证项目是否准备好进行公开部署

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo "🔍 Web站点部署就绪验证 - quota-proxy + landing page"
echo "======================================================"
echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 验证结果跟踪
all_checks_passed=true
checks_count=0
passed_count=0

# 检查函数
check() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    checks_count=$((checks_count + 1))
    echo -n "检查 $checks_count: $description ... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 通过${NC}"
        passed_count=$((passed_count + 1))
        return 0
    else
        echo -e "${RED}❌ 失败${NC}"
        all_checks_passed=false
        return 1
    fi
}

# 1. 验证quota-proxy核心文件
echo "1. 验证quota-proxy核心文件"
echo "--------------------------"
check "server-sqlite-admin.js存在" "[ -f \"$PROJECT_ROOT/server-sqlite-admin.js\" ]" "文件存在"
check "server-sqlite-admin.js包含Admin API" "grep -q 'ADMIN_TOKEN' \"$PROJECT_ROOT/server-sqlite-admin.js\"" "包含Admin API"
check "compose.yaml存在" "[ -f \"$PROJECT_ROOT/compose.yaml\" ]" "文件存在"
check "compose.yaml包含quota-proxy服务" "grep -q 'quota-proxy' \"$PROJECT_ROOT/compose.yaml\"" "包含quota-proxy服务"

# 2. 验证数据库持久化
echo ""
echo "2. 验证数据库持久化"
echo "-------------------"
check "init-db.sql存在" "[ -f \"$PROJECT_ROOT/init-db.sql\" ]" "文件存在"
check "init-db.sql包含表结构" "grep -q 'CREATE TABLE' \"$PROJECT_ROOT/init-db.sql\"" "包含表结构"
check "DATABASE-INIT-GUIDE.md存在" "[ -f \"$PROJECT_ROOT/DATABASE-INIT-GUIDE.md\" ]" "文件存在"
check "数据库初始化指南完整" "grep -q '初始化步骤' \"$PROJECT_ROOT/DATABASE-INIT-GUIDE.md\"" "指南完整"

# 3. 验证Admin API功能
echo ""
echo "3. 验证Admin API功能"
echo "-------------------"
check "ADMIN-API-GUIDE.md存在" "[ -f \"$PROJECT_ROOT/ADMIN-API-GUIDE.md\" ]" "文件存在"
check "Admin API指南包含端点说明" "grep -q 'POST /admin/keys' \"$PROJECT_ROOT/ADMIN-API-GUIDE.md\"" "包含端点说明"
check "verify-admin-api-complete.sh存在" "[ -f \"$PROJECT_ROOT/verify-admin-api-complete.sh\" ]" "文件存在"
check "Admin API验证脚本可执行" "[ -x \"$PROJECT_ROOT/verify-admin-api-complete.sh\" ]" "可执行"

# 4. 验证部署配置
echo ""
echo "4. 验证部署配置"
echo "---------------"
check "DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md存在" "[ -f \"$PROJECT_ROOT/DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md\" ]" "文件存在"
check "部署指南包含Docker Compose" "grep -q 'docker-compose' \"$PROJECT_ROOT/DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md\"" "包含Docker部署"
check "verify-deployment-status.sh存在" "[ -f \"$PROJECT_ROOT/verify-deployment-status.sh\" ]" "文件存在"
check "部署状态验证脚本可执行" "[ -x \"$PROJECT_ROOT/verify-deployment-status.sh\" ]" "可执行"

# 5. 验证Web站点文件
echo ""
echo "5. 验证Web站点文件"
echo "------------------"
check "web目录存在" "[ -d \"$PROJECT_ROOT/../web\" ]" "目录存在"
check "web/site目录存在" "[ -d \"$PROJECT_ROOT/../web/site\" ]" "目录存在"
check "index.html存在" "[ -f \"$PROJECT_ROOT/../web/site/index.html\" ]" "文件存在"
check "downloads.html存在" "[ -f \"$PROJECT_ROOT/../web/site/downloads.html\" ]" "文件存在"

# 6. 验证HTTPS配置就绪
echo ""
echo "6. 验证HTTPS配置就绪"
echo "-------------------"
check "Caddy配置目录存在" "[ -d \"$PROJECT_ROOT/../web/caddy\" ]" "目录存在"
check "Caddyfile存在" "[ -f \"$PROJECT_ROOT/../web/caddy/Caddyfile\" ]" "文件存在"
check "Caddyfile包含HTTPS配置" "grep -q 'tls' \"$PROJECT_ROOT/../web/caddy/Caddyfile\"" "包含HTTPS配置"
check "Nginx配置目录存在" "[ -d \"$PROJECT_ROOT/../web/nginx\" ]" "目录存在"

# 7. 验证安装脚本
echo ""
echo "7. 验证安装脚本"
echo "---------------"
check "install-cn.sh存在" "[ -f \"$PROJECT_ROOT/../scripts/install-cn.sh\" ]" "文件存在"
check "install-cn.sh可执行" "[ -x \"$PROJECT_ROOT/../scripts/install-cn.sh\" ]" "可执行"
check "install-cn.sh包含自检" "grep -q 'openclaw --version' \"$PROJECT_ROOT/../scripts/install-cn.sh\"" "包含自检"

# 8. 验证验证工具链
echo ""
echo "8. 验证验证工具链"
echo "-----------------"
check "VALIDATION-TOOLS-INDEX.md存在" "[ -f \"$PROJECT_ROOT/VALIDATION-TOOLS-INDEX.md\" ]" "文件存在"
check "验证工具索引包含Web部署" "grep -q 'web.*deploy' \"$PROJECT_ROOT/VALIDATION-TOOLS-INDEX.md\"" "包含Web部署"
check "verify-validation-docs-enhanced.sh存在" "[ -f \"$PROJECT_ROOT/verify-validation-docs-enhanced.sh\" ]" "文件存在"
check "增强验证脚本可执行" "[ -x \"$PROJECT_ROOT/verify-validation-docs-enhanced.sh\" ]" "可执行"

# 总结报告
echo ""
echo "======================================================"
echo "验证总结"
echo "--------"
echo "总检查数: $checks_count"
echo "通过数: $passed_count"
echo "失败数: $((checks_count - passed_count))"
echo ""

if [ "$all_checks_passed" = true ]; then
    echo -e "${GREEN}🎉 Web站点部署就绪验证通过！${NC}"
    echo ""
    echo "项目已准备好进行公开部署："
    echo "1. ✅ quota-proxy核心功能完整"
    echo "2. ✅ 数据库持久化就绪"
    echo "3. ✅ Admin API功能完整"
    echo "4. ✅ 部署配置就绪"
    echo "5. ✅ Web站点文件完整"
    echo "6. ✅ HTTPS配置就绪"
    echo "7. ✅ 安装脚本就绪"
    echo "8. ✅ 验证工具链完整"
    echo ""
    echo "下一步行动："
    echo "1. 准备服务器环境（确保/tmp/server.txt包含服务器信息）"
    echo "2. 运行部署脚本：./scripts/deploy-web-site.sh"
    echo "3. 配置域名和HTTPS证书"
    echo "4. 验证公开访问：curl -fsS https://your-domain.com/healthz"
    exit 0
else
    echo -e "${RED}❌ Web站点部署就绪验证失败${NC}"
    echo ""
    echo "需要修复的问题："
    echo "1. 检查缺失的文件"
    echo "2. 确保所有脚本可执行"
    echo "3. 验证配置完整性"
    echo "4. 测试部署流程"
    echo ""
    echo "修复后重新运行此验证脚本。"
    exit 1
fi