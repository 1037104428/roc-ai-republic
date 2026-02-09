# Clawd共和国论坛 MVP

## 🎯 当前状态

- ✅ **论坛引擎**：Flarum 已部署在服务器 `127.0.0.1:8081`
- ✅ **数据库**：MariaDB 11 运行正常
- ✅ **容器编排**：Docker Compose 管理
- ✅ **反向代理**：Caddy 配置完成（主域名子路径方案）
- ✅ **HTTPS 访问**：通过 `https://clawdrepublic.cn/forum/` 可访问
- ⚠️ **独立子域名**：`forum.clawdrepublic.cn` 等待 DNS 记录配置
- ✅ **初始化内容**：标准板块和置顶帖已创建

## 🚀 快速验证

### 内部服务检查
```bash
# SSH 到服务器验证
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 \
  "docker ps | grep forum && \
   curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && \
   echo '✅ 论坛内部服务正常'"
```

### 外部访问检查
```bash
# 子路径访问（当前可用）
curl -fsS -m 5 https://clawdrepublic.cn/forum/ >/dev/null && \
  echo '✅ 论坛外部访问正常（子路径方案）'

# 子域名访问（等待 DNS 配置）
curl -fsS -m 5 https://forum.clawdrepublic.cn/ 2>/dev/null || \
  echo '⚠️  子域名访问异常（预期：DNS 记录未配置）'
```

### 一键验证脚本
```bash
# 全量验证
./scripts/verify-forum-mvp.sh

# 快速检查
./scripts/quick-verify-forum.sh
```

## 📋 访问方式

### 当前可用
- **主域名子路径**：`https://clawdrepublic.cn/forum/`
- **适用场景**：临时解决方案，无需 DNS 配置

### 待配置
- **独立子域名**：`https://forum.clawdrepublic.cn/`
- **需要操作**：添加 DNS A 记录 `forum.clawdrepublic.cn → 8.210.185.194`

## 🔧 运维操作

### 常用命令
```bash
# 进入论坛目录
cd /opt/roc/forum

# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看日志
docker compose logs -f forum

# 重启服务
docker compose restart forum
```

### 数据备份
```bash
# 备份数据库
docker exec forum-db-1 mysqldump -u root -p${MYSQL_ROOT_PASSWORD} flarum > backup.sql

# 一键备份脚本
./scripts/backup-forum.sh
```

## 📚 详细文档

- [完整部署与运维指南](../docs/forum-deployment-guide.md)
- [论坛部署 ticket](../docs/tickets.md#论坛-现网优先)
- [初始化内容脚本](../scripts/init-forum-sticky-posts.sh)
- [故障排查指南](../docs/forum-deployment-guide.md#故障排查)

## 🎨 初始化内容

### 标准板块
1. **新手入门** - 安装指南、常见问题
2. **TRIAL_KEY 申请** - 试用密钥发放
3. **问题求助** - 技术问题讨论
4. **Clawd 入驻** - 项目介绍、贡献指南
5. **杂谈** - 非技术讨论

### 置顶帖
- TRIAL_KEY 获取与使用指南
- OpenClaw 小白版一条龙教程
- 论坛使用指南

初始化脚本：`./scripts/init-forum-sticky-posts.sh`

## 🔄 升级与维护

### 安全更新
```bash
# 更新镜像
docker compose pull
docker compose up -d

# 检查安全更新
./scripts/check-forum-security-updates.sh
```

### 监控健康
```bash
# 健康检查
./scripts/monitor-forum-health.sh

# 性能监控
./scripts/monitor-forum-performance.sh
```

## 🆘 故障排除

### 常见问题
1. **论坛无法访问**：检查容器状态 `docker compose ps`
2. **数据库连接失败**：验证数据库服务 `docker compose logs forum-db`
3. **权限问题**：检查文件权限 `ls -la /opt/roc/forum/data/`

### 快速修复
```bash
# 重启所有服务
cd /opt/roc/forum && docker compose restart

# 查看详细错误
docker compose logs --tail=50 forum
```

## 📞 支持与贡献

- **问题报告**：在论坛"问题求助"板块发帖
- **改进建议**：提交 GitHub Issue 或 Pull Request
- **紧急支持**：查看 [运维指南](../docs/forum-deployment-guide.md#故障恢复)