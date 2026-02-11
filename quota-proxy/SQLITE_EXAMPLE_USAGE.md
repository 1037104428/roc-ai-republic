# SQLite 示例脚本使用说明

## 概述

`sqlite-example.py` 是一个完整的 QuotaDatabase 类实现，为 quota-proxy 提供 SQLite 持久化的参考实现。该脚本演示了如何管理 API 密钥、跟踪使用量、检查配额以及提供管理接口。

## 快速开始

### 1. 运行示例

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy
python3 sqlite-example.py
```

脚本将自动：
- 创建或连接到 SQLite 数据库
- 演示所有核心功能
- 输出详细的执行结果

### 2. 核心功能演示

脚本演示以下功能：

1. **数据库初始化** - 创建必要的表和索引
2. **API 密钥管理** - 创建、查询、删除 API 密钥
3. **使用量跟踪** - 记录和查询 API 使用情况
4. **配额检查** - 验证 API 密钥是否超出配额限制
5. **管理接口** - 管理员功能演示

### 3. 命令行参数

```bash
# 显示帮助信息
python3 sqlite-example.py --help

# 运行演示模式（默认）
python3 sqlite-example.py --demo

# 指定自定义数据库文件
python3 sqlite-example.py --db /path/to/custom.db

# 静默模式（仅输出错误）
python3 sqlite-example.py --quiet
```

## 类结构

### QuotaDatabase 类

主要方法：

```python
class QuotaDatabase:
    def __init__(self, db_path=":memory:", verbose=True)
    def initialize_database(self)
    def create_api_key(self, key_id, user_id="default", quota_daily=100, quota_monthly=1000)
    def get_api_key(self, key_id)
    def delete_api_key(self, key_id)
    def record_usage(self, key_id, model="gpt-4", tokens=100, cost=0.01)
    def get_usage(self, key_id, days=30)
    def check_quota(self, key_id)
    def get_all_keys(self)
    def reset_usage(self, key_id)
    def get_database_stats(self)
```

### 使用示例

```python
# 初始化数据库
db = QuotaDatabase("quota.db")

# 创建 API 密钥
db.create_api_key("test-key-123", "user-1", 100, 1000)

# 记录使用量
db.record_usage("test-key-123", "gpt-4", 150, 0.015)

# 检查配额
quota_status = db.check_quota("test-key-123")
print(f"配额状态: {quota_status}")

# 获取使用统计
usage = db.get_usage("test-key-123", 7)
print(f"7天内使用量: {usage}")
```

## 验证脚本

项目提供了验证脚本确保示例脚本的质量：

```bash
# 运行验证脚本
./scripts/verify-sqlite-example.sh

# 干运行模式（预览验证步骤）
./scripts/verify-sqlite-example.sh --dry-run

# 快速验证模式
./scripts/verify-sqlite-example.sh --quick
```

验证脚本检查以下内容：
- 文件存在性和权限
- 脚本语法和导入
- 演示模式功能
- 实际数据库操作
- 代码质量

## 集成到 quota-proxy

要将此示例集成到实际的 quota-proxy 服务中：

1. **复制核心逻辑** - 将 `QuotaDatabase` 类复制到你的项目中
2. **调整数据库路径** - 使用环境变量或配置文件指定数据库路径
3. **集成到服务器** - 在 Express.js 服务器中初始化数据库实例
4. **添加错误处理** - 增强生产环境的错误处理和日志记录
5. **性能优化** - 考虑连接池和查询优化

## 故障排除

### 常见问题

1. **Python 依赖缺失**
   ```bash
   pip install sqlite3  # SQLite3 是 Python 标准库，通常不需要安装
   ```

2. **权限问题**
   ```bash
   chmod +x sqlite-example.py
   chmod +w .  # 确保有数据库文件写入权限
   ```

3. **数据库锁定**
   - 确保没有其他进程正在使用数据库文件
   - 检查文件权限和所有权

### 调试模式

启用详细输出以调试问题：

```bash
python3 sqlite-example.py --verbose
```

## 下一步

1. **阅读完整文档** - 查看脚本内的详细注释和文档字符串
2. **运行验证** - 使用验证脚本确保一切正常
3. **集成测试** - 将示例集成到你的应用程序中进行测试
4. **性能测试** - 测试在高负载下的性能表现
5. **备份策略** - 实现数据库备份和恢复机制

## 支持

如有问题，请参考：
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - 故障排除指南
- [README.md](./README.md) - 主文档
- 项目 Issues - 报告问题和功能请求