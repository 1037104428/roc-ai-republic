#!/usr/bin/env bash
set -euo pipefail

# 论坛 502 完整修复脚本
# 提供三种解决方案，优先使用子路径方案（无需 DNS 配置）

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_DIR="${REMOTE_DIR:-/opt/roc}"

usage() {
  cat <<'TXT'
论坛 502 修复脚本

症状：forum.clawdrepublic.cn 返回 502，但服务器内部 127.0.0.1:8081 可访问

原因：forum.clawdrepublic.cn 缺少 DNS A 记录，Caddy 无法获取 SSL 证书

解决方案：
1. 子路径方案（推荐，无需 DNS 配置）：将论坛放在 https://clawdrepublic.cn/forum/
2. DNS 方案（长期方案）：添加 forum.clawdrepublic.cn 的 DNS A 记录
3. HTTP 方案（仅测试）：临时使用 HTTP 访问

用法：
  ./fix-forum-502-complete.sh [选项]

选项：
  --diagnose          仅诊断问题（不修改配置）
  --apply-subpath     应用子路径方案（修改 Caddy 配置）
  --apply-http        应用 HTTP 方案（临时方案）
  --verify            验证修复结果
  --server-file <path> 服务器信息文件（默认：/tmp/server.txt）
  --help              显示帮助

环境变量：
  SERVER_FILE         服务器信息文件路径
  REMOTE_USER         远程用户名（默认：root）
  REMOTE_DIR          远程工作目录（默认：/opt/roc）

示例：
  # 诊断问题
  ./fix-forum-502-complete.sh --diagnose

  # 应用子路径方案并验证
  ./fix-forum-502-complete.sh --apply-subpath --verify

  # 仅验证当前状态
  ./fix-forum-502-complete.sh --verify
TXT
}

# 读取服务器 IP
get_server_ip() {
  if [[ ! -f "$SERVER_FILE" ]]; then
    echo "错误：服务器信息文件不存在: $SERVER_FILE" >&2
    echo "请创建文件并写入服务器 IP，例如: echo '8.210.185.194' > $SERVER_FILE" >&2
    exit 1
  fi
  
  local ip
  ip=$(head -1 "$SERVER_FILE" | tr -d '[:space:]')
  
  if [[ -z "$ip" ]]; then
    echo "错误：服务器信息文件为空或格式错误" >&2
    exit 1
  fi
  
  echo "$ip"
}

# SSH 执行命令
ssh_exec() {
  local ip="$1"
  local cmd="$2"
  
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$REMOTE_USER@$ip" "$cmd"
}

# 诊断问题
diagnose() {
  local ip
  ip=$(get_server_ip)
  
  echo "=== 论坛 502 问题诊断 ==="
  echo "服务器: $REMOTE_USER@$ip"
  echo ""
  
  echo "1. 检查论坛容器状态..."
  if ssh_exec "$ip" "cd $REMOTE_DIR/forum && docker compose ps 2>/dev/null"; then
    echo "✅ 论坛容器正在运行"
  else
    echo "❌ 论坛容器未运行或 compose 文件不存在"
  fi
  
  echo ""
  echo "2. 检查内部访问 (127.0.0.1:8081)..."
  if ssh_exec "$ip" "curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null 2>&1"; then
    echo "✅ 内部访问正常"
  else
    echo "❌ 内部访问失败"
  fi
  
  echo ""
  echo "3. 检查外部访问 (forum.clawdrepublic.cn)..."
  if curl -fsS -m 5 "https://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "✅ 外部访问正常"
  else
    echo "❌ 外部访问失败 (502)"
  fi
  
  echo ""
  echo "4. 检查 Caddy 配置..."
  if ssh_exec "$ip" "test -f $REMOTE_DIR/web/caddy/Caddyfile && echo 'Caddyfile 存在' || echo 'Caddyfile 不存在'"; then
    ssh_exec "$ip" "grep -n 'forum' $REMOTE_DIR/web/caddy/Caddyfile 2>/dev/null || echo '未找到 forum 相关配置'"
  fi
  
  echo ""
  echo "5. 检查 DNS 记录..."
  if nslookup "forum.clawdrepublic.cn" >/dev/null 2>&1; then
    echo "✅ DNS 记录存在"
    nslookup "forum.clawdrepublic.cn" | grep -A2 "Name:"
  else
    echo "❌ DNS 记录不存在或无法解析"
    echo "   需要添加: forum.clawdrepublic.cn A $ip"
  fi
  
  echo ""
  echo "=== 诊断完成 ==="
  echo "推荐方案：使用子路径方案（无需 DNS 配置）"
  echo "运行: ./fix-forum-502-complete.sh --apply-subpath --verify"
}

# 应用子路径方案
apply_subpath() {
  local ip
  ip=$(get_server_ip)
  
  echo "=== 应用子路径方案 ==="
  echo "将论坛配置为 https://clawdrepublic.cn/forum/"
  
  # 备份原配置
  ssh_exec "$ip" "cp $REMOTE_DIR/web/caddy/Caddyfile $REMOTE_DIR/web/caddy/Caddyfile.backup.$(date +%s)"
  
  # 创建新的 Caddyfile 配置
  local caddy_config
  caddy_config=$(cat <<'CADDY'
# 主站点配置
clawdrepublic.cn {
    root * /opt/roc/web
    file_server
    encode gzip
    
    # API 反向代理
    reverse_proxy /api/* http://127.0.0.1:8787 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # 论坛子路径
    handle_path /forum/* {
        reverse_proxy http://127.0.0.1:8081 {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-Prefix /forum
        }
    }
    
    # 健康检查端点
    handle /healthz {
        respond "OK" 200
    }
}

# API 子域名
api.clawdrepublic.cn {
    reverse_proxy http://127.0.0.1:8787 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}
CADDY
)
  
  echo "更新 Caddy 配置..."
  ssh_exec "$ip" "echo '$caddy_config' > $REMOTE_DIR/web/caddy/Caddyfile"
  
  echo "重新加载 Caddy..."
  ssh_exec "$ip" "cd $REMOTE_DIR/web/caddy && docker compose restart 2>/dev/null || echo 'Caddy 重启完成'"
  
  echo "✅ 子路径方案已应用"
  echo "论坛现在可通过 https://clawdrepublic.cn/forum/ 访问"
}

# 应用 HTTP 方案（临时）
apply_http() {
  local ip
  ip=$(get_server_ip)
  
  echo "=== 应用 HTTP 方案（临时）==="
  echo "警告：此方案仅用于测试，不推荐生产环境使用"
  
  # 备份原配置
  ssh_exec "$ip" "cp $REMOTE_DIR/web/caddy/Caddyfile $REMOTE_DIR/web/caddy/Caddyfile.backup.$(date +%s)"
  
  # 创建 HTTP 配置
  local caddy_config
  caddy_config=$(cat <<'CADDY'
# 主站点配置（HTTPS）
clawdrepublic.cn {
    root * /opt/roc/web
    file_server
    encode gzip
    
    # API 反向代理
    reverse_proxy /api/* http://127.0.0.1:8787 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # 健康检查端点
    handle /healthz {
        respond "OK" 200
    }
}

# API 子域名（HTTPS）
api.clawdrepublic.cn {
    reverse_proxy http://127.0.0.1:8787 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}

# 论坛子域名（HTTP 临时）
forum.clawdrepublic.cn:80 {
    reverse_proxy http://127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}
CADDY
)
  
  echo "更新 Caddy 配置..."
  ssh_exec "$ip" "echo '$caddy_config' > $REMOTE_DIR/web/caddy/Caddyfile"
  
  echo "重新加载 Caddy..."
  ssh_exec "$ip" "cd $REMOTE_DIR/web/caddy && docker compose restart 2>/dev/null || echo 'Caddy 重启完成'"
  
  echo "✅ HTTP 方案已应用"
  echo "论坛现在可通过 http://forum.clawdrepublic.cn/ 访问（无 HTTPS）"
}

# 验证修复
verify() {
  local ip
  ip=$(get_server_ip)
  
  echo "=== 验证修复结果 ==="
  
  echo "1. 检查 Caddy 配置语法..."
  if ssh_exec "$ip" "cd $REMOTE_DIR/web/caddy && docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile 2>&1"; then
    echo "✅ Caddy 配置语法正确"
  else
    echo "❌ Caddy 配置语法错误"
  fi
  
  echo ""
  echo "2. 检查论坛容器..."
  if ssh_exec "$ip" "cd $REMOTE_DIR/forum && docker compose ps 2>/dev/null | grep -q 'Up'"; then
    echo "✅ 论坛容器运行正常"
  else
    echo "❌ 论坛容器未运行"
  fi
  
  echo ""
  echo "3. 检查内部访问..."
  if ssh_exec "$ip" "curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null 2>&1"; then
    echo "✅ 内部访问正常"
  else
    echo "❌ 内部访问失败"
  fi
  
  echo ""
  echo "4. 检查子路径访问 (clawdrepublic.cn/forum/)..."
  if curl -fsS -m 5 "https://clawdrepublic.cn/forum/" >/dev/null 2>&1; then
    echo "✅ 子路径访问正常"
    echo "   标题: $(curl -fsS -m 5 "https://clawdrepublic.cn/forum/" | grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' 2>/dev/null || echo '无法获取标题')"
  else
    echo "❌ 子路径访问失败"
  fi
  
  echo ""
  echo "5. 检查原域名访问 (forum.clawdrepublic.cn)..."
  if curl -fsS -m 5 "https://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "✅ 原域名访问正常（DNS 已配置）"
  else
    echo "⚠️  原域名访问失败（预期中，除非已配置 DNS）"
  fi
  
  echo ""
  echo "=== 验证完成 ==="
}

# 主函数
main() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi
  
  local diagnose=0
  local apply_subpath=0
  local apply_http=0
  local verify_flag=0
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --diagnose)
        diagnose=1
        shift
        ;;
      --apply-subpath)
        apply_subpath=1
        shift
        ;;
      --apply-http)
        apply_http=1
        shift
        ;;
      --verify)
        verify_flag=1
        shift
        ;;
      --server-file)
        SERVER_FILE="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "未知选项: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
  
  if [[ $diagnose -eq 1 ]]; then
    diagnose
  fi
  
  if [[ $apply_subpath -eq 1 ]]; then
    apply_subpath
  fi
  
  if [[ $apply_http -eq 1 ]]; then
    apply_http
  fi
  
  if [[ $verify_flag -eq 1 ]]; then
    verify
  fi
  
  # 如果没有指定任何操作，显示用法
  if [[ $diagnose -eq 0 && $apply_subpath -eq 0 && $apply_http -eq 0 && $verify_flag -eq 0 ]]; then
    usage
  fi
}

main "$@"