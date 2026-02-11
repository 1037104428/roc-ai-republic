# 论坛部署快速测试指南

> 用于验证论坛部署脚本的可行性，不实际运行生产环境

## 一、环境检查

### 1.1 系统要求
- Docker 20.10+
- Docker Compose 2.0+
- 2GB 可用内存
- 5GB 磁盘空间

### 1.2 快速检查命令
```bash
# 检查Docker
docker --version
docker-compose --version

# 检查端口占用
ss -tlnp | grep -E ':3000|:5432'

# 检查磁盘空间
df -h .
```

## 二、部署脚本验证

### 2.1 脚本结构验证
```bash
# 检查部署脚本语法
bash -n scripts/deploy-forum.sh

# 查看脚本内容摘要
head -50 scripts/deploy-forum.sh
```

### 2.2 配置文件生成测试
```bash
# 创建测试目录
mkdir -p /tmp/forum-test
cd /tmp/forum-test

# 生成docker-compose.yml（不实际运行）
cat > docker-compose.test.yml << 'EOF'
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: test_forum
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test123
    ports:
      - "5433:5432"
  forum:
    image: flarum/flarum:stable
    depends_on:
      - postgres
    environment:
      FORUM_URL: http://localhost:3000
      DB_HOST: postgres
      DB_NAME: test_forum
      DB_USER: test
      DB_PASSWORD: test123
    ports:
      - "3001:80"
EOF

echo "✅ 配置文件生成成功"
```

## 三、一键部署测试（可选）

### 3.1 安全测试模式
```bash
# 创建.env文件
cat > .env << 'EOF'
DB_PASSWORD=secure_password_123
FORUM_ADMIN_EMAIL=admin@example.com
FORUM_ADMIN_PASSWORD=Admin123!
EOF

# 验证环境变量
echo "DB_PASSWORD长度: ${#DB_PASSWORD}"
```

### 3.2 最小化部署测试
```bash
# 仅拉取镜像（不运行）
docker pull postgres:15-alpine
docker pull flarum/flarum:stable

# 验证镜像可用性
docker images | grep -E "postgres|flarum"
```

## 四、验证步骤

### 4.1 部署前验证清单
- [ ] Docker服务运行正常
- [ ] 端口3000、5432未被占用
- [ ] 有足够磁盘空间
- [ ] 网络连接正常（可拉取镜像）

### 4.2 部署后验证
```bash
# 健康检查（部署后）
curl -f http://localhost:3000/healthz 2>/dev/null || echo "服务未运行"

# 容器状态检查
docker-compose ps

# 日志检查
docker-compose logs --tail=10
```

## 五、故障排除

### 5.1 常见问题
1. **端口冲突**：修改docker-compose.yml中的端口映射
2. **内存不足**：增加swap空间或减少容器资源限制
3. **镜像拉取失败**：检查网络连接，使用国内镜像源

### 5.2 快速恢复
```bash
# 停止并清理
docker-compose down -v

# 重新部署
docker-compose up -d

# 查看实时日志
docker-compose logs -f
```

## 六、生产部署建议

### 6.1 安全加固
- 使用强密码生成器
- 配置HTTPS证书
- 设置防火墙规则
- 定期备份数据库

### 6.2 性能优化
- 配置数据库连接池
- 启用缓存（Redis）
- 设置CDN加速静态资源
- 监控资源使用情况

---

**测试状态**：文档创建完成，待实际部署验证
**创建时间**：2026-02-11 19:43
**下一步**：运行简化部署测试，验证脚本可行性