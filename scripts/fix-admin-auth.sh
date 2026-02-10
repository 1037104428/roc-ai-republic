#!/bin/bash
set -e

# 修复 server-better-sqlite.js 中的管理员认证
HOST="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

echo "目标主机: $HOST"
echo "修复 server-better-sqlite.js 管理员认证..."

cat > /tmp/fix-auth.sh <<'EOF'
#!/bin/bash
set -e

cd /opt/roc/quota-proxy

echo "备份当前 server-better-sqlite.js..."
cp -f server-better-sqlite.js server-better-sqlite.js.backup.$(date +%s)

echo "检查当前 ADMIN_TOKEN..."
ADMIN_TOKEN=$(grep "^ADMIN_TOKEN=" .env 2>/dev/null | cut -d= -f2)
if [ -z "$ADMIN_TOKEN" ]; then
  echo "错误: 未找到 ADMIN_TOKEN"
  exit 1
fi

echo "在 server-better-sqlite.js 中添加 adminAuth 中间件..."
# 首先检查是否已经有 adminAuth 函数
if ! grep -q "const adminAuth" server-better-sqlite.js; then
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
};' server-better-sqlite.js
fi

echo "为管理员路由添加 adminAuth 中间件并移除 isAdmin 检查..."
# 替换 app.get('/admin/keys', ...)
sed -i "s/app\.get('\/admin\/keys', (req, res) => {/app.get('\/admin\/keys', adminAuth, (req, res) => {/" server-better-sqlite.js
sed -i "/app\.get('\/admin\/keys', adminAuth, (req, res) => {/,/^  })/{/  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });/d}" server-better-sqlite.js

# 替换 app.post('/admin/keys', ...)
sed -i "s/app\.post('\/admin\/keys', (req, res) => {/app.post('\/admin\/keys', adminAuth, (req, res) => {/" server-better-sqlite.js
sed -i "/app\.post('\/admin\/keys', adminAuth, (req, res) => {/,/^  })/{/  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });/d}" server-better-sqlite.js

# 替换 app.delete('/admin/keys/:key', ...)
sed -i "s/app\.delete('\/admin\/keys\/:key', (req, res) => {/app.delete('\/admin\/keys\/:key', adminAuth, (req, res) => {/" server-better-sqlite.js
sed -i "/app\.delete('\/admin\/keys\/:key', adminAuth, (req, res) => {/,/^  })/{/  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });/d}" server-better-sqlite.js

# 替换 app.get('/admin/usage', ...)
sed -i "s/app\.get('\/admin\/usage', (req, res) => {/app.get('\/admin\/usage', adminAuth, (req, res) => {/" server-better-sqlite.js
sed -i "/app\.get('\/admin\/usage', adminAuth, (req, res) => {/,/^  })/{/  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });/d}" server-better-sqlite.js

# 替换 app.post('/admin/usage/reset', ...)
sed -i "s/app\.post('\/admin\/usage\/reset', (req, res) => {/app.post('\/admin\/usage\/reset', adminAuth, (req, res) => {/" server-better-sqlite.js
sed -i "/app\.post('\/admin\/usage\/reset', adminAuth, (req, res) => {/,/^  })/{/  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });/d}" server-better-sqlite.js

echo "确保 Dockerfile 使用正确的文件..."
if [ -f Dockerfile-better-sqlite ]; then
  echo "Dockerfile-better-sqlite 已存在"
else
  cat > Dockerfile-better-sqlite <<'DOCKER_EOF'
FROM node:20-alpine
WORKDIR /app

# 复制 package.json 文件
COPY package*.json ./

# 安装依赖（better-sqlite3 需要编译）
RUN apk add --no-cache python3 make g++ \
    && npm ci --only=production \
    && apk del python3 make g++

# 复制应用代码
COPY server-better-sqlite.js ./server.js
COPY admin.html ./

EXPOSE 8787
CMD ["node", "server.js"]
DOCKER_EOF
fi

echo "重建并重启容器..."
docker compose down
docker compose build
docker compose up -d

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

if [ "$HTTP_CODE" = "200" ]; then
  echo "成功！管理员接口现在受 ADMIN_TOKEN 保护。"
  echo "ADMIN_TOKEN: $ADMIN_TOKEN"
else
  echo "警告: 管理员接口可能仍有问题，HTTP 状态码: $HTTP_CODE"
  echo "检查日志: docker compose logs"
fi
EOF

echo "开始执行..."
scp -i "$SSH_KEY" /tmp/fix-auth.sh "root@$HOST:/tmp/fix-auth.sh"
ssh -i "$SSH_KEY" "root@$HOST" "bash /tmp/fix-auth.sh"

rm -f /tmp/fix-auth.sh