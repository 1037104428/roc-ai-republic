# 站点健康检查脚本指南

## 概述

`check-site-health.sh` 是一个轻量级的站点健康检查工具，用于快速验证中华AI共和国 / OpenClaw 小白中文包项目站点的部署状态和基本功能。

## 功能特性

- ✅ **站点可访问性检查** - 验证站点是否返回 HTTP 200
- ✅ **主页面内容检查** - 检查主页面是否包含预期内容
- ✅ **关键页面检查** - 验证下载页、快速开始、试用密钥指南等关键页面
- ✅ **响应时间检查** - 测量站点响应时间（需要 `bc` 命令）
- ✅ **详细报告** - 提供清晰的检查结果和问题定位
- ✅ **灵活配置** - 支持命令行参数和环境变量配置

## 快速开始

### 1. 授予执行权限

```bash
chmod +x ./scripts/check-site-health.sh
```

### 2. 基本使用

检查默认站点 (http://localhost:8080):

```bash
./scripts/check-site-health.sh
```

### 3. 指定站点URL

```bash
./scripts/check-site-health.sh --url http://example.com
```

或使用环境变量:

```bash
SITE_URL=http://example.com ./scripts/check-site-health.sh
```

### 4. 详细输出模式

```bash
./scripts/check-site-health.sh --url http://localhost:8080 --verbose
```

## 命令行参数

| 参数 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--url` | `-u` | 站点URL | `http://localhost:8080` |
| `--timeout` | `-t` | 超时时间(秒) | `10` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--help` | `-h` | 显示帮助信息 | - |

## 环境变量

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `SITE_URL` | 站点URL | `http://localhost:8080` |
| `TIMEOUT` | 超时时间(秒) | `10` |
| `VERBOSE` | 详细输出模式 | `false` |

## 检查项目详解

### 1. 站点可访问性检查
- 使用 `curl` 检查站点是否返回 HTTP 200
- 这是关键检查，失败会导致脚本立即退出

### 2. 主页面内容检查
- 检查主页面是否包含 "中华AI共和国" 文本
- 验证基本内容是否正确部署

### 3. 关键页面检查
检查以下关键页面是否存在且包含预期内容:
- **下载页** (`downloads.html`) - 包含 "下载 OpenClaw"
- **快速开始** (`quickstart.html`) - 包含 "快速开始"
- **试用密钥指南** (`trial-key-guide.html`) - 包含 "试用密钥"

### 4. 响应时间检查
- 测量从请求到响应的总时间
- 需要 `bc` 命令支持数学运算
- 如果响应时间超过超时设置，会发出警告

## 退出码说明

| 退出码 | 含义 | 建议操作 |
|--------|------|----------|
| `0` | 所有检查通过 | 站点状态良好 |
| `1` | 参数错误 | 检查命令行参数 |
| `2` | 站点不可访问 | 检查站点部署和网络连接 |
| `3` | 关键页面缺失 | 检查页面部署完整性 |
| `4` | 静态资源问题 | 检查静态资源部署 |
| `5` | 响应时间过长 | 优化站点性能 |

## 使用示例

### 示例1: 快速检查本地开发环境

```bash
./scripts/check-site-health.sh --url http://localhost:3000 --timeout 5
```

### 示例2: 检查生产环境站点

```bash
./scripts/check-site-health.sh \
  --url https://roc-ai-republic.example.com \
  --timeout 15 \
  --verbose
```

### 示例3: 集成到部署脚本中

```bash
#!/bin/bash
# deploy-site.sh

# 部署站点...
echo "部署站点..."

# 检查部署结果
if ./scripts/check-site-health.sh --url "$DEPLOY_URL"; then
    echo "✅ 站点部署成功，健康检查通过"
else
    echo "❌ 站点部署存在问题"
    exit 1
fi
```

## 最佳实践

### 1. 自动化部署验证
将健康检查集成到 CI/CD 流程中，确保每次部署后站点功能正常。

### 2. 定期监控
使用 cron 定期运行健康检查，及时发现站点问题:

```bash
# 每小时检查一次
0 * * * * cd /path/to/roc-ai-republic && ./scripts/check-site-health.sh --url https://your-site.com >> /var/log/site-health.log 2>&1
```

### 3. 告警集成
根据退出码设置告警机制，当检查失败时发送通知。

### 4. 性能基准
记录正常的响应时间作为基准，当响应时间异常增长时发出警告。

## 故障排除

### 问题1: "命令 'curl' 未安装"
**解决方案**: 安装 curl:
```bash
# Ubuntu/Debian
sudo apt-get install curl

# CentOS/RHEL
sudo yum install curl

# macOS
brew install curl
```

### 问题2: "bc命令未安装，跳过响应时间检查"
**解决方案**: 安装 bc:
```bash
# Ubuntu/Debian
sudo apt-get install bc

# CentOS/RHEL
sudo yum install bc

# macOS
brew install bc
```

### 问题3: 站点访问超时
**可能原因**:
1. 站点未启动
2. 网络连接问题
3. 防火墙阻止

**解决方案**:
- 检查站点服务状态
- 验证网络连接
- 检查防火墙规则

### 问题4: 页面内容检查失败
**可能原因**:
1. 页面未正确部署
2. 页面内容已更新
3. 字符编码问题

**解决方案**:
- 检查页面文件是否存在
- 更新检查脚本中的预期内容
- 验证字符编码设置

## 扩展功能

### 自定义检查项目
您可以修改脚本添加自定义检查项目:

```bash
# 在 check_page_content 函数后添加自定义检查
check_custom_page() {
    local url="${SITE_URL}/custom-page.html"
    local pattern="自定义内容"
    
    if check_page_content "$url" "$pattern" "自定义页面"; then
        log_success "自定义页面检查通过"
        return 0
    else
        log_warning "自定义页面检查失败"
        return 1
    fi
}
```

### 性能监控集成
将响应时间数据发送到监控系统:

```bash
# 获取响应时间数据
response_time=$(./scripts/check-site-health.sh --url "$SITE_URL" --quiet | grep "响应时间" | awk '{print $2}')

# 发送到监控系统
send_to_monitoring "site.response_time" "$response_time"
```

## 更新记录

### v1.0.0 (2026-02-11)
- 初始版本发布
- 基础站点健康检查功能
- 支持命令行参数和环境变量
- 详细的检查报告和退出码

## 相关资源

- [站点部署指南](./landing-page-deployment.md)
- [Web服务器配置验证](./web-server-config-verification.md)
- [站点验证脚本](./verify-landing-page.md)

---

**提示**: 定期运行健康检查可以确保站点始终处于良好状态，及时发现并解决问题。