#!/usr/bin/env bash
set -euo pipefail

# 检查 quota-proxy 响应时间脚本
# 用于监控 API 网关的性能和可用性

readonly SCRIPT_NAME="check-quota-proxy-response-time.sh"
readonly VERSION="1.0.0"

show_help() {
    cat <<EOF
${SCRIPT_NAME} - 检查 quota-proxy API 网关的响应时间

用法:
  ${SCRIPT_NAME} [选项]

选项:
  -h, --help          显示此帮助信息
  -v, --version       显示版本信息
  -s, --server <IP>   指定服务器IP（默认从 /tmp/server.txt 读取）
  -p, --port <PORT>   指定端口（默认: 8787）
  -t, --timeout <秒>  超时时间（默认: 5秒）
  -k, --key <KEY>     使用 TRIAL_KEY 测试（可选）
  --admin-token <TOKEN> 管理员令牌（用于 /admin/keys 端点）

示例:
  ${SCRIPT_NAME}                    # 基本健康检查
  ${SCRIPT_NAME} -s 8.210.185.194   # 指定服务器
  ${SCRIPT_NAME} -k abc123          # 使用 TRIAL_KEY 测试
  ${SCRIPT_NAME} --admin-token secret # 测试管理员端点

EOF
}

show_version() {
    echo "${SCRIPT_NAME} v${VERSION}"
}

main() {
    local server_ip=""
    local port="8787"
    local timeout=5
    local trial_key=""
    local admin_token=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                return 0
                ;;
            -v|--version)
                show_version
                return 0
                ;;
            -s|--server)
                server_ip="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            -k|--key)
                trial_key="$2"
                shift 2
                ;;
            --admin-token)
                admin_token="$2"
                shift 2
                ;;
            *)
                echo "错误: 未知选项 '$1'" >&2
                show_help >&2
                return 1
                ;;
        esac
    done
    
    # 获取服务器IP
    if [[ -z "$server_ip" ]]; then
        if [[ -f "/tmp/server.txt" ]]; then
            server_ip=$(grep -oP 'ip=\K[0-9.]+' /tmp/server.txt || echo "")
        fi
        
        if [[ -z "$server_ip" ]]; then
            echo "错误: 未指定服务器IP且 /tmp/server.txt 中未找到" >&2
            return 1
        fi
    fi
    
    echo "=== quota-proxy 响应时间检查 ==="
    echo "服务器: ${server_ip}:${port}"
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 测试健康检查端点
    echo "1. 健康检查端点 (/healthz):"
    local healthz_start
    local healthz_end
    local healthz_duration
    
    healthz_start=$(date +%s%N)
    if curl -fsS -m "$timeout" "http://${server_ip}:${port}/healthz" >/dev/null 2>&1; then
        healthz_end=$(date +%s%N)
        healthz_duration=$(( (healthz_end - healthz_start) / 1000000 ))
        echo "   ✓ 成功 - 响应时间: ${healthz_duration}ms"
    else
        echo "   ✗ 失败 - 端点不可用或超时"
        return 1
    fi
    
    # 测试验证端点（如果提供了TRIAL_KEY）
    if [[ -n "$trial_key" ]]; then
        echo ""
        echo "2. 验证端点 (/verify):"
        local verify_start
        local verify_end
        local verify_duration
        
        verify_start=$(date +%s%N)
        if curl -fsS -m "$timeout" \
            -H "Authorization: Bearer ${trial_key}" \
            "http://${server_ip}:${port}/verify" >/dev/null 2>&1; then
            verify_end=$(date +%s%N)
            verify_duration=$(( (verify_end - verify_start) / 1000000 ))
            echo "   ✓ 成功 - 响应时间: ${verify_duration}ms"
        else
            echo "   ✗ 失败 - 验证失败或超时"
        fi
    fi
    
    # 测试管理员端点（如果提供了管理员令牌）
    if [[ -n "$admin_token" ]]; then
        echo ""
        echo "3. 管理员端点 (/admin/keys):"
        local admin_start
        local admin_end
        local admin_duration
        
        admin_start=$(date +%s%N)
        if curl -fsS -m "$timeout" \
            -H "X-Admin-Token: ${admin_token}" \
            "http://${server_ip}:${port}/admin/keys" >/dev/null 2>&1; then
            admin_end=$(date +%s%N)
            admin_duration=$(( (admin_end - admin_start) / 1000000 ))
            echo "   ✓ 成功 - 响应时间: ${admin_duration}ms"
        else
            echo "   ✗ 失败 - 管理员端点不可用或令牌无效"
        fi
    fi
    
    echo ""
    echo "=== 检查完成 ==="
    echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "建议:"
    echo "  - 正常响应时间应 < 100ms"
    echo "  - 100-500ms 为警告范围"
    echo "  - > 500ms 需要调查"
    echo "  - 可结合 cron 定期监控"
}

# 仅当直接执行时运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi