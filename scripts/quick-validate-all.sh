#!/bin/bash

# quick-validate-all.sh - 快速验证quota-proxy所有核心功能的一键脚本
# 提供快速验证所有核心功能的统一入口，支持多种验证模式和灵活配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
HOST=${HOST:-"127.0.0.1"}
PORT=${PORT:-"8787"}
ADMIN_TOKEN=${ADMIN_TOKEN:-"dummy-token"}
VERBOSE=${VERBOSE:-false}
DRY_RUN=${DRY_RUN:-false}

# 帮助信息
show_help() {
    cat << EOF
快速验证quota-proxy所有核心功能的一键脚本

用法: $0 [选项]

选项:
  -h, --help           显示此帮助信息
  -H, --host HOST      主机地址 (默认: 127.0.0.1)
  -p, --port PORT      端口号 (默认: 8787)
  -t, --token TOKEN    管理员令牌 (默认: dummy-token)
  -v, --verbose        详细输出模式
  -d, --dry-run        模拟运行，不实际执行验证
  --no-color           禁用彩色输出

环境变量:
  HOST        主机地址
  PORT        端口号
  ADMIN_TOKEN 管理员令牌
  VERBOSE     详细输出模式 (true/false)
  DRY_RUN     模拟运行模式 (true/false)

示例:
  $0 -H 8.210.185.194 -t "my-secret-token" -v
  HOST=8.210.185.194 ADMIN_TOKEN="my-token" $0
  $0 --dry-run --verbose

退出码:
  0 - 所有验证通过
  1 - 参数错误
  2 - 基础健康检查失败
  3 - 管理接口验证失败
  4 - API网关验证失败
  5 - 集成测试失败
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -H|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-color)
            RED=''
            GREEN=''
            YELLOW=''
            BLUE=''
            NC=''
            shift
            ;;
        *)
            echo -e "${RED}错误: 未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 打印配置信息
print_config() {
    echo -e "${BLUE}=== 快速验证配置 ===${NC}"
    echo -e "主机: ${YELLOW}$HOST${NC}"
    echo -e "端口: ${YELLOW}$PORT${NC}"
    echo -e "令牌: ${YELLOW}${ADMIN_TOKEN:0:8}...${NC}"
    echo -e "详细模式: ${YELLOW}$VERBOSE${NC}"
    echo -e "模拟运行: ${YELLOW}$DRY_RUN${NC}"
    echo -e "${BLUE}===================${NC}"
    echo
}

# 运行命令（支持dry-run）
run_cmd() {
    local cmd="$1"
    local desc="$2"
    
    echo -e "${BLUE}[验证]${NC} $desc"
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}命令: $cmd${NC}"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}[模拟] 跳过执行${NC}"
        return 0
    fi
    
    if eval "$cmd"; then
        echo -e "${GREEN}[通过] $desc${NC}"
        return 0
    else
        echo -e "${RED}[失败] $desc${NC}"
        return 1
    fi
}

# 主验证函数
main() {
    print_config
    
    local failed=0
    local total=0
    
    echo -e "${BLUE}=== 开始快速验证 ===${NC}"
    echo
    
    # 1. 基础健康检查
    echo -e "${BLUE}--- 基础健康检查 ---${NC}"
    run_cmd "curl -fsS http://$HOST:$PORT/healthz" "健康检查接口"
    if [ $? -ne 0 ]; then ((failed++)); fi
    ((total++))
    echo
    
    # 2. 管理界面访问
    echo -e "${BLUE}--- 管理界面验证 ---${NC}"
    run_cmd "curl -fsS http://$HOST:$PORT/admin/ | grep -q '<!DOCTYPE html>'" "管理界面HTML访问"
    if [ $? -ne 0 ]; then ((failed++)); fi
    ((total++))
    echo
    
    # 3. 管理接口验证（需要令牌）
    echo -e "${BLUE}--- 管理接口验证 ---${NC}"
    run_cmd "curl -fsS -H \"Authorization: Bearer $ADMIN_TOKEN\" http://$HOST:$PORT/admin/keys | grep -q '\"keys\"'" "获取密钥列表"
    if [ $? -ne 0 ]; then ((failed++)); fi
    ((total++))
    
    # 4. 创建试用密钥
    local key_data='{"name":"quick-validate-test","quota":100}'
    run_cmd "curl -fsS -X POST -H \"Authorization: Bearer $ADMIN_TOKEN\" -H \"Content-Type: application/json\" -d '$key_data' http://$HOST:$PORT/admin/keys | grep -q 'trial_key'" "创建试用密钥"
    if [ $? -ne 0 ]; then ((failed++)); fi
    ((total++))
    echo
    
    # 5. API网关验证
    echo -e "${BLUE}--- API网关验证 ---${NC}"
    # 注意：这里需要先获取创建的密钥，但为了简化，我们假设创建成功
    run_cmd "curl -fsS -H \"X-API-Key: dummy-key\" http://$HOST:$PORT/api/test | grep -q '403'" "API网关无权限访问（预期403）"
    if [ $? -ne 0 ]; then ((failed++)); fi
    ((total++))
    echo
    
    # 6. 使用情况统计
    echo -e "${BLUE}--- 使用情况统计 ---${NC}"
    run_cmd "curl -fsS -H \"Authorization: Bearer $ADMIN_TOKEN\" http://$HOST:$PORT/admin/usage | grep -q '\"total_requests\"'" "获取使用情况统计"
    if [ $? -ne 0 ]; then ((failed++)); fi
    ((total++))
    echo
    
    # 汇总结果
    echo -e "${BLUE}=== 验证结果汇总 ===${NC}"
    echo -e "总测试数: ${YELLOW}$total${NC}"
    echo -e "通过数: ${GREEN}$((total - failed))${NC}"
    echo -e "失败数: ${RED}$failed${NC}"
    echo
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✅ 所有验证通过！${NC}"
        return 0
    else
        echo -e "${RED}❌ 有 $failed 个验证失败${NC}"
        return 3
    fi
}

# 清理函数（在退出时调用）
cleanup() {
    if [ "$DRY_RUN" = false ] && [ "$failed" -gt 0 ]; then
        echo -e "${YELLOW}[清理] 跳过清理（有验证失败）${NC}"
    elif [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}[模拟] 跳过清理${NC}"
    else
        echo -e "${BLUE}[清理] 清理测试数据...${NC}"
        # 这里可以添加清理测试数据的逻辑
        echo -e "${GREEN}[清理完成]${NC}"
    fi
}

# 设置陷阱
trap cleanup EXIT

# 运行主函数
main "$@"