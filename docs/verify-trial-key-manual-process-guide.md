# TRIAL_KEY手动发放流程验证指南

本文档详细说明如何使用验证脚本测试TRIAL_KEY手动发放流程的各个步骤。

## 概述

`verify-trial-key-manual-process.sh` 脚本用于验证 `TRIAL_KEY_MANUAL_PROCESS.md` 文档中描述的手动发放流程。脚本会测试以下关键功能：

1. **服务健康检查** - 验证quota-proxy服务是否正常运行
2. **Web管理界面访问** - 测试管理界面可访问性
3. **curl命令行创建密钥** - 验证POST /admin/keys接口
4. **数据库操作测试** - 验证SQLite数据库可访问性
5. **密钥列表获取** - 验证GET /admin/keys接口
6. **使用情况统计** - 验证GET /admin/usage接口
7. **密钥可用性测试** - 验证创建的密钥是否可用

## 快速开始

### 基本用法

```bash
# 进入项目目录
cd /path/to/roc-ai-republic

# 运行验证脚本
./scripts/verify-trial-key-manual-process.sh
```

### 指定服务器配置

```bash
# 指定服务器地址和管理员令牌
./scripts/verify-trial-key-manual-process.sh \
  -H 192.168.1.100 \
  -p 8787 \
  -t "your-admin-token-here"
```

### 模拟运行模式

```bash
# 模拟运行，不实际执行操作
./scripts/verify-trial-key-manual-process.sh -n -v
```

## 详细说明

### 脚本选项

| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--host` | `-H` | 服务器主机名或IP | `localhost` |
| `--port` | `-p` | 服务器端口 | `8787` |
| `--token` | `-t` | 管理员令牌 | `test-admin-token-123` |
| `--db-path` | `-d` | SQLite数据库路径 | `quota.db` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--dry-run` | `-n` | 模拟运行模式 | `false` |
| `--no-cleanup` | - | 不清理测试数据 | `false` |

### 环境变量

脚本也支持通过环境变量配置：

```bash
# 设置环境变量
export HOST="192.168.1.100"
export PORT="8787"
export ADMIN_TOKEN="your-admin-token"
export VERBOSE="true"

# 运行脚本（会自动使用环境变量）
./scripts/verify-trial-key-manual-process.sh
```

### 退出码

| 退出码 | 说明 |
|--------|------|
| 0 | 所有测试通过 |
| 1 | 参数错误或帮助信息 |
| 2 | 必需命令缺失（如curl） |
| 3 | 服务健康检查失败 |
| 4 | 密钥创建失败 |
| 5 | 其他测试失败 |

## 测试流程详解

### 1. 服务健康检查
脚本首先检查quota-proxy服务是否正常运行：
```bash
curl -fsS http://localhost:8787/healthz
```
期望响应：`{"ok":true}`

### 2. Web管理界面访问测试
检查管理界面是否可访问：
```bash
curl -fsS http://localhost:8787/admin
```

### 3. curl命令行创建密钥
测试POST /admin/keys接口：
```bash
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer admin-token" \
  -H "Content-Type: application/json" \
  -d '{"label": "测试密钥", "daily_limit": 100}'
```

### 4. 数据库操作测试
验证SQLite数据库可访问性：
```bash
sqlite3 quota.db "SELECT COUNT(*) FROM api_keys;"
```

### 5. 密钥列表获取测试
测试GET /admin/keys接口：
```bash
curl -H "Authorization: Bearer admin-token" \
  http://localhost:8787/admin/keys
```

### 6. 使用情况统计测试
测试GET /admin/usage接口：
```bash
curl -H "Authorization: Bearer admin-token" \
  http://localhost:8787/admin/usage
```

### 7. 密钥可用性测试
验证创建的密钥是否可用：
```bash
curl -H "Authorization: Bearer trial-key" \
  http://localhost:8787/usage
```

## 使用场景

### 场景1：部署后验证
在部署quota-proxy服务后，使用脚本验证所有功能是否正常：

```bash
# 部署后完整验证
./scripts/verify-trial-key-manual-process.sh -v
```

### 场景2：故障排查
当手动发放流程出现问题时，使用脚本定位问题：

```bash
# 详细模式帮助定位问题
./scripts/verify-trial-key-manual-process.sh -v --no-cleanup
```

### 场景3：CI/CD集成
在持续集成流程中自动验证：

```bash
# 在CI/CD流水线中运行
export ADMIN_TOKEN="${{ secrets.ADMIN_TOKEN }}"
./scripts/verify-trial-key-manual-process.sh || exit 1
```

### 场景4：演示和培训
用于演示手动发放流程的各个步骤：

```bash
# 模拟运行，展示所有步骤
./scripts/verify-trial-key-manual-process.sh -n -v
```

## 最佳实践

### 1. 安全注意事项
- 不要在脚本中硬编码真实的管理员令牌
- 使用环境变量或配置文件管理敏感信息
- 定期轮换管理员令牌

### 2. 测试数据管理
- 脚本默认会自动清理测试数据
- 使用`--no-cleanup`选项保留测试数据用于调试
- 定期检查数据库中的测试数据

### 3. 监控集成
- 将验证脚本集成到监控系统中
- 设置定期自动验证（如每小时一次）
- 配置告警机制，当验证失败时通知管理员

### 4. 性能考虑
- 验证脚本设计为轻量级，执行时间通常在几秒钟内
- 避免在高负载时段运行验证
- 考虑使用`--dry-run`模式进行预检查

## 故障排除

### 常见问题

#### 问题1：服务健康检查失败
**症状**：脚本在第一步就失败
**可能原因**：
- quota-proxy服务未运行
- 端口配置错误
- 防火墙阻止访问

**解决方案**：
```bash
# 检查服务状态
docker compose ps

# 检查端口监听
netstat -tlnp | grep 8787

# 测试本地连接
curl http://localhost:8787/healthz
```

#### 问题2：管理员令牌无效
**症状**：密钥创建失败，返回401错误
**可能原因**：
- 管理员令牌错误
- 令牌未正确设置
- 服务配置问题

**解决方案**：
```bash
# 检查环境变量
echo $ADMIN_TOKEN

# 检查服务配置
cat .env | grep ADMIN_TOKEN

# 重新设置令牌
export ADMIN_TOKEN="new-token"
docker compose restart
```

#### 问题3：数据库访问失败
**症状**：数据库操作测试失败
**可能原因**：
- 数据库文件不存在
- 文件权限问题
- 表结构不匹配

**解决方案**：
```bash
# 检查数据库文件
ls -la quota.db

# 检查文件权限
stat quota.db

# 检查表结构
sqlite3 quota.db ".tables"
```

#### 问题4：网络连接问题
**症状**：所有curl请求都失败
**可能原因**：
- 网络配置问题
- DNS解析失败
- 代理设置问题

**解决方案**：
```bash
# 测试网络连接
ping server-ip

# 测试端口连通性
telnet server-ip 8787

# 检查代理设置
echo $http_proxy
```

### 调试技巧

1. **启用详细模式**：使用`-v`选项查看详细输出
2. **模拟运行**：使用`-n`选项查看将要执行的操作
3. **分步测试**：手动执行脚本中的各个curl命令
4. **查看日志**：检查quota-proxy服务日志
5. **使用网络工具**：使用tcpdump或Wireshark分析网络流量

## 与相关文档的关联

### TRIAL_KEY_MANUAL_PROCESS.md
验证脚本直接对应手动发放流程文档中的各个步骤：
- 第3.1节：Web管理界面 → `test_web_interface_access()`
- 第3.2节：curl命令行 → `test_curl_create_key()`
- 第3.3节：数据库操作 → `test_database_operations()`
- 第6.1节：密钥列表 → `test_get_keys_list()`
- 第6.2节：使用统计 → `test_usage_stats()`

### QUICKSTART.md
验证脚本可以作为快速开始指南的补充，确保用户按照指南操作后所有功能正常。

### ADMIN-INTERFACE.md
验证脚本测试了管理接口文档中描述的所有关键接口。

## 扩展和定制

### 添加新测试
要添加新的测试用例，可以在脚本中添加新的测试函数：

```bash
test_new_feature() {
    print_info "测试新功能..."
    # 测试逻辑
}
```

然后在`run_all_tests()`函数中调用新函数。

### 集成到现有工具链
脚本可以与其他验证脚本集成：

```bash
# 在现有验证流程中调用
./scripts/verify-quota-proxy-deployment.sh
./scripts/verify-trial-key-manual-process.sh
./scripts/verify-admin-ui.sh
```

### 自动化调度
使用cron定时运行验证：

```bash
# 每小时运行一次验证
0 * * * * cd /path/to/roc-ai-republic && ./scripts/verify-trial-key-manual-process.sh >> /var/log/quota-verify.log 2>&1
```

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0.0 | 2026-02-10 | 初始版本，包含7个核心测试 |

## 贡献指南

欢迎提交改进建议和问题报告：

1. 在GitHub仓库创建Issue
2. 提交Pull Request
3. 更新测试用例和文档

## 联系和支持

- 项目仓库：https://github.com/1037104428/roc-ai-republic
- 问题反馈：GitHub Issues
- 相关文档：查看`docs/`目录下的其他文档

---

**最后更新**：2026-02-10  
**维护者**：Clawd团队  
**相关脚本**：`verify-quota-proxy-deployment.sh`, `verify-admin-ui.sh`  
**相关文档**：`TRIAL_KEY_MANUAL_PROCESS.md`, `QUICKSTART.md`, `ADMIN-INTERFACE.md`