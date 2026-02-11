#!/bin/bash

# 环境变量验证功能测试脚本
# 测试 load-env.cjs 中的 validateEnv 功能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 测试函数
test_env_validation() {
    print_info "测试环境变量验证功能..."
    
    # 创建测试环境变量文件
    cat > test-env-validation.env << 'EOF'
# 测试环境变量文件
PORT=8787
HOST=127.0.0.1
ADMIN_TOKEN=test-admin-token-123
DB_PATH=:memory:
LOG_LEVEL=debug
EOF
    
    # 测试1: 验证必需环境变量
    print_info "测试1: 验证必需环境变量..."
    node -e "
    const { validateEnv } = require('./load-env.cjs');
    process.env.ADMIN_TOKEN = 'test-token';
    process.env.PORT = '8787';
    
    const result1 = validateEnv(['ADMIN_TOKEN', 'PORT']);
    console.log('验证结果1:', JSON.stringify(result1, null, 2));
    
    if (result1.valid && result1.missing.length === 0) {
        console.log('✅ 测试1通过: 所有必需变量都存在');
    } else {
        console.error('❌ 测试1失败: 缺少变量', result1.missing);
        process.exit(1);
    }
    "
    
    # 测试2: 验证缺少必需环境变量
    print_info "测试2: 验证缺少必需环境变量..."
    node -e "
    const { validateEnv } = require('./load-env.cjs');
    delete process.env.ADMIN_TOKEN;
    process.env.PORT = '8787';
    
    const result2 = validateEnv(['ADMIN_TOKEN', 'PORT', 'NON_EXISTENT']);
    console.log('验证结果2:', JSON.stringify(result2, null, 2));
    
    if (!result2.valid && result2.missing.includes('ADMIN_TOKEN') && result2.missing.includes('NON_EXISTENT')) {
        console.log('✅ 测试2通过: 正确检测到缺少的变量');
    } else {
        console.error('❌ 测试2失败: 验证结果不正确');
        process.exit(1);
    }
    "
    
    # 测试3: 验证空值环境变量
    print_info "测试3: 验证空值环境变量..."
    node -e "
    const { validateEnv } = require('./load-env.cjs');
    process.env.EMPTY_VAR = '';
    process.env.WHITESPACE_VAR = '   ';
    
    const result3 = validateEnv(['EMPTY_VAR', 'WHITESPACE_VAR']);
    console.log('验证结果3:', JSON.stringify(result3, null, 2));
    
    if (!result3.valid && result3.missing.includes('EMPTY_VAR') && result3.missing.includes('WHITESPACE_VAR')) {
        console.log('✅ 测试3通过: 正确检测到空值变量');
    } else {
        console.error('❌ 测试3失败: 空值变量验证不正确');
        process.exit(1);
    }
    "
    
    # 测试4: 集成测试 - 加载环境变量后验证
    print_info "测试4: 集成测试 - 加载环境变量后验证..."
    node -e "
    const { loadEnv, validateEnv } = require('./load-env.cjs');
    
    // 清除测试环境变量
    delete process.env.ADMIN_TOKEN;
    delete process.env.PORT;
    
    // 加载测试环境变量文件
    const loaded = loadEnv('test-env-validation.env');
    console.log('环境变量加载结果:', loaded);
    
    if (loaded) {
        const result4 = validateEnv(['ADMIN_TOKEN', 'PORT']);
        console.log('验证结果4:', JSON.stringify(result4, null, 2));
        
        if (result4.valid && result4.missing.length === 0) {
            console.log('✅ 测试4通过: 环境变量加载和验证成功');
        } else {
            console.error('❌ 测试4失败: 加载后验证失败', result4.missing);
            process.exit(1);
        }
    } else {
        console.error('❌ 测试4失败: 环境变量加载失败');
        process.exit(1);
    }
    "
    
    # 清理测试文件
    rm -f test-env-validation.env
    
    print_success "所有环境变量验证测试通过！"
}

# 测试服务器集成
test_server_integration() {
    print_info "测试服务器集成..."
    
    # 创建测试环境变量文件
    cat > .env.test-validation << 'EOF'
PORT=9999
HOST=127.0.0.1
ADMIN_TOKEN=integration-test-token
DB_PATH=:memory:
LOG_LEVEL=debug
EOF
    
    # 测试服务器启动（快速检查）
    print_info "快速检查服务器语法和集成..."
    if node -c server-sqlite.js; then
        print_success "服务器语法检查通过"
    else
        print_error "服务器语法检查失败"
        rm -f .env.test-validation
        exit 1
    fi
    
    # 检查服务器是否包含验证逻辑
    if grep -q "validateEnv" server-sqlite.js; then
        print_success "服务器包含环境变量验证逻辑"
    else
        print_error "服务器缺少环境变量验证逻辑"
        rm -f .env.test-validation
        exit 1
    fi
    
    # 清理
    rm -f .env.test-validation
    
    print_success "服务器集成测试通过！"
}

# 主测试流程
main() {
    print_info "开始环境变量验证功能测试..."
    print_info "当前目录: $(pwd)"
    
    # 检查必需文件
    if [ ! -f "load-env.cjs" ]; then
        print_error "缺少 load-env.cjs 文件"
        exit 1
    fi
    
    if [ ! -f "server-sqlite.js" ]; then
        print_error "缺少 server-sqlite.js 文件"
        exit 1
    fi
    
    # 运行测试
    test_env_validation
    test_server_integration
    
    print_success "✅ 环境变量验证功能测试全部完成！"
    print_info "📋 测试总结:"
    print_info "  - 环境变量验证功能正常工作"
    print_info "  - 服务器集成验证通过"
    print_info "  - 支持必需变量检查、空值检测、集成验证"
}

# 处理命令行参数
case "${1:-}" in
    --help|-h)
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  --help, -h    显示帮助信息"
        echo "  --dry-run     模拟运行，不执行实际测试"
        echo "  --quick       快速测试（仅语法检查）"
        exit 0
        ;;
    --dry-run)
        print_info "模拟运行模式..."
        print_info "将测试以下功能:"
        print_info "  1. 环境变量验证功能测试"
        print_info "  2. 服务器集成测试"
        print_info "测试文件: load-env.cjs, server-sqlite.js"
        exit 0
        ;;
    --quick)
        print_info "快速测试模式..."
        if node -c load-env.cjs && node -c server-sqlite.js; then
            print_success "语法检查通过"
        else
            print_error "语法检查失败"
            exit 1
        fi
        exit 0
        ;;
    *)
        main
        ;;
esac