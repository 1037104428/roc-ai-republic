#!/usr/bin/env bash
set -euo pipefail

# 修复论坛 502 问题（DNS 记录缺失）
# 当前问题：forum.clawdrepublic.cn 缺少 DNS A 记录，Caddy 无法获取 SSL 证书
# 解决方案：1) 添加 DNS 记录 2) 临时使用主域名子路径

echo "=== 论坛 502 修复脚本 ==="
echo "问题：forum.clawdrepublic.cn 返回 502"
echo "原因：缺少 DNS A 记录，Caddy 无法获取 SSL 证书"
echo ""

# 检查当前状态
echo "1. 检查论坛容器状态..."
if ssh -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 "docker ps | grep -q flarum"; then
  echo "   ✓ 论坛容器正在运行 (127.0.0.1:8081)"
else
  echo "   ✗ 论坛容器未运行"
  exit 1
fi

echo ""
echo "2. 检查 Caddy 日志中的 DNS 错误..."
ssh -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 \
  "journalctl -u caddy --since '5 minutes ago' | grep -i 'forum.clawdrepublic.cn' | tail -3" 2>/dev/null || true

echo ""
echo "3. 临时解决方案（二选一）："
echo ""
echo "   A) 添加 DNS 记录（推荐长期方案）"
echo "      在 DNS 控制台添加："
echo "        forum.clawdrepublic.cn A 8.210.185.194"
echo "        forum.clawdrepublic.cn AAAA (如有 IPv6)"
echo ""
echo "   B) 使用主域名子路径（临时方案）"
echo "      修改 Caddy 配置，将论坛放在 /forum/ 路径下："
echo "        handle /forum/* {"
echo "          reverse_proxy 127.0.0.1:8081"
echo "        }"
echo ""
echo "   C) 禁用 HTTPS（仅测试用）"
echo "      修改 Caddy 配置，对 forum.clawdrepublic.cn 使用 HTTP："
echo "        forum.clawdrepublic.cn:80 {"
echo "          reverse_proxy 127.0.0.1:8081"
echo "        }"

echo ""
echo "4. 验证当前论坛可访问性："
echo "   内网访问："
ssh -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 \
  "curl -fsS -m 5 http://127.0.0.1:8081/ | grep -o '<title>[^<]*</title>' | head -1" 2>/dev/null || echo "   内网访问失败"

echo ""
echo "5. 操作建议："
echo "   - 如果只是测试，可使用方案 B（/forum/ 子路径）"
echo "   - 如果准备正式使用，使用方案 A（添加 DNS 记录）"
echo "   - 添加 DNS 记录后，Caddy 会自动获取 SSL 证书，无需重启"

echo ""
echo "=== 脚本结束 ==="
echo "如需应用临时方案 B，请运行："
echo "  ./scripts/apply-forum-subpath-fix.sh"