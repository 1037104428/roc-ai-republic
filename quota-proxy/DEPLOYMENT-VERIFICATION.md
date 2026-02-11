# 部署验证脚本

`deployment-verification.sh` 是一个用于验证 quota-proxy 服务器部署状态的脚本。它检查所有关键API端点，确保服务正常运行。

## 功能特性

- ✅ **全面验证**：检查5个关键API端点（健康检查、试用密钥生成、验证、配额检查、使用统计）
- ✅ **灵活配置**：支持自定义主机、端口和管理员令牌
- ✅ **干运行模式**：预览将要执行的命令而不实际发送请求
- ✅ **颜色编码输出**：绿色表示成功，红色表示失败，黄色表示警告
- ✅ **环境检查**：自动检查Docker容器状态和进程状态
- ✅ **错误处理**：详细的错误信息和故障排除建议

## 快速开始

### 基本使用

```bash
# 进入 quota-proxy 目录
cd quota-proxy

# 运行验证脚本（使用默认配置）
./deployment-verification.sh
```

### 自定义配置

```bash
# 指定主机和端口
./deployment-verification.sh --host 192.168.1.100 --port 8080

# 指定管理员令牌
./deployment-verification.sh --token "your-secret-admin-token"

# 或通过环境变量设置
export ADMIN_TOKEN="your-secret-admin-token"
./deployment-verification.sh
```

### 干运行模式

```bash
# 预览将要执行的命令
./deployment-verification.sh --dry-run
```

## 验证的端点

脚本会验证以下端点：

1. **健康检查** (`GET /healthz`)
   - 验证服务是否正常运行
   - 期望返回 HTTP 200

2. **试用密钥生成** (`POST /admin/keys`)
   - 验证管理员API是否正常工作
   - 需要有效的管理员令牌
   - 期望返回 HTTP 201

3. **试用密钥验证** (`POST /verify`)
   - 验证试用密钥验证端点
   - 期望返回 HTTP 200 或适当的错误码

4. **配额检查** (`POST /quota`)
   - 验证配额检查逻辑
   - 期望返回 HTTP 200

5. **使用统计** (`GET /admin/usage`)
   - 验证管理员使用统计端点
   - 需要有效的管理员令牌
   - 期望返回 HTTP 200

## 环境检查

除了API端点验证，脚本还会检查：

- **Docker容器状态**：如果Docker可用，显示quota-proxy相关容器的状态
- **进程状态**：检查是否有Node.js进程运行quota-proxy

## 故障排除

### 常见问题

1. **连接被拒绝**
   ```
   ✗ 失败 (HTTP 000)
   ```
   - 确保服务器已启动：`./start-sqlite-persistent.sh`
   - 检查防火墙设置
   - 验证主机和端口配置

2. **管理员令牌无效**
   ```
   ✗ 失败 (HTTP 401)
   ```
   - 设置正确的管理员令牌：`export ADMIN_TOKEN="your-token"`
   - 检查服务器启动时的ADMIN_TOKEN配置

3. **服务未运行**
   ```
   ⚠ 未找到 quota-proxy 进程
   ```
   - 启动服务：`./start-sqlite-persistent.sh`
   - 检查日志：`docker logs quota-proxy` 或查看服务器控制台输出

### 验证步骤

如果验证失败，按以下步骤排查：

1. **检查服务状态**
   ```bash
   # 检查进程
   ps aux | grep quota-proxy
   
   # 检查Docker容器
   docker ps | grep quota-proxy
   ```

2. **检查日志**
   ```bash
   # Docker容器日志
   docker logs quota-proxy
   
   # 或直接查看服务器日志
   tail -f logs/quota-proxy.log
   ```

3. **手动测试端点**
   ```bash
   # 健康检查
   curl -v http://localhost:8787/healthz
   
   # 试用密钥验证（需要有效的密钥）
   curl -X POST http://localhost:8787/verify \
     -H "Content-Type: application/json" \
     -d '{"key": "your-trial-key"}'
   ```

4. **验证环境变量**
   ```bash
   # 检查管理员令牌
   echo $ADMIN_TOKEN
   
   # 检查数据库文件
   ls -la quota-proxy.db
   ```

## 集成到CI/CD

可以将此脚本集成到持续集成流程中：

```bash
#!/bin/bash
# CI/CD 验证脚本示例

set -e

echo "开始部署验证..."

# 启动服务（如果是CI环境）
./start-sqlite-persistent.sh &
SERVER_PID=$!

# 等待服务启动
sleep 5

# 运行验证
if ./deployment-verification.sh; then
    echo "✅ 部署验证通过"
    exit 0
else
    echo "❌ 部署验证失败"
    # 清理
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi
```

## 相关文档

- [快速开始指南](QUICK-START.md) - 5分钟上手指南
- [SQLite持久化指南](SQLITE-PERSISTENT-GUIDE.md) - 详细配置和使用说明
- [健康检查脚本](quick-sqlite-health-check.sh) - 快速健康检查工具
- [API验证脚本](verify-sqlite-persistent-api.sh) - 完整API验证工具链

## 更新日志

- **v1.0.0** (2026-02-11)
  - 初始版本发布
  - 支持5个关键API端点验证
  - 添加干运行模式和颜色编码输出
  - 集成环境检查（Docker和进程状态）

## 支持

如有问题，请参考：
- [GitHub Issues](https://github.com/1037104428/roc-ai-republic/issues)
- [项目文档](../docs/)
- [快速开始指南](QUICK-START.md)
