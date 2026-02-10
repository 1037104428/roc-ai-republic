#!/bin/bash
set -e

# 简单版本：为 quota-proxy 添加 ADMIN_TOKEN 保护
HOST="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

echo "目标主机: $HOST"
echo "为 quota-proxy 添加 ADMIN_TOKEN 保护..."

# 生成随机 ADMIN_TOKEN
ADMIN_TOKEN=$(openssl rand -hex 32 2>/dev/null || echo "admin-token-$(date +%s)")

cat > /tmp/simple-admin-auth.sh <<'EOF'
#!/bin/bash
set -e

cd /opt/roc/quota-proxy

echo "备份当前 server.js..."
cp -f server.js server.js.backup.$(date +%s)

echo "设置 ADMIN_TOKEN..."
if [ ! -f .env ]; then
  echo "ADMIN_TOKEN=$ADMIN_TOKEN" > .env
else
  if grep -q "^ADMIN_TOKEN=" .env; then
    sed -i "s/^ADMIN_TOKEN=.*/ADMIN_TOKEN=$ADMIN_TOKEN/" .env
  else
    echo "ADMIN_TOKEN=$ADMIN_TOKEN" >> .env
  fi
fi

echo "修改 server.js 添加管理员认证..."
# 首先检查是否已经有 adminAuth 函数
if ! grep -q "const adminAuth" server.js; then
  # 在 ADMIN_TOKEN 定义后添加 adminAuth 函数
  sed -i '/const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '\'''\'';/a\
\
// 管理员认证中间件\
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

# 为管理员路由添加中间件（跳过 /admin/healthz）
sed -i 's/app\.get('\''\/admin\/keys'\'',/app.get('\''\/admin\/keys'\'', adminAuth, /' server.js
sed -i 's/app\.post('\''\/admin\/keys'\'',/app.post('\''\/admin\/keys'\'', adminAuth, /' server.js
sed -i 's/app\.delete('\''\/admin\/keys\/:key'\'',/app.delete('\''\/admin\/keys\/:key'\'', adminAuth, /' server.js
sed -i 's/app\.get('\''\/admin\/usage'\'',/app.get('\''\/admin\/usage'\'', adminAuth, /' server.js
sed -i 's/app\.post('\''\/admin\/usage\/reset'\'',/app.post('\''\/admin\/usage\/reset'\'', adminAuth, /' server.js

echo "重启服务..."
docker compose restart

echo "等待服务启动..."
sleep 5

echo "检查服务状态..."
docker compose ps

echo "测试健康检查..."
curl -fsS http://127.0.0.1:8787/healthz || (echo "健康检查失败"; exit 1)

echo "测试管理员接口（无 token 应返回 401）..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8787/admin/keys)
echo "HTTP 状态码: $HTTP_CODE"

echo "测试管理员接口（有 token 应返回 200）..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" http://127.0.0.1:8787/admin/keys)
echo "HTTP 状态码: $HTTP_CODE"

echo "完成!"
echo "ADMIN_TOKEN: $ADMIN_TOKEN"
EOF

# 替换脚本中的 ADMIN_TOKEN 变量
sed -i "s/\$ADMIN_TOKEN/$ADMIN_TOKEN/g" /tmp/simple-admin-auth.sh

echo "开始执行..."
scp -i "$SSH_KEY" /tmp/simple-admin-auth.sh "root@$HOST:/tmp/simple-admin-auth.sh"
ssh -i "$SSH_KEY" "root@$HOST" "bash /tmp/simple-admin-auth.sh"

echo "验证部署..."
ssh -i "$SSH_KEY" "root@$HOST" "cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz"

echo "ADMIN_TOKEN 保护已添加！"
echo "ADMIN_TOKEN: $ADMIN_TOKEN"

rm -f /tmp/simple-admin-auth.sh