#!/bin/bash
set -e

# 为现有 quota-proxy 添加 ADMIN_TOKEN 保护
# 用法: ./scripts/add-admin-token-protection.sh [--dry-run] [--host <ip>]

DRY_RUN=false
HOST=""
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: $0 [--dry-run] [--host <ip>]"
      exit 1
      ;;
  esac
done

if [ -z "$HOST" ]; then
  if [ -f "/tmp/server.txt" ]; then
    HOST=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' /tmp/server.txt | head -1)
    if [ -z "$HOST" ]; then
      HOST=$(grep -E '^ip:' /tmp/server.txt | cut -d: -f2 | tr -d ' ')
    fi
  fi
  if [ -z "$HOST" ]; then
    echo "错误: 未指定主机且 /tmp/server.txt 中未找到 IP"
    exit 1
  fi
fi

echo "目标主机: $HOST"
echo "为现有 quota-proxy 添加 ADMIN_TOKEN 保护..."

# 生成随机 ADMIN_TOKEN
ADMIN_TOKEN=$(openssl rand -hex 32 2>/dev/null || echo "admin-token-$(date +%s)")

cat > /tmp/add-admin-token.sh <<EOF
#!/bin/bash
set -e

cd /opt/roc/quota-proxy

echo "备份当前 server.js..."
cp -f server.js server.js.backup.\$(date +%s)

echo "检查当前 server.js 是否已有 ADMIN_TOKEN 检查..."
if grep -q "ADMIN_TOKEN" server.js; then
  echo "警告: server.js 似乎已有 ADMIN_TOKEN 检查"
  echo "当前 ADMIN_TOKEN 值:"
  grep ADMIN_TOKEN .env 2>/dev/null || echo "未找到 .env 文件"
fi

echo "创建 .env 文件（如果不存在）..."
if [ ! -f .env ]; then
  cat > .env <<ENV_EOF
ADMIN_TOKEN=$ADMIN_TOKEN
ENV_EOF
else
  # 更新或添加 ADMIN_TOKEN
  if grep -q "^ADMIN_TOKEN=" .env; then
    sed -i "s/^ADMIN_TOKEN=.*/ADMIN_TOKEN=$ADMIN_TOKEN/" .env
  else
    echo "ADMIN_TOKEN=$ADMIN_TOKEN" >> .env
  fi
fi

echo "修改 server.js 添加 ADMIN_TOKEN 检查..."
# 创建临时文件
cat > /tmp/server-patch.js <<'PATCH_EOF'
// ADMIN_TOKEN 中间件
const adminAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  
  const token = authHeader.substring(7);
  if (token !== process.env.ADMIN_TOKEN) {
    return res.status(403).json({ error: 'Invalid admin token' });
  }
  
  next();
};

// 应用中间件到管理员接口
// 注意：这里假设 server.js 中已有 app.post('/admin/keys', ...) 等路由
// 实际修改需要根据具体文件内容调整
PATCH_EOF

# 应用补丁（简化版：直接修改文件）
# 这里使用一个更安全的方法：先备份，然后使用 sed 添加中间件定义
if ! grep -q "const adminAuth" server.js; then
  # 在文件开头附近添加中间件定义
  sed -i '/^const express = require/ a\
const adminAuth = (req, res, next) => {\
  const authHeader = req.headers.authorization;\
  if (!authHeader || !authHeader.startsWith("Bearer ")) {\
    return res.status(401).json({ error: "Missing or invalid Authorization header" });\
  }\
  \
  const token = authHeader.substring(7);\
  if (token !== process.env.ADMIN_TOKEN) {\
    return res.status(403).json({ error: "Invalid admin token" });\
  }\
  \
  next();\
};' server.js
fi

# 为管理员路由添加中间件
sed -i 's/app\.post(\"\/admin\/keys\",/app.post(\"\/admin\/keys\", adminAuth, /g' server.js
sed -i 's/app\.get(\"\/admin\/keys\",/app.get(\"\/admin\/keys\", adminAuth, /g' server.js
sed -i 's/app\.delete(\"\/admin\/keys\/:key\",/app.delete(\"\/admin\/keys\/:key\", adminAuth, /g' server.js
sed -i 's/app\.put(\"\/admin\/keys\/:key\",/app.put(\"\/admin\/keys\/:key\", adminAuth, /g' server.js
sed -i 's/app\.get(\"\/admin\/usage\",/app.get(\"\/admin\/usage\", adminAuth, /g' server.js
sed -i 's/app\.post(\"\/admin\/usage\/reset\",/app.post(\"\/admin\/usage\/reset\", adminAuth, /g' server.js

echo "重启服务..."
docker compose restart

echo "等待服务启动..."
sleep 3

echo "检查服务状态..."
docker compose ps

echo "测试健康检查..."
curl -fsS http://127.0.0.1:8787/healthz || (echo "健康检查失败"; exit 1)

echo "测试管理员接口（无 token 应返回 401）..."
curl -fsS -w 'HTTP %{http_code}\n' http://127.0.0.1:8787/admin/keys 2>/dev/null | tail -1

echo "测试管理员接口（有 token 应返回 200）..."
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" -w 'HTTP %{http_code}\n' http://127.0.0.1:8787/admin/keys 2>/dev/null | tail -1

echo "完成!"
echo "ADMIN_TOKEN: $ADMIN_TOKEN"
echo "请妥善保存此 token"
EOF

if [ "$DRY_RUN" = true ]; then
  echo "=== 干跑模式 ==="
  echo "将执行以下操作:"
  cat /tmp/add-admin-token.sh
  echo "ADMIN_TOKEN: $ADMIN_TOKEN"
else
  echo "开始添加 ADMIN_TOKEN 保护..."
  scp -i "$SSH_KEY" /tmp/add-admin-token.sh "root@$HOST:/tmp/add-admin-token.sh"
  ssh -i "$SSH_KEY" "root@$HOST" "bash /tmp/add-admin-token.sh"
  
  echo "验证部署..."
  ssh -i "$SSH_KEY" "root@$HOST" "cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz"
  
  echo "ADMIN_TOKEN 保护已添加！"
  echo "ADMIN_TOKEN 已保存到服务器 /opt/roc/quota-proxy/.env"
fi

rm -f /tmp/add-admin-token.sh