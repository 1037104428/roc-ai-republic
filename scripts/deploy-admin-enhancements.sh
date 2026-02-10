#!/bin/bash
# 部署 quota-proxy 管理接口增强功能
# 包括：综合测试脚本、文档更新、配置检查

set -e

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== 部署 quota-proxy 管理接口增强功能 ==="
echo "仓库根目录: $REPO_ROOT"
echo

# 1. 检查服务器配置
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "错误: 服务器配置文件不存在: $SERVER_FILE"
    echo "请创建文件并写入服务器IP，例如:"
    echo "  echo '8.210.185.194' > $SERVER_FILE"
    exit 1
fi

SERVER_IP=$(head -1 "$SERVER_FILE" | tr -d '[:space:]')
if [[ -z "$SERVER_IP" ]]; then
    echo "错误: 服务器IP为空"
    exit 1
fi

echo "目标服务器: $SERVER_IP"
echo

# 2. 本地验证脚本
echo "2. 本地验证脚本..."
cd "$REPO_ROOT"

# 检查脚本语法
bash -n scripts/test-admin-comprehensive.sh && echo "✓ test-admin-comprehensive.sh 语法检查通过"

# 检查依赖
if ! command -v jq &> /dev/null; then
    echo "⚠ 警告: jq 命令未安装，测试脚本需要 jq 解析 JSON"
    echo "  安装: sudo apt-get install jq 或 brew install jq"
fi

echo

# 3. 更新文档
echo "3. 更新文档..."
DOCS_UPDATED=false

# 检查是否已记录测试脚本
if ! grep -q "test-admin-comprehensive.sh" docs/verify.md 2>/dev/null; then
    echo "在 docs/verify.md 中添加测试脚本说明..."
    cat >> docs/verify.md << 'DOC_EOF'

### 管理接口综合测试

使用 `test-admin-comprehensive.sh` 进行端到端管理功能测试：

```bash
# 设置管理员令牌
export ADMIN_TOKEN="your-admin-token-here"

# 运行综合测试（本地 quota-proxy）
./scripts/test-admin-comprehensive.sh

# 远程服务器测试
./scripts/test-admin-comprehensive.sh --host http://127.0.0.1:8787
```

测试包括：
1. 健康检查
2. 密钥列表
3. 密钥创建
4. 密钥验证
5. 使用情况查询
6. 密钥删除
7. 验证删除
DOC_EOF
    DOCS_UPDATED=true
    echo "✓ 文档更新完成"
else
    echo "✓ 文档已包含测试脚本说明"
fi

echo

# 4. 服务器端验证（可选）
echo "4. 服务器端验证..."
read -p "是否要验证服务器上的 quota-proxy 管理接口？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "连接到服务器 $SERVER_IP..."
    
    # 检查服务器上的 quota-proxy 状态
    if ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "cd /opt/roc/quota-proxy && docker compose ps" 2>/dev/null | grep -q "quota-proxy"; then
        echo "✓ 服务器上 quota-proxy 正在运行"
        
        # 获取管理员令牌
        ADMIN_TOKEN_REMOTE=$(ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "grep ADMIN_TOKEN /opt/roc/quota-proxy/.env 2>/dev/null | cut -d= -f2" || echo "")
        if [[ -n "$ADMIN_TOKEN_REMOTE" ]]; then
            echo "✓ 获取到管理员令牌"
            echo "令牌: ${ADMIN_TOKEN_REMOTE:0:10}..."
            
            # 测试健康检查
            echo "测试健康检查..."
            HEALTH_CHECK=$(ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "curl -s http://127.0.0.1:8787/healthz")
            if echo "$HEALTH_CHECK" | grep -q '"ok":true'; then
                echo "✓ 服务器健康检查通过"
            else
                echo "⚠ 服务器健康检查失败: $HEALTH_CHECK"
            fi
        else
            echo "⚠ 无法获取管理员令牌"
        fi
    else
        echo "⚠ 服务器上未找到运行的 quota-proxy"
    fi
fi

echo

# 5. 生成部署报告
echo "5. 生成部署报告..."
REPORT_FILE="/tmp/quota-proxy-admin-deploy-$(date +%Y%m%d-%H%M%S).txt"
{
    echo "quota-proxy 管理接口增强部署报告"
    echo "生成时间: $(date)"
    echo "服务器: $SERVER_IP"
    echo "仓库版本: $(git rev-parse --short HEAD 2>/dev/null || echo '未知')"
    echo
    echo "新增文件:"
    echo "  - scripts/test-admin-comprehensive.sh (综合测试脚本)"
    echo
    echo "更新的文档:"
    echo "  - docs/verify.md (添加测试脚本说明)"
    echo
    echo "验证命令:"
    echo "  # 本地测试"
    echo "  ./scripts/test-admin-comprehensive.sh --host http://127.0.0.1:8787 --token YOUR_TOKEN"
    echo
    echo "  # 服务器验证"
    echo "  ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'"
} > "$REPORT_FILE"

echo "✓ 部署报告已生成: $REPORT_FILE"
echo
echo "=== 部署完成 ==="
echo
echo "下一步:"
echo "1. 提交更改到仓库:"
echo "   git add scripts/test-admin-comprehensive.sh docs/verify.md"
echo "   git commit -m 'feat: 新增 quota-proxy 管理接口综合测试脚本与文档'"
echo "   git push"
echo
echo "2. 运行测试验证:"
echo "   export ADMIN_TOKEN=your_token"
echo "   ./scripts/test-admin-comprehensive.sh --host http://127.0.0.1:8787"
echo
echo "3. 更新服务器（如需）:"
echo "   ./scripts/deploy-quota-proxy-sqlite.sh --server $SERVER_IP"