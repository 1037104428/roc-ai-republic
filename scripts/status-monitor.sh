#!/bin/bash
# ROC AI Republic 服务状态监控脚本
# 用于生成 status.html 页面，显示各服务健康状态

set -euo pipefail

# 配置
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
OUTPUT_FILE="${OUTPUT_FILE:-/opt/roc/web/site/status.html}"
TEMP_FILE="${TEMP_FILE:-/tmp/roc-status-$$.json}"

# 颜色定义（用于终端输出）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 读取服务器IP
if [[ -f "$SERVER_FILE" ]]; then
    SERVER_IP=$(head -n1 "$SERVER_FILE" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "")
else
    SERVER_IP=""
fi

# 初始化状态对象
declare -A STATUS

# 检查主站点
check_site() {
    echo "检查主站点..."
    if curl -fsS -m 10 "https://clawdrepublic.cn/" >/dev/null 2>&1; then
        STATUS["site"]="healthy"
        STATUS["site_message"]="主站点可访问"
    else
        STATUS["site"]="unhealthy"
        STATUS["site_message"]="主站点不可访问"
    fi
}

# 检查API网关
check_api() {
    echo "检查API网关..."
    local response
    if response=$(curl -fsS -m 10 "https://api.clawdrepublic.cn/healthz" 2>/dev/null); then
        if echo "$response" | grep -q '"ok":true'; then
            STATUS["api"]="healthy"
            STATUS["api_message"]="API网关健康"
        else
            STATUS["api"]="degraded"
            STATUS["api_message"]="API网关响应异常"
        fi
    else
        STATUS["api"]="unhealthy"
        STATUS["api_message"]="API网关不可访问"
    fi
}

# 检查quota-proxy（需要服务器IP）
check_quota_proxy() {
    if [[ -z "$SERVER_IP" ]]; then
        STATUS["quota_proxy"]="unknown"
        STATUS["quota_proxy_message"]="未配置服务器IP"
        return
    fi
    
    echo "检查quota-proxy..."
    local ssh_key="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
    
    # 检查Docker容器状态
    if ssh -i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=10 "root@$SERVER_IP" \
        'cd /opt/roc/quota-proxy && docker compose ps --format json 2>/dev/null || docker compose ps 2>/dev/null' >/dev/null 2>&1; then
        
        # 检查健康端点
        if ssh -i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=10 "root@$SERVER_IP" \
            'curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null | grep -q "ok" && echo "healthy"' | grep -q "healthy"; then
            
            STATUS["quota_proxy"]="healthy"
            STATUS["quota_proxy_message"]="quota-proxy运行正常"
        else
            STATUS["quota_proxy"]="degraded"
            STATUS["quota_proxy_message"]="quota-proxy容器运行但健康检查失败"
        fi
    else
        STATUS["quota_proxy"]="unhealthy"
        STATUS["quota_proxy_message"]="quota-proxy容器未运行"
    fi
}

# 检查论坛
check_forum() {
    echo "检查论坛..."
    if curl -fsS -m 10 "https://clawdrepublic.cn/forum/" >/dev/null 2>&1; then
        STATUS["forum"]="healthy"
        STATUS["forum_message"]="论坛可访问"
    else
        STATUS["forum"]="unhealthy"
        STATUS["forum_message"]="论坛不可访问"
    fi
}

# 生成HTML状态页面
generate_html() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    
    cat > "$OUTPUT_FILE" << EOF
<!doctype html>
<html lang="zh">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Clawd 国度 - 服务状态</title>
  <meta name="description" content="Clawd 国度服务状态监控" />
  <style>
    body {
      max-width: 800px;
      margin: 40px auto;
      font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial;
      line-height: 1.6;
      padding: 0 16px;
    }
    h1 { margin-bottom: 8px; }
    .timestamp { color: #666; font-size: 14px; margin-bottom: 24px; }
    .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; }
    .status-card {
      border: 1px solid #e0e0e0;
      border-radius: 12px;
      padding: 16px;
      background: #fafafa;
    }
    .status-card.healthy { border-left: 4px solid #2ecc71; }
    .status-card.degraded { border-left: 4px solid #f39c12; }
    .status-card.unhealthy { border-left: 4px solid #e74c3c; }
    .status-card.unknown { border-left: 4px solid #95a5a6; }
    .status-title { font-weight: bold; margin-bottom: 8px; font-size: 18px; }
    .status-message { margin-bottom: 8px; }
    .status-indicator {
      display: inline-block;
      width: 12px;
      height: 12px;
      border-radius: 50%;
      margin-right: 8px;
    }
    .healthy .status-indicator { background: #2ecc71; }
    .degraded .status-indicator { background: #f39c12; }
    .unhealthy .status-indicator { background: #e74c3c; }
    .unknown .status-indicator { background: #95a5a6; }
    .actions { margin-top: 24px; }
    .btn {
      display: inline-block;
      background: #111;
      color: #fff;
      padding: 8px 16px;
      border-radius: 8px;
      text-decoration: none;
      margin-right: 8px;
    }
    .btn:hover { opacity: 0.9; }
    .refresh-btn {
      background: #3498db;
      border: none;
      color: white;
      padding: 8px 16px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 14px;
    }
    .refresh-btn:hover { background: #2980b9; }
    .legend {
      margin-top: 24px;
      padding: 12px;
      background: #f8f9fa;
      border-radius: 8px;
      font-size: 14px;
    }
    .legend-item { display: inline-block; margin-right: 16px; }
  </style>
</head>
<body>
  <h1>Clawd 国度 - 服务状态</h1>
  <div class="timestamp">最后更新: $timestamp</div>
  
  <div class="status-grid">
    <div class="status-card ${STATUS["site"]}">
      <div class="status-title">
        <span class="status-indicator"></span>
        主站点 (clawdrepublic.cn)
      </div>
      <div class="status-message">${STATUS["site_message"]}</div>
      <div class="small">HTTPS 静态站点</div>
    </div>
    
    <div class="status-card ${STATUS["api"]}">
      <div class="status-title">
        <span class="status-indicator"></span>
        API 网关 (api.clawdrepublic.cn)
      </div>
      <div class="status-message">${STATUS["api_message"]}</div>
      <div class="small">OpenAI 兼容接口</div>
    </div>
    
    <div class="status-card ${STATUS["quota_proxy"]}">
      <div class="status-title">
        <span class="status-indicator"></span>
        Quota Proxy 服务
      </div>
      <div class="status-message">${STATUS["quota_proxy_message"]}</div>
      <div class="small">TRIAL_KEY 管理与限额控制</div>
    </div>
    
    <div class="status-card ${STATUS["forum"]}">
      <div class="status-title">
        <span class="status-indicator"></span>
        论坛 (forum.clawdrepublic.cn)
      </div>
      <div class="status-message">${STATUS["forum_message"]}</div>
      <div class="small">社区交流与知识沉淀</div>
    </div>
  </div>
  
  <div class="legend">
    <strong>状态说明:</strong>
    <div class="legend-item"><span style="color:#2ecc71">●</span> 健康 - 服务正常</div>
    <div class="legend-item"><span style="color:#f39c12">●</span> 降级 - 部分功能异常</div>
    <div class="legend-item"><span style="color:#e74c3c">●</span> 故障 - 服务不可用</div>
    <div class="legend-item"><span style="color:#95a5a6">●</span> 未知 - 无法检测</div>
  </div>
  
  <div class="actions">
    <a class="btn" href="/">返回首页</a>
    <a class="btn" href="/quickstart.html">小白一条龙</a>
    <a class="btn" href="/quota-proxy.html">TRIAL_KEY 说明</a>
    <button class="refresh-btn" onclick="location.reload()">刷新状态</button>
  </div>
  
  <script>
    // 自动刷新（每5分钟）
    setTimeout(function() {
      location.reload();
    }, 5 * 60 * 1000);
    
    // 添加键盘快捷键：按 R 刷新
    document.addEventListener('keydown', function(e) {
      if (e.key === 'r' || e.key === 'R') {
        location.reload();
      }
    });
  </script>
</body>
</html>
EOF
    
    echo "状态页面已生成: $OUTPUT_FILE"
    
    # 同时复制到旧路径保持兼容性
    if [[ "$OUTPUT_FILE" != "/opt/roc/web/status.html" ]]; then
        cp "$OUTPUT_FILE" "/opt/roc/web/status.html" 2>/dev/null || true
        echo "兼容性副本: /opt/roc/web/status.html"
    fi
}

# 主函数
main() {
    echo "=== Clawd 国度服务状态检查 ==="
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
    
    # 执行检查
    check_site
    check_api
    check_quota_proxy
    check_forum
    
    # 输出终端状态
    echo ""
    echo "=== 检查结果 ==="
    for service in site api quota_proxy forum; do
        local status="${STATUS["$service"]}"
        local message="${STATUS["${service}_message"]}"
        
        case "$status" in
            healthy) color="$GREEN" ;;
            degraded) color="$YELLOW" ;;
            unhealthy) color="$RED" ;;
            *) color="$NC" ;;
        esac
        
        printf "%-15s: ${color}%-10s${NC} %s\n" "$service" "$status" "$message"
    done
    
    # 生成HTML页面
    generate_html
    
    # 输出JSON格式（用于脚本处理）
    if [[ -n "${TEMP_FILE}" ]]; then
        cat > "$TEMP_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "services": {
    "site": {
      "status": "${STATUS["site"]}",
      "message": "${STATUS["site_message"]}"
    },
    "api": {
      "status": "${STATUS["api"]}",
      "message": "${STATUS["api_message"]}"
    },
    "quota_proxy": {
      "status": "${STATUS["quota_proxy"]}",
      "message": "${STATUS["quota_proxy_message"]}"
    },
    "forum": {
      "status": "${STATUS["forum"]}",
      "message": "${STATUS["forum_message"]}"
    }
  }
}
EOF
        echo "JSON 状态已保存: $TEMP_FILE"
    fi
    
    echo ""
    echo "状态页面: file://$OUTPUT_FILE"
    echo "在线访问: https://clawdrepublic.cn/status.html"
    echo "兼容性页面: file:///opt/roc/web/status.html"
}

# 执行主函数
main "$@"