#!/bin/bash
set -e

# Verify forum fix
# Usage: ./scripts/verify-forum-fix.sh

echo "=== Verifying forum accessibility fix ==="

# 1. Check Caddy service status
echo "1. Checking Caddy service status..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
    systemctl status caddy --no-pager -l | head -30
'

# 2. Check forum service
echo "2. Checking forum service (Flarum)..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
    systemctl status flarum 2>/dev/null || echo "Flarum service not found, checking process..."
    ps aux | grep -E "(flarum|php.*8081)" | grep -v grep || echo "No Flarum process found"
    netstat -tlnp | grep :8081 || echo "Port 8081 not listening"
'

# 3. Test local access
echo "3. Testing local access to forum..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
    echo "Testing localhost:8081..."
    curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo "✅ Forum accessible locally" || echo "❌ Forum not accessible locally"
'

# 4. Test external access via subdomain
echo "4. Testing external access via forum.clawdrepublic.cn..."
curl -fsS -m 10 https://forum.clawdrepublic.cn/ >/dev/null && echo "✅ Forum accessible via subdomain" || echo "❌ Forum not accessible via subdomain"

# 5. Test external access via path
echo "5. Testing external access via /forum path..."
curl -fsS -m 10 https://clawdrepublic.cn/forum/ >/dev/null && echo "✅ Forum accessible via /forum path" || echo "❌ Forum not accessible via /forum path"

# 6. Check Caddy logs
echo "6. Checking Caddy logs for errors..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
    echo "Recent Caddy errors:"
    journalctl -u caddy --since "5 minutes ago" | grep -i error | tail -5 || echo "No recent errors"
'

# 7. Verify Caddyfile
echo "7. Verifying Caddyfile configuration..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
    echo "Caddyfile forum configuration:"
    grep -A5 -B5 "forum" /etc/caddy/Caddyfile || echo "No forum config found"
'

echo "=== Verification complete ==="
echo ""
echo "Summary:"
echo "- Caddy service should be running (not reloading)"
echo "- Forum should be accessible via https://forum.clawdrepublic.cn"
echo "- Forum should be accessible via https://clawdrepublic.cn/forum/"
echo "- No permission errors in Caddy logs"