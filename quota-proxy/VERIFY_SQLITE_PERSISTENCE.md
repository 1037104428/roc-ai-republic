# SQLite持久化功能验证指南

## 概述

`verify-sqlite-persistence.sh` 是一个专门用于验证 quota-proxy 项目中 SQLite 数据库持久化功能是否正常工作的验证脚本。该脚本提供全面的数据库功能验证，确保数据持久化机制可靠运行。

## 快速开始

### 基本使用

```bash
# 进入项目目录
cd /path/to/roc-ai-republic

# 运行完整验证
./quota-proxy/verify-sqlite-persistence.sh

# 干运行模式（只显示检查项）
./quota-proxy/verify-sqlite-persistence.sh --dry-run

# 安静模式（只显示错误信息）
./quota-proxy/verify-sqlite-persistence.sh --quiet
```

### 一键验证

```bash
# 最简验证
cd /home/kai/.openclaw/workspace/roc-ai-republic && ./quota-proxy/verify-sqlite-persistence.sh
```

## 功能特性

### 1. 数据库文件检查
- 检查 SQLite 数据库文件是否存在
- 验证文件大小和修改时间
- 提供文件状态信息

### 2. 表结构验证
- 验证数据库表结构是否正确
- 检查主键、外键约束
- 验证字段类型和默认值

### 3. 数据持久化测试
- 测试数据插入功能
- 验证数据保存和读取
- 检查事务处理能力

### 4. 数据库连接测试
- 测试数据库连接是否正常
- 验证 SQL 查询执行
- 检查错误处理机制

## 命令行选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--dry-run` | 干运行模式，只显示检查项不执行实际验证 | false |
| `--quiet` | 安静模式，只显示错误信息 | false |
| `--help` | 显示帮助信息 | - |

## 使用示例

### 示例 1：完整验证
```bash
./quota-proxy/verify-sqlite-persistence.sh
```
输出示例：
```
[INFO] 开始验证SQLite持久化功能
[INFO] 当前时间: 2026-02-11 17:53:53
[INFO] 工作目录: /home/kai/.openclaw/workspace/roc-ai-republic
[INFO] 1. 检查SQLite数据库文件
[SUCCESS] 数据库文件存在: quota.db
[INFO] 文件大小: 48K
[INFO] 修改时间: 2026-02-11 17:45:00.000000000 +0800
[INFO] 2. 检查数据库表结构
[SUCCESS] 测试数据库表结构创建成功
[INFO] 数据库表: api_keys usage_logs
[INFO] 3. 验证数据持久化
[SUCCESS] 测试数据插入成功
[INFO] 测试数据记录数: 3
[SUCCESS] 数据持久化验证通过
[INFO] 4. 检查数据库连接
[SUCCESS] 数据库连接测试成功
[SUCCESS] SQLite持久化功能验证完成
[SUCCESS] 所有验证项目通过
```

### 示例 2：干运行模式
```bash
./quota-proxy/verify-sqlite-persistence.sh --dry-run
```
只显示检查项，不执行实际数据库操作。

### 示例 3：CI/CD 集成
```bash
# 在CI流水线中运行
./quota-proxy/verify-sqlite-persistence.sh --quiet
if [ $? -eq 0 ]; then
    echo "SQLite持久化验证通过"
else
    echo "SQLite持久化验证失败"
    exit 1
fi
```

## 故障排除

### 常见问题

1. **数据库文件不存在**
   ```
   [WARNING] 数据库文件不存在: quota.db
   ```
   解决方案：确保 quota-proxy 服务已启动并创建了数据库文件。

2. **表结构验证失败**
   ```
   [ERROR] 测试数据库表结构创建失败
   ```
   解决方案：检查 SQLite3 是否已安装，或数据库文件权限是否正确。

3. **数据持久化测试失败**
   ```
   [ERROR] 数据持久化验证失败: 期望3条记录，实际0条
   ```
   解决方案：检查数据库连接和 SQL 语法。

### 调试模式

```bash
# 启用详细输出
set -x
./quota-proxy/verify-sqlite-persistence.sh
set +x
```

## 相关文档

- [SQLite示例脚本快速验证指南](./VERIFY_SQLITE_EXAMPLE_QUICK.md)
- [环境变量配置指南](./ENV_CONFIGURATION_GUIDE.md)
- [快速部署指南](./QUICK_DEPLOYMENT_GUIDE.md)
- [验证脚本索引](../../docs/VERIFICATION_SCRIPTS_INDEX.md)

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-02-11 | 初始版本，包含基本验证功能 |
| | | 添加数据库文件检查 |
| | | 添加表结构验证 |
| | | 添加数据持久化测试 |
| | | 添加数据库连接测试 |

## 维护说明

### 脚本位置
- 主脚本：`quota-proxy/verify-sqlite-persistence.sh`
- 文档：`quota-proxy/VERIFY_SQLITE_PERSISTENCE.md`

### 依赖项
- Bash 4.0+
- SQLite3 3.20+
- 标准 Unix 工具（date, stat, du, grep 等）

### 测试覆盖
- 单元测试：通过脚本自验证
- 集成测试：与 quota-proxy 服务集成
- 回归测试：定期运行确保功能正常

## 贡献指南

欢迎提交问题和改进建议。请确保：
1. 遵循现有代码风格
2. 添加相应的测试用例
3. 更新文档和版本历史
4. 通过现有验证脚本测试

---

**最后更新**: 2026-02-11  
**维护者**: 中华AI共和国项目组  
**状态**: 生产就绪 ✅
