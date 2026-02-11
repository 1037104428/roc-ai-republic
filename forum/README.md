# NodeBB 论坛部署指南

## 概述

NodeBB 是一个现代化的论坛平台，基于 Node.js 构建，支持实时聊天、插件系统和现代化界面。本目录包含完整的 NodeBB 论坛部署配置。

## 快速开始

### 1. 环境要求
- Docker 20.10+
- Docker Compose 2.0+
- 至少 2GB 可用内存

### 2. 一键部署

```bash
# 进入论坛目录
cd forum

# 启动论坛
./start-forum.sh

# 验证部署
./verify-forum.sh

# 停止论坛
./stop-forum.sh
```

### 3. 访问地址
- NodeBB 直接访问: http://localhost:4567
- 通过 Nginx 代理: http://forum.localhost

### 4. 管理员账号
- 用户名: admin
- 密码: Clawd@2026!
- 邮箱: admin@clawd.ai

## 架构说明

### 服务组件
1. **NodeBB** - 论坛应用 (端口: 4567)
2. **Redis** - 缓存数据库 (端口: 6379)
3. **Nginx** - 反向代理 (端口: 80/443)

### 数据持久化
- Redis 数据: `redis-data` 卷
- NodeBB 数据: `nodebb-data` 卷
- 上传文件: `nodebb-uploads` 卷

## 配置文件

### docker-compose-nodebb.yml
主 Docker Compose 配置文件，包含所有服务定义。

### config.json
NodeBB 配置文件，包含数据库连接、密钥等设置。

### nginx.conf
Nginx 反向代理配置，支持 WebSocket 和静态文件缓存。

## 管理脚本

### start-forum.sh
启动脚本，自动设置环境变量、创建配置文件和启动服务。

### stop-forum.sh
停止脚本，安全停止所有服务。

### verify-forum.sh
验证脚本，检查环境、配置和服务状态。

## 高级配置

### 自定义域名
1. 修改 `docker-compose-nodebb.yml` 中的域名设置
2. 更新 `nginx.conf` 中的 server_name
3. 设置 DNS 解析或 hosts 文件

### SSL 证书
1. 将证书文件放入 `ssl/` 目录
2. 更新 `nginx.conf` 添加 SSL 配置
3. 修改端口映射为 443:443

### 备份与恢复
```bash
# 备份数据
docker run --rm -v nodebb-data:/source -v $(pwd)/backup:/backup alpine tar czf /backup/nodebb-data-$(date +%Y%m%d).tar.gz -C /source .

# 恢复数据
docker run --rm -v nodebb-data:/target -v $(pwd)/backup:/backup alpine tar xzf /backup/nodebb-data-20250212.tar.gz -C /target
```

## 监控与日志

### 查看日志
```bash
# 查看所有服务日志
docker-compose -f docker-compose-nodebb.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose-nodebb.yml logs -f nodebb
```

### 健康检查
- NodeBB: http://localhost:4567/api/ping
- Redis: `redis-cli ping`
- Nginx: http://localhost

## 故障排除

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   sudo lsof -i :4567
   sudo lsof -i :80
   
   # 修改端口映射
   # 编辑 docker-compose-nodebb.yml 中的 ports 部分
   ```

2. **内存不足**
   ```bash
   # 查看容器内存使用
   docker stats
   
   # 增加 Docker 内存限制
   # 编辑 Docker Desktop 设置或修改 docker-compose.yml 中的 mem_limit
   ```

3. **启动失败**
   ```bash
   # 查看详细错误
   docker-compose -f docker-compose-nodebb.yml logs --tail=50
   
   # 重新构建服务
   docker-compose -f docker-compose-nodebb.yml up --build -d
   ```

### 联系支持
- GitHub Issues: https://github.com/1037104428/roc-ai-republic/issues
- 社区论坛: 部署后访问 http://forum.localhost

## 安全建议

1. **修改默认密码**
   - 首次登录后立即修改管理员密码
   - 使用强密码策略

2. **更新密钥**
   ```bash
   # 生成新的密钥
   export NODEBB_SECRET=$(openssl rand -hex 32)
   # 更新 config.json
   ```

3. **防火墙配置**
   - 仅开放必要的端口 (80, 443)
   - 使用云服务商的安全组规则

4. **定期更新**
   ```bash
   # 更新镜像
   docker-compose -f docker-compose-nodebb.yml pull
   docker-compose -f docker-compose-nodebb.yml up -d
   ```

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进本部署方案。

### 开发流程
1. Fork 本仓库
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

### 测试要求
- 所有脚本必须通过 `bash -n` 语法检查
- 验证脚本必须正常运行
- 更新 README 文档