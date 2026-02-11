# Enhanced ROC Public Endpoints Verification Script

## 概述

`verify-roc-public-enhanced.sh` 是一个增强版的 ROC 公共端点验证脚本，提供全面的 landing page 和 API 端点验证功能，包含详细的报告和多种验证选项。

## 功能特性

### 核心验证功能
- **基础可用性检查**: 验证 landing page 和 API health 端点的基本可用性
- **SSL 证书验证**: 可选验证 SSL 证书有效性
- **重定向验证**: 可选跟随和验证重定向行为
- **响应头验证**: 可选验证响应头信息
- **内容验证**: 可选验证响应内容

### 输出选项
- **详细模式**: 显示详细的请求和响应信息
- **安静模式**: 仅显示错误信息
- **JSON 输出**: 以 JSON 格式输出验证结果
- **干运行模式**: 显示将要执行的检查而不实际发送请求

### 错误处理
- 详细的错误信息和诊断输出
- 适当的退出码表示不同错误类型
- 颜色编码的输出便于快速识别状态

## 快速开始

### 基本用法
```bash
# 使用默认配置验证
./scripts/verify-roc-public-enhanced.sh

# 使用自定义超时
./scripts/verify-roc-public-enhanced.sh --timeout 5

# 使用自定义 URL
./scripts/verify-roc-public-enhanced.sh https://clawdrepublic.cn https://api.clawdrepublic.cn
```

### 高级用法
```bash
# 启用详细输出和 SSL 检查
./scripts/verify-roc-public-enhanced.sh --verbose --check-ssl

# 输出 JSON 格式结果
./scripts/verify-roc-public-enhanced.sh --json

# 干运行模式（仅显示将要执行的检查）
./scripts/verify-roc-public-enhanced.sh --dry-run

# 安静模式（仅显示错误）
./scripts/verify-roc-public-enhanced.sh --quiet
```

### 一键验证（远程执行）
```bash
# GitHub 源
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/verify-roc-public-enhanced.sh | bash

# Gitee 源
curl -fsSL https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/scripts/verify-roc-public-enhanced.sh | bash
```

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--timeout N` | 请求超时时间（秒） | 10 |
| `--verbose` | 启用详细输出 | false |
| `--quiet` | 抑制非错误输出 | false |
| `--dry-run` | 干运行模式 | false |
| `--json` | JSON 格式输出 | false |
| `--check-ssl` | 验证 SSL 证书 | false |
| `--check-redirect` | 跟随和验证重定向 | false |
| `--check-headers` | 验证响应头 | false |
| `--check-content` | 验证响应内容 | false |
| `--help` | 显示帮助信息 | - |

## 环境变量

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `TIMEOUT` | 默认请求超时时间 | 10 |

## 退出码

| 退出码 | 描述 |
|--------|------|
| 0 | 所有检查通过 |
| 1 | 一个或多个检查失败 |
| 2 | 无效参数 |
| 3 | 网络/DNS 错误 |

## 使用示例

### 示例 1: 基础验证
```bash
./scripts/verify-roc-public-enhanced.sh
```
输出:
```
=== ROC Public Endpoints Verification ===
Timestamp: 2026-02-11 18:25:00 CST
Configuration:
  Timeout: 10s
  Home URL: https://clawdrepublic.cn
  API Base URL: https://api.clawdrepublic.cn
  SSL Check: false
  Redirect Check: false
  Headers Check: false
  Content Check: false

[CHECK] Landing page availability: https://clawdrepublic.cn
  ✓ PASS: Landing page availability
[CHECK] API health endpoint: https://api.clawdrepublic.cn/healthz
  ✓ PASS: API health endpoint

=== Verification Summary ===
Total checks: 2
Passed: 2
Failed: 0
✓ All checks passed!
```

### 示例 2: 详细模式 + SSL 检查
```bash
./scripts/verify-roc-public-enhanced.sh --verbose --check-ssl
```

### 示例 3: JSON 输出
```bash
./scripts/verify-roc-public-enhanced.sh --json
```
输出:
```json
{
  "timestamp": "2026-02-11T18:25:00+08:00",
  "configuration": {
    "timeout": 10,
    "home_url": "https://clawdrepublic.cn",
    "api_base_url": "https://api.clawdrepublic.cn",
    "check_ssl": false,
    "check_redirect": false,
    "check_headers": false,
    "check_content": false
  },
  "results": [
    {"check":"landing_page","status":"pass"},
    {"check":"api_health","status":"pass"}
  ],
  "summary": {
    "total": 2,
    "passed": 2,
    "failed": 0,
    "success": true
  }
}
```

## CI/CD 集成

### GitHub Actions 示例
```yaml
name: Verify ROC Public Endpoints
on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
        
      - name: Verify public endpoints
        run: |
          chmod +x scripts/verify-roc-public-enhanced.sh
          ./scripts/verify-roc-public-enhanced.sh --json --check-ssl
```

### 定时监控
```bash
# 添加到 crontab 进行定时监控
*/15 * * * * cd /path/to/roc-ai-republic && ./scripts/verify-roc-public-enhanced.sh --quiet --json --check-ssl >> /var/log/roc-monitor.log 2>&1
```

## 故障排除

### 常见问题

#### 1. 连接超时
```bash
# 增加超时时间
./scripts/verify-roc-public-enhanced.sh --timeout 30

# 检查网络连接
curl -v https://clawdrepublic.cn
```

#### 2. SSL 证书错误
```bash
# 禁用 SSL 检查（临时）
./scripts/verify-roc-public-enhanced.sh --check-ssl=false

# 检查证书详情
openssl s_client -connect clawdrepublic.cn:443 -servername clawdrepublic.cn
```

#### 3. DNS 解析失败
```bash
# 检查 DNS 解析
nslookup clawdrepublic.cn
dig clawdrepublic.cn

# 使用 IP 地址直接测试
./scripts/verify-roc-public-enhanced.sh https://<IP_ADDRESS> https://<API_IP_ADDRESS>
```

### 调试模式
```bash
# 启用详细输出查看详细信息
./scripts/verify-roc-public-enhanced.sh --verbose

# 使用 curl 手动测试
curl -v -m 10 https://clawdrepublic.cn
curl -v -m 10 https://api.clawdrepublic.cn/healthz
```

## 维护说明

### 定期检查项目
- [ ] 验证脚本功能正常
- [ ] 更新默认 URL（如有变更）
- [ ] 测试所有命令行选项
- [ ] 验证 CI/CD 集成

### 发布前验证流程
1. 运行基础验证: `./scripts/verify-roc-public-enhanced.sh`
2. 运行完整验证: `./scripts/verify-roc-public-enhanced.sh --verbose --check-ssl --check-redirect`
3. 验证 JSON 输出: `./scripts/verify-roc-public-enhanced.sh --json`
4. 验证远程执行: `curl -fsSL ... | bash`

### 问题响应流程
1. 收集错误信息: `./scripts/verify-roc-public-enhanced.sh --verbose 2>&1`
2. 检查网络连接: `ping clawdrepublic.cn`
3. 检查服务状态: 联系运维团队
4. 更新文档: 记录解决方案

## 相关文档

- [README.md](../README.md) - 项目主文档
- [verify-roc-public.sh](./verify-roc-public.sh) - 基础验证脚本
- [quota-proxy 部署文档](../quota-proxy/README.md) - API 服务部署指南
- [验证脚本体系文档](./README-verification-scripts.md) - 完整验证脚本体系说明

## 版本历史

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持基础可用性检查
- 支持 SSL 证书验证
- 支持多种输出格式
- 完整的错误处理和诊断信息

### 待实现功能
- [ ] 支持代理配置
- [ ] 添加性能基准测试
- [ ] 支持地理位置检查
- [ ] 添加历史趋势分析

---

**最后更新**: 2026-02-11  
**维护者**: ROC 工程团队  
**反馈渠道**: GitHub Issues 或论坛