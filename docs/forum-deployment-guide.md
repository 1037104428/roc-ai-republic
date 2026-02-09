# 论坛部署与运维指南

## 当前部署状态

### ✅ 已完成的组件
1. **论坛引擎**：Flarum (mondedie/flarum:stable)
2. **数据库**：MariaDB 11
3. **容器编排**：Docker Compose
4. **反向代理**：Caddy（主域名子路径 `/forum/`）
5. **HTTPS**：通过主域名证书自动启用

### 🌐 访问方式
- **主域名子路径**：`https://clawdrepublic.cn/forum/`（当前可用）
- **独立子域名**：`https://forum.clawdrepublic.cn/`（等待 DNS 配置）

### 📊 健康状态检查
```bash
# 1. 内部服务检查（SSH 到服务器）
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 \
  "docker ps | grep forum && \
   curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && \
   echo '论坛内部服务正常'"

# 2. 外部访问检查
curl -fsS -m 5 https://clawdrepublic.cn/forum/ >/dev/null && \
  echo '论坛外部访问正常（子路径）'

# 3. 一键全量检查
./scripts/verify-forum-mvp.sh
```

## 部署架构

```
用户浏览器
    ↓ HTTPS
Caddy (clawdrepublic.cn:443)
    ↓ /forum/* 路由
Flarum 容器 (127.0.0.1:8081)
    ↓
MariaDB 容器 (forum-db-1)
```

### 容器配置
```yaml
# docker-compose.yml 位置：/opt/roc/forum/
version: '3.8'
services:
  forum-db:
    image: mariadb:11
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: flarum
      MYSQL_USER: flarum
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - ./data/mysql:/var/lib/mysql
    restart: unless-stopped

  forum:
    image: mondedie/flarum:stable
    depends_on:
      - forum-db
    environment:
      FLARUM_BASE_URL: https://clawdrepublic.cn/forum
      DB_HOST: forum-db
      DB_NAME: flarum
      DB_USER: flarum
      DB_PASSWORD: ${MYSQL_PASSWORD}
      FORUM_ADMIN_USER: admin
      FORUM_ADMIN_PASS: ${ADMIN_PASSWORD}
      FORUM_ADMIN_MAIL: admin@clawdrepublic.cn
    volumes:
      - ./data/assets:/flarum/app/public/assets
      - ./data/extensions:/flarum/app/extensions
    ports:
      - "127.0.0.1:8081:8888"
    restart: unless-stopped
```

### Caddy 配置（关键部分）
```caddy
# /etc/caddy/Caddyfile
clawdrepublic.cn {
    # ... 其他配置 ...
    
    # 论坛反向代理（子路径方案）
    handle /forum/* {
        reverse_proxy http://127.0.0.1:8081
    }
    
    # ... 其他配置 ...
}

# 子域名方案（等待 DNS 配置）
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081
}
```

## 运维操作

### 1. 启动/停止论坛
```bash
# SSH 到服务器操作
ssh root@8.210.185.194

# 进入论坛目录
cd /opt/roc/forum

# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看日志
docker compose logs -f forum
docker compose logs -f forum-db

# 重启服务
docker compose restart forum
```

### 2. 数据备份
```bash
# 备份数据库
docker exec forum-db-1 mysqldump -u root -p${MYSQL_ROOT_PASSWORD} flarum > backup-$(date +%Y%m%d).sql

# 备份上传文件
tar czf forum-assets-$(date +%Y%m%d).tar.gz /opt/roc/forum/data/assets/

# 一键备份脚本
./scripts/backup-forum.sh
```

### 3. 故障排查

#### 论坛无法访问
```bash
# 检查容器状态
docker compose ps

# 检查论坛日志
docker compose logs forum

# 检查数据库连接
docker exec forum-db-1 mysql -u flarum -p${MYSQL_PASSWORD} -e "SHOW DATABASES;"

# 检查网络连通性
curl -v http://127.0.0.1:8081/
```

#### 性能问题
```bash
# 查看资源使用
docker stats

# 数据库查询优化
docker exec forum-db-1 mysql -u root -p${MYSQL_ROOT_PASSWORD} flarum -e "SHOW PROCESSLIST;"

# 清理缓存
docker compose exec forum php flarum cache:clear
```

### 4. 安全维护
```bash
# 更新 Flarum 镜像
docker compose pull forum
docker compose up -d --force-recreate forum

# 更新数据库镜像
docker compose pull forum-db
docker compose up -d --force-recreate forum-db

# 检查安全更新
./scripts/check-forum-security-updates.sh
```

## 初始化内容

### 标准板块结构
1. **新手入门** - 安装指南、常见问题
2. **TRIAL_KEY 申请** - 试用密钥发放
3. **问题求助** - 技术问题讨论
4. **Clawd 入驻** - 项目介绍、贡献指南
5. **杂谈** - 非技术讨论

### 置顶帖模板
已预置在 `docs/posts/` 目录：
- `置顶_TRIAL_KEY_获取与使用_模板.md`
- `置顶_OpenClaw_小白版_一条龙_安装到调用.md`
- `置顶_论坛使用指南.md`

初始化脚本：
```bash
./scripts/init-forum-sticky-posts.sh
```

## 扩展与自定义

### 安装扩展
```bash
# SSH 到服务器
ssh root@8.210.185.194

# 进入论坛容器
docker compose exec forum bash

# 安装扩展（示例：标签扩展）
composer require flarum/tags

# 退出容器并重启
exit
docker compose restart forum
```

### 主题自定义
1. 修改 `./data/assets/` 中的 CSS/JS 文件
2. 使用 Flarum 后台的主题设置
3. 重启论坛服务使更改生效

## 监控与告警

### 健康检查端点
```bash
# 论坛健康检查
curl -fsS https://clawdrepublic.cn/forum/api/health

# 数据库健康检查
ssh root@8.210.185.194 "docker exec forum-db-1 mysqladmin ping -u root -p${MYSQL_ROOT_PASSWORD}"
```

### 监控脚本
```bash
# 定期健康检查
./scripts/monitor-forum-health.sh

# 性能监控
./scripts/monitor-forum-performance.sh

# 异常检测
./scripts/detect-forum-anomalies.sh
```

## 升级指南

### 小版本升级（Flarum）
```bash
# 1. 备份当前数据
./scripts/backup-forum.sh

# 2. 更新镜像标签
# 编辑 docker-compose.yml，更新 forum 服务镜像版本

# 3. 重新部署
docker compose pull
docker compose up -d

# 4. 运行数据库迁移
docker compose exec forum php flarum migrate

# 5. 清理缓存
docker compose exec forum php flarum cache:clear
```

### 大版本升级
1. 在测试环境验证兼容性
2. 分阶段升级（数据库 → Flarum → 扩展）
3. 监控升级后的性能表现
4. 准备回滚方案

## 故障恢复

### 数据库损坏恢复
```bash
# 1. 停止服务
docker compose down

# 2. 恢复备份
docker compose up -d forum-db
docker exec -i forum-db-1 mysql -u root -p${MYSQL_ROOT_PASSWORD} flarum < backup-20250209.sql

# 3. 启动论坛
docker compose up -d forum
```

### 文件系统损坏
```bash
# 恢复上传文件
tar xzf forum-assets-20250209.tar.gz -C /

# 修复权限
chown -R 1000:1000 /opt/roc/forum/data/assets
```

## 贡献指南

### 报告问题
1. 在论坛"问题求助"板块发帖
2. 提供：
   - 错误信息
   - 复现步骤
   - 环境信息
   - 相关日志

### 提交改进
1. Fork 仓库
2. 创建功能分支
3. 提交 Pull Request
4. 包含测试和文档更新

## 相关资源

- [Flarum 官方文档](https://docs.flarum.org/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [Caddy 文档](https://caddyserver.com/docs/)
- [项目 tickets](../docs/tickets.md)
- [论坛状态监控](../docs/forum/status.md)