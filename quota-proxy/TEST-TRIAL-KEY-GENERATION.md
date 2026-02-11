# 试用密钥生成API测试指南

## 概述

`test-trial-key-generation.sh` 脚本是一个用于测试 quota-proxy 服务试用密钥生成功能的工具。它提供了一套完整的测试流程，用于验证试用密钥生成API端点的功能和可用性。

## 功能特性

- ✅ **健康端点测试** - 验证服务基本健康状态
- ✅ **管理员API密钥生成测试** - 测试管理员API密钥生成功能
- ✅ **试用密钥生成测试** - 测试试用密钥生成功能
- ✅ **试用密钥可用性验证** - 验证生成的试用密钥可以正常使用
- ✅ **干运行模式** - 支持预览将要执行的命令而不实际执行
- ✅ **详细输出模式** - 提供详细的执行过程和响应信息
- ✅ **彩色输出** - 使用颜色区分不同级别的信息
- ✅ **灵活的配置** - 支持自定义端口、令牌和URL

## 快速开始

### 1. 确保服务运行

首先确保 quota-proxy 服务正在运行：

```bash
# 检查服务状态
docker compose ps

# 或者使用系统服务
systemctl status quota-proxy
```

### 2. 运行测试脚本

使用默认配置运行测试：

```bash
cd /path/to/roc-ai-republic
./quota-proxy/test-trial-key-generation.sh
```

### 3. 查看测试结果

脚本将输出测试结果，示例如下：

```
[INFO] 开始测试试用密钥生成API端点
[INFO] Base URL: http://127.0.0.1:8787
[INFO] 管理员令牌: test-admin...
[INFO] 测试健康端点: http://127.0.0.1:8787/healthz
[SUCCESS] 健康端点测试通过
[INFO] 测试管理员API密钥生成: http://127.0.0.1:8787/admin/keys
[SUCCESS] 管理员API密钥生成测试通过
[INFO] 生成的API密钥: ak_test_1234567890abcdef
[INFO] 测试试用密钥生成: http://127.0.0.1:8787/admin/trial-keys
[SUCCESS] 试用密钥生成测试通过
[INFO] 生成的试用密钥: tk_test_abcdef1234567890
[INFO] 验证试用密钥可用性
[INFO] 使用试用密钥调用API: http://127.0.0.1:8787/api/usage
[SUCCESS] 试用密钥可用性验证通过

[INFO] 测试总结:
  通过: 4
  失败: 0
  总计: 4
[SUCCESS] 所有测试通过！
```

## 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--port` | `-p` | 指定quota-proxy端口 | `8787` |
| `--token` | `-t` | 指定管理员令牌 | `test-admin-token-123` |
| `--url` | `-u` | 指定完整的base URL | `http://127.0.0.1:8787` |
| `--dry-run` | `-d` | 干运行模式 | `false` |
| `--verbose` | `-v` | 详细输出模式 | `false` |

## 使用示例

### 示例1: 使用默认配置

```bash
./quota-proxy/test-trial-key-generation.sh
```

### 示例2: 自定义端口和令牌

```bash
./quota-proxy/test-trial-key-generation.sh -p 8080 -t "my-secret-admin-token"
```

### 示例3: 干运行模式

```bash
./quota-proxy/test-trial-key-generation.sh --dry-run
```

### 示例4: 详细输出模式

```bash
./quota-proxy/test-trial-key-generation.sh --verbose
```

### 示例5: 指定完整URL

```bash
./quota-proxy/test-trial-key-generation.sh --url "https://api.example.com"
```

## CI/CD集成

### GitHub Actions 示例

```yaml
name: Test Trial Key Generation

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test-trial-key:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Start quota-proxy service
      run: |
        docker compose up -d
        sleep 10  # 等待服务启动
    
    - name: Run trial key generation tests
      run: |
        chmod +x ./quota-proxy/test-trial-key-generation.sh
        ./quota-proxy/test-trial-key-generation.sh --port 8787 --token "${{ secrets.ADMIN_TOKEN }}"
    
    - name: Cleanup
      run: docker compose down
```

### GitLab CI 示例

```yaml
test_trial_key:
  stage: test
  script:
    - docker compose up -d
    - sleep 10
    - chmod +x ./quota-proxy/test-trial-key-generation.sh
    - ./quota-proxy/test-trial-key-generation.sh --port 8787 --token "$ADMIN_TOKEN"
  after_script:
    - docker compose down
```

## 故障排除

### 常见问题

#### 1. 连接被拒绝

**症状**: `curl: (7) Failed to connect to 127.0.0.1 port 8787: Connection refused`

**解决方案**:
- 确保quota-proxy服务正在运行
- 检查端口是否正确
- 验证防火墙设置

```bash
# 检查服务状态
docker compose ps

# 检查端口监听
netstat -tlnp | grep 8787

# 尝试重启服务
docker compose restart
```

#### 2. 认证失败

**症状**: 端点返回 `401 Unauthorized`

**解决方案**:
- 检查管理员令牌是否正确
- 验证令牌是否有足够的权限
- 检查令牌是否已过期

```bash
# 使用正确的令牌
./quota-proxy/test-trial-key-generation.sh -t "correct-admin-token"

# 验证令牌
curl -H "Authorization: Bearer your-token" http://127.0.0.1:8787/healthz
```

#### 3. 端点不存在

**症状**: 端点返回 `404 Not Found`

**解决方案**:
- 检查API端点路径是否正确
- 验证服务版本是否支持该端点
- 检查路由配置

```bash
# 查看所有可用端点
curl http://127.0.0.1:8787/ 2>/dev/null | jq . 2>/dev/null || echo "无法获取端点列表"
```

### 调试技巧

1. **启用详细模式**:
   ```bash
   ./quota-proxy/test-trial-key-generation.sh --verbose
   ```

2. **手动测试端点**:
   ```bash
   # 测试健康端点
   curl -v http://127.0.0.1:8787/healthz
   
   # 测试管理员API密钥生成
   curl -v -X POST -H "Content-Type: application/json" \
     -H "Authorization: Bearer your-token" \
     -d '{"name":"test","quota":1000}' \
     http://127.0.0.1:8787/admin/keys
   ```

3. **检查服务日志**:
   ```bash
   # Docker Compose
   docker compose logs quota-proxy
   
   # 系统服务
   journalctl -u quota-proxy -f
   ```

## 最佳实践

### 1. 测试环境配置

- 在独立的测试环境中运行测试
- 使用测试专用的管理员令牌
- 定期清理测试数据

### 2. 自动化测试

- 将测试集成到CI/CD流水线
- 设置定时测试任务
- 监控测试结果和趋势

### 3. 安全考虑

- 不要在日志中暴露真实的API密钥
- 使用环境变量存储敏感信息
- 定期轮换测试用的管理员令牌

### 4. 性能测试

对于生产环境，建议添加性能测试：

```bash
# 并发测试试用密钥生成
for i in {1..10}; do
  ./quota-proxy/test-trial-key-generation.sh &
done
wait
```

## 相关文档

- [quota-proxy 部署指南](./DEPLOYMENT-GUIDE.md)
- [管理员API文档](./ADMIN-API.md)
- [健康检查脚本](./quick-health-check.sh)
- [环境变量配置验证](./verify-env-config.sh)

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持健康端点测试
- 支持管理员API密钥生成测试
- 支持试用密钥生成测试
- 支持试用密钥可用性验证
- 支持干运行和详细输出模式

## 贡献指南

欢迎提交问题和拉取请求来改进这个测试脚本。

1. Fork 仓库
2. 创建功能分支 (`git checkout -b feature/improvement`)
3. 提交更改 (`git commit -am 'Add some improvement'`)
4. 推送到分支 (`git push origin feature/improvement`)
5. 创建拉取请求

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。
