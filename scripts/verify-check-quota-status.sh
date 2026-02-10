#!/bin/bash
# 验证 check-quota-status.sh 脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHECK_SCRIPT="${PROJECT_ROOT}/scripts/check-quota-status.sh"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header() {
    echo "=== $1 ==="
}

usage() {
    cat << EOF
验证 check-quota-status.sh 脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -l, --local         本地验证模式（默认）
  -r, --remote        远程验证模式（需要配置服务器）
  --dry-run           只显示验证步骤，不实际执行

示例:
  $0
  $0 --local
  $0 --remote

EOF
}

verify_script_exists() {
    print_header "1. 检查脚本是否存在"
    if [ -f "${CHECK_SCRIPT}" ]; then
        print_success "脚本存在: ${CHECK_SCRIPT}"
    else
        print_error "脚本不存在"
        return 1
    fi
}

verify_script_permissions() {
    print_header "2. 检查脚本权限"
    if [ -x "${CHECK_SCRIPT}" ]; then
        print_success "脚本可执行"
    else
        print_error "脚本不可执行"
        return 1
    fi
}

verify_script_syntax() {
    print_header "3. 检查脚本语法"
    if bash -n "${CHECK_SCRIPT}"; then
        print_success "脚本语法正确"
    else
        print_error "脚本语法错误"
        return 1
    fi
}

verify_help_output() {
    print_header "4. 检查帮助输出"
    HELP_OUTPUT=$("${CHECK_SCRIPT}" --help 2>&1)
    if echo "${HELP_OUTPUT}" | grep -q "用法:"; then
        print_success "帮助信息输出正常"
        echo "   帮助信息包含: 用法、选项、示例"
    else
        print_error "帮助信息输出异常"
        return 1
    fi
}

verify_basic_functionality() {
    print_header "5. 检查基本功能"
    
    # 测试帮助选项
    if "${CHECK_SCRIPT}" --help > /dev/null 2>&1; then
        print_success "帮助选项工作正常"
    else
        print_error "帮助选项工作异常"
        return 1
    fi
    
    # 测试无效选项
    if ! "${CHECK_SCRIPT}" --invalid-option 2>/dev/null; then
        print_success "无效选项处理正常（返回非零状态）"
    else
        print_error "无效选项处理异常"
        return 1
    fi
}

verify_local_health_check() {
    print_header "6. 本地健康检查测试"
    
    # 启动一个临时的测试服务（如果可能）
    if command -v python3 > /dev/null 2>&1; then
        # 创建一个简单的健康检查端点
        cat > /tmp/test_healthz.py << 'EOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/healthz':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"ok": True, "service": "test"}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # 静默日志

if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 9876), HealthHandler)
    print("测试服务器启动在 127.0.0.1:9876")
    server.serve_forever()
EOF
        
        # 在后台启动测试服务器
        python3 /tmp/test_healthz.py > /dev/null 2>&1 &
        SERVER_PID=$!
        sleep 2
        
        # 测试脚本
        if "${CHECK_SCRIPT}" --url http://127.0.0.1:9876 --skip-db --skip-admin --skip-docker 2>&1 | grep -q "服务健康检查通过"; then
            print_success "本地健康检查功能正常"
        else
            print_error "本地健康检查功能异常"
            kill $SERVER_PID 2>/dev/null || true
            return 1
        fi
        
        # 清理
        kill $SERVER_PID 2>/dev/null || true
        rm -f /tmp/test_healthz.py
    else
        print_success "跳过本地健康检查测试（python3 未安装）"
    fi
}

verify_remote_functionality() {
    print_header "7. 远程验证模式测试"
    
    # 检查服务器配置
    if [ -f "/tmp/server.txt" ]; then
        SERVER_IP=$(grep -o 'ip:[0-9.]*' /tmp/server.txt | cut -d: -f2)
        if [ -n "${SERVER_IP}" ]; then
            print_success "检测到服务器IP: ${SERVER_IP}"
            
            # 测试远程健康检查
            if ssh root@${SERVER_IP} "curl -fsS http://127.0.0.1:8787/healthz" > /dev/null 2>&1; then
                print_success "远程服务器健康检查通过"
                
                # 测试脚本在远程环境
                REMOTE_OUTPUT=$(ssh root@${SERVER_IP} "cd /opt/roc/quota-proxy && ADMIN_TOKEN=\${ADMIN_TOKEN} ./check-quota-status.sh --skip-db --skip-admin 2>&1 || true" 2>/dev/null)
                if echo "${REMOTE_OUTPUT}" | grep -q "服务健康检查通过"; then
                    print_success "远程脚本执行正常"
                else
                    print_warning "远程脚本执行可能有问题（检查输出）"
                    echo "   远程输出: ${REMOTE_OUTPUT:0:200}..."
                fi
            else
                print_error "远程服务器健康检查失败"
            fi
        else
            print_error "无法从 /tmp/server.txt 提取服务器IP"
        fi
    else
        print_success "跳过远程验证（/tmp/server.txt 不存在）"
    fi
}

print_summary() {
    print_header "验证摘要"
    echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "脚本路径: ${CHECK_SCRIPT}"
    echo "脚本大小: $(stat -c%s "${CHECK_SCRIPT}" 2>/dev/null || echo "unknown") bytes"
    echo "脚本权限: $(stat -c%A "${CHECK_SCRIPT}" 2>/dev/null || echo "unknown")"
    echo ""
    echo "使用说明:"
    echo "1. 基本使用: ./scripts/check-quota-status.sh"
    echo "2. 指定服务: ./scripts/check-quota-status.sh --url http://localhost:8787"
    echo "3. 带管理员令牌: ADMIN_TOKEN=your-token ./scripts/check-quota-status.sh"
    echo "4. 跳过检查: ./scripts/check-quota-status.sh --skip-db --skip-admin"
}

# 主验证流程
MODE="local"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -l|--local)
            MODE="local"
            shift
            ;;
        -r|--remote)
            MODE="remote"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "未知选项: $1"
            usage
            exit 1
            ;;
    esac
done

echo "开始验证 check-quota-status.sh 脚本..."
echo "模式: ${MODE}"
echo ""

if [ "${DRY_RUN}" = true ]; then
    echo "=== 验证步骤（干运行）==="
    echo "1. 检查脚本是否存在"
    echo "2. 检查脚本权限"
    echo "3. 检查脚本语法"
    echo "4. 检查帮助输出"
    echo "5. 检查基本功能"
    echo "6. 本地健康检查测试"
    echo "7. 远程验证模式测试"
    echo ""
    echo "实际验证被跳过（--dry-run）"
    exit 0
fi

# 执行验证步骤
ERRORS=0

verify_script_exists || ERRORS=$((ERRORS + 1))
verify_script_permissions || ERRORS=$((ERRORS + 1))
verify_script_syntax || ERRORS=$((ERRORS + 1))
verify_help_output || ERRORS=$((ERRORS + 1))
verify_basic_functionality || ERRORS=$((ERRORS + 1))

if [ "${MODE}" = "local" ]; then
    verify_local_health_check || ERRORS=$((ERRORS + 1))
else
    verify_remote_functionality || ERRORS=$((ERRORS + 1))
fi

echo ""
print_summary

echo ""
if [ ${ERRORS} -eq 0 ]; then
    print_success "所有验证通过！脚本 ready for use."
    exit 0
else
    print_error "验证失败，有 ${ERRORS} 个错误"
    exit 1
fi