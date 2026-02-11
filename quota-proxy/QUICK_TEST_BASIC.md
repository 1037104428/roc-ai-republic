# quick-test-basic.sh - 快速测试quota-proxy基本功能

## 概述

`quick-test-basic.sh` 是一个轻量级的quota-proxy功能验证脚本，专为快速测试基本功能而设计。无需复杂配置，只需quota-proxy服务正在运行即可使用。

## 快速开始

### 1. 确保quota-proxy正在运行

```bash
# 启动quota-proxy（使用SQLite版本）
cd /home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy
export DEEPSEEK_API_KEY="your-api-key-here"
node server-sqlite.js
```

### 2. 运行快速测试

```bash
# 授予执行权限（首次运行）
chmod +x quick-test-basic.sh

# 运行快速测试
./quick-test-basic.sh
```

### 3. 查看测试结果

脚本将输出类似以下内容：

```
[INFO] 开始快速测试quota-proxy基本功能
[INFO] 目标地址: http://127.0.0.1:8787
[INFO] 当前时间: 2026-02-11 17:26:52
[INFO] === 测试1: 健康检查 ===
[INFO] 测试: 健康检查 (GET /healthz)
[SUCCESS] 请求成功
  响应: {"ok":true}
...
```

## 功能测试

脚本测试以下基本功能：

1. **健康检查** (`GET /healthz`) - 验证服务是否正常运行
2. **状态查询** (`GET /status`) - 获取服务状态信息
3. **模型列表** (`GET /v1/models`) - 查看支持的模型
4. **TRIAL_KEY要求检查** (`POST /v1/chat/completions`) - 验证是否需要试用密钥

## 命令行选项

```bash
# 显示帮助信息
./quick-test-basic.sh --help

# 干运行模式（只显示命令不执行）
./quick-test-basic.sh --dry-run

# 指定端口和主机
./quick-test-basic.sh --port 8888 --host 192.168.1.100
```

## 使用示例

### 示例1：基本测试
```bash
./quick-test-basic.sh
```

### 示例2：干运行模式（查看将要执行的命令）
```bash
./quick-test-basic.sh --dry-run
```

### 示例3：测试远程服务
```bash
./quick-test-basic.sh --host api.example.com --port 443
```

## 预期输出

成功运行的输出示例：

```
[INFO] 开始快速测试quota-proxy基本功能
[INFO] 目标地址: http://127.0.0.1:8787
[INFO] 当前时间: 2026-02-11 17:26:52
[INFO] === 测试1: 健康检查 ===
[INFO] 测试: 健康检查 (GET /healthz)
[SUCCESS] 请求成功
  响应: {"ok":true}
[INFO] === 测试2: 状态查询 ===
[INFO] 测试: 状态查询 (GET /status)
[SUCCESS] 请求成功
  响应: {"service":"quota-proxy","version":"1.0.0","uptime":123}
[INFO] === 测试3: 模型列表 ===
[INFO] 测试: 模型列表 (GET /v1/models)
[SUCCESS] 请求成功
  响应: {"data":[{"id":"deepseek-chat"},{"id":"deepseek-reasoner"}]}
[INFO] === 测试4: 检查TRIAL_KEY要求 ===
[INFO] 测试: 聊天请求（无密钥） (POST /v1/chat/completions)
[SUCCESS] 请求成功
  响应: {"error":"Missing or invalid TRIAL_KEY"}
[INFO] === 测试总结 ===
[SUCCESS] 快速测试完成
[INFO] 基本功能测试完成，如需完整测试请运行其他验证脚本:
  ./verify-trial-key-api.sh     # 试用密钥API测试
  ./verify-admin-keys-usage.sh  # 管理密钥和使用统计测试
  ./verify-status-endpoint.sh   # 状态端点详细测试
[INFO] 脚本版本: 2026.02.11.1726
[INFO] 完成时间: 2026-02-11 17:26:53
```

## 故障排除

### 常见问题

1. **连接被拒绝**
   ```
   [ERROR] 请求失败: {"error":"curl failed"}
   ```
   **解决方案**: 确保quota-proxy服务正在运行，并且端口正确。

2. **服务未响应**
   **解决方案**: 检查服务日志，确认服务已成功启动。

3. **权限问题**
   ```
   bash: ./quick-test-basic.sh: Permission denied
   ```
   **解决方案**: 运行 `chmod +x quick-test-basic.sh`

### 调试模式

要查看更详细的输出，可以手动运行curl命令：

```bash
# 测试健康检查
curl -v http://127.0.0.1:8787/healthz

# 测试状态查询
curl -v http://127.0.0.1:8787/status
```

## 与其他测试脚本的关系

`quick-test-basic.sh` 是最简单的入门测试脚本。对于更全面的测试，请使用：

- `verify-trial-key-api.sh` - 完整的试用密钥API测试
- `verify-admin-keys-usage.sh` - 管理密钥和使用统计测试
- `verify-status-endpoint.sh` - 状态端点详细测试
- `verify-prometheus-metrics.sh` - Prometheus指标测试

## 版本历史

- **2026.02.11.1726**: 初始版本
  - 添加基本功能测试
  - 支持干运行模式
  - 添加颜色输出和详细日志
  - 创建使用说明文档

## 贡献

欢迎提交问题和改进建议。这是一个轻量级工具，旨在帮助用户快速验证quota-proxy的基本功能。