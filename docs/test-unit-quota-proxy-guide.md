# Quota-Proxy 单元测试指南

**创建时间**: 2026-02-11 09:59:53 CST  
**最后更新**: 2026-02-11 09:59:53 CST  
**版本**: 1.0.0  

## 概述

本指南介绍如何使用 `test-unit-quota-proxy.sh` 脚本对 quota-proxy 进行单元测试。该脚本提供轻量级的单元测试框架，覆盖 quota-proxy 的核心功能验证。

## 快速开始

### 1. 运行所有单元测试

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
chmod +x ./scripts/test-unit-quota-proxy.sh
./scripts/test-unit-quota-proxy.sh
```

### 2. 查看测试计划（不实际执行）

```bash
./scripts/test-unit-quota-proxy.sh --dry-run
```

### 3. 详细输出模式

```bash
./scripts/test-unit-quota-proxy.sh --verbose
```

### 4. 安静模式（仅输出结果）

```bash
./scripts/test-unit-quota-proxy.sh --quiet
```

## 测试项目详解

### 测试1: 服务器文件存在性检查
- **目的**: 验证必要的服务器文件是否存在
- **检查文件**:
  - `server/server.js` - 主服务器文件
  - `server/server-sqlite.js` - SQLite 服务器文件
  - `server/package.json` - Node.js 依赖配置
  - `server/.env.example` - 环境变量示例

### 测试2: Node.js 依赖检查
- **目的**: 验证 Node.js 和 npm 是否已安装
- **检查项目**:
  - Node.js 版本
  - npm 版本
  - 命令可用性

### 测试3: 环境配置文件检查
- **目的**: 验证环境配置文件的完整性和正确性
- **检查项目**:
  - 必要的环境变量定义（PORT, ADMIN_TOKEN, DATABASE_PATH, LOG_LEVEL）
  - `.env` 文件格式
  - 注释和空行统计

### 测试4: SQLite 数据库功能检查
- **目的**: 验证 SQLite 数据库功能的完整性
- **检查项目**:
  - 必要的模块导入（sqlite3, better-sqlite3, database, quota, usage）
  - 数据库表创建语句（api_keys, usage_logs, admin_logs）
  - 数据库连接和操作逻辑

### 测试5: API 端点定义检查
- **目的**: 验证所有 API 端点是否正确定义
- **检查项目**:
  - 公共 API 端点:
    - `GET /` - 根路径
    - `GET /healthz` - 健康检查
    - `GET /quota/:key` - 获取配额
    - `POST /quota/:key/use` - 使用配额
  - Admin API 端点:
    - `POST /admin/keys` - 生成密钥
    - `GET /admin/keys` - 列出密钥
    - `GET /admin/usage` - 查看使用情况
    - `DELETE /admin/keys/:key` - 删除密钥
    - `PUT /admin/keys/:key` - 更新密钥
    - `POST /admin/reset-usage` - 重置统计

### 测试6: 中间件功能检查
- **目的**: 验证必要的中间件是否配置
- **检查项目**:
  - `express.json()` - JSON 解析
  - `express.urlencoded` - URL 编码解析
  - `rateLimit` - 请求频率限制
  - `adminAuth` - Admin 认证
  - `ipWhitelist` - IP 白名单
  - `requestLogger` - 请求日志记录

### 测试7: 语法检查
- **目的**: 验证 JavaScript 语法正确性
- **检查项目**:
  - Node.js 语法检查 (`node -c`)
  - 语法错误检测

## 输出格式

### 控制台输出
- **INFO** (蓝色): 测试进度和信息
- **SUCCESS** (绿色): 测试通过
- **ERROR** (红色): 测试失败
- **WARNING** (黄色): 测试警告

### 日志文件
所有测试输出都会保存到日志文件:
```
/tmp/quota-proxy-unit-test-YYYYMMDD-HHMMSS.log
```

### 测试结果摘要
测试完成后会显示:
- 总计测试数量
- 通过测试数量
- 失败测试数量
- 最终状态（✅ 通过 / ❌ 失败）

## 使用示例

### 示例1: 基本测试运行
```bash
$ ./scripts/test-unit-quota-proxy.sh
[INFO] 开始 quota-proxy 单元测试
[INFO] 测试时间: Wed Feb 11 09:59:53 CST 2026
[INFO] 项目根目录: /home/kai/.openclaw/workspace/roc-ai-republic
[INFO] 日志文件: /tmp/quota-proxy-unit-test-20260211-095953.log
========================================
[INFO] 运行测试: 服务器文件存在性检查
[INFO] 测试1: 检查服务器文件存在性
[INFO] ✓ 文件存在: server.js
[INFO] ✓ 文件存在: server-sqlite.js
[INFO] ✓ 文件存在: package.json
[INFO] ✓ 文件存在: .env.example
[SUCCESS] 测试通过: 服务器文件存在性检查
...
[INFO] 测试完成
[INFO] 总计测试: 7
[INFO] 通过测试: 7
[INFO] 失败测试: 0
[SUCCESS] 所有测试通过！
✅ 单元测试验证完成，核心功能检查通过
```

### 示例2: 测试失败情况
```bash
$ ./scripts/test-unit-quota-proxy.sh
...
[ERROR] 测试失败: API 端点定义检查
[INFO] 测试完成
[INFO] 总计测试: 7
[INFO] 通过测试: 6
[INFO] 失败测试: 1
[ERROR] 有 1 个测试失败
❌ 单元测试验证失败，请查看日志文件: /tmp/quota-proxy-unit-test-20260211-100000.log
```

### 示例3: 查看测试计划
```bash
$ ./scripts/test-unit-quota-proxy.sh --dry-run
单元测试计划:
1. 服务器文件存在性检查
2. Node.js 依赖检查
3. 环境配置文件检查
4. SQLite 数据库功能检查
5. API 端点定义检查
6. 中间件功能检查
7. 语法检查

总计: 7 个测试项目
```

## 集成到开发流程

### 1. 本地开发验证
在修改 quota-proxy 代码后运行:
```bash
./scripts/test-unit-quota-proxy.sh
```

### 2. CI/CD 集成
在 CI/CD 流水线中添加:
```bash
# 安装依赖
cd server && npm install

# 运行单元测试
../scripts/test-unit-quota-proxy.sh
```

### 3. 预提交检查
在 Git 预提交钩子中添加:
```bash
#!/bin/bash
if ./scripts/test-unit-quota-proxy.sh; then
    echo "✅ 单元测试通过"
    exit 0
else
    echo "❌ 单元测试失败，请修复后再提交"
    exit 1
fi
```

## 故障排除

### 常见问题

#### 1. "Node.js 未安装" 错误
**解决方案**:
```bash
# 安装 Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 验证安装
node --version
npm --version
```

#### 2. "文件不存在" 错误
**解决方案**:
```bash
# 检查文件路径
ls -la server/

# 确保在正确目录
cd /home/kai/.openclaw/workspace/roc-ai-republic
```

#### 3. "语法检查失败" 错误
**解决方案**:
```bash
# 手动检查语法
node -c server/server-sqlite.js

# 查看详细错误
node server/server-sqlite.js
```

#### 4. "环境变量未定义" 错误
**解决方案**:
```bash
# 检查 .env.example 文件
cat server/.env.example

# 创建 .env 文件（如果需要）
cp server/.env.example server/.env
```

### 日志分析
测试失败时，查看日志文件获取详细信息:
```bash
cat /tmp/quota-proxy-unit-test-*.log | grep -A5 -B5 "ERROR\|FAILED"
```

## 最佳实践

### 1. 定期运行测试
- 每次代码修改后运行单元测试
- 提交前确保所有测试通过
- 持续集成环境中自动运行

### 2. 测试覆盖范围
- 核心功能必须通过测试
- 新增功能需要添加对应测试
- 修复 bug 时添加回归测试

### 3. 测试环境
- 使用干净的测试环境
- 避免生产数据污染
- 测试数据隔离

### 4. 性能考虑
- 单元测试应快速执行（< 30秒）
- 避免外部依赖
- 使用模拟数据

## 扩展和自定义

### 添加新测试
要添加新的测试项目，编辑 `test-unit-quota-proxy.sh`:

1. 创建新的测试函数:
```bash
test_new_feature() {
    log_info "测试X: 新功能检查"
    # 测试逻辑
    return 0  # 成功
    # return 1  # 失败
}
```

2. 在主函数中注册测试:
```bash
run_test "新功能检查" test_new_feature
```

### 修改测试配置
可以修改脚本中的配置变量:
- `TEST_DIR`: 测试脚本目录
- `PROJECT_ROOT`: 项目根目录
- `SERVER_DIR`: 服务器目录
- `LOG_FILE`: 日志文件路径

### 输出定制
支持多种输出模式:
- 默认模式: 标准输出
- 详细模式: `--verbose`
- 安静模式: `--quiet`
- 仅计划: `--dry-run`

## 相关文档

- [TODO-quota-proxy-sqlite-improvements.md](./TODO-quota-proxy-sqlite-improvements.md) - 改进清单
- [stress-test-quota-proxy-guide.md](./stress-test-quota-proxy-guide.md) - 压力测试指南
- [test-database-recovery-guide.md](./test-database-recovery-guide.md) - 数据库恢复测试指南
- [集成测试指南](./integration-test-quota-proxy-guide.md) - 完整 API 流程测试

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 7个核心测试项目
- 支持多种输出模式
- 完整的日志记录
- 详细的指南文档

---

**维护者**: 阿爪推进循环  
**状态**: 活跃维护  
**反馈**: 通过项目 Issues 或 Pull Requests 提交反馈