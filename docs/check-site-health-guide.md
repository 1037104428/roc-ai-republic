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

## 站点部署验证示例

### 示例1: 快速验证本地静态站点部署

```bash
#!/bin/bash
# verify-static-site-deployment.sh
# 快速验证静态站点部署的完整示例

# 配置参数
SITE_URL="http://localhost:8080"
SITE_DIR="./web/landing-page"
LOG_FILE="/tmp/site-deployment-verify-$(date +%Y%m%d-%H%M%S).log"

echo "=== 静态站点部署验证开始 ===" | tee -a "$LOG_FILE"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "站点URL: $SITE_URL" | tee -a "$LOG_FILE"
echo "站点目录: $SITE_DIR" | tee -a "$LOG_FILE"

# 1. 检查站点目录是否存在
echo -e "\n[1/5] 检查站点目录..." | tee -a "$LOG_FILE"
if [ -d "$SITE_DIR" ]; then
    echo "✅ 站点目录存在: $SITE_DIR" | tee -a "$LOG_FILE"
    echo "   文件数量: $(find "$SITE_DIR" -type f | wc -l)" | tee -a "$LOG_FILE"
    echo "   目录大小: $(du -sh "$SITE_DIR" | cut -f1)" | tee -a "$LOG_FILE"
else
    echo "❌ 站点目录不存在: $SITE_DIR" | tee -a "$LOG_FILE"
    exit 1
fi

# 2. 检查关键文件
echo -e "\n[2/5] 检查关键文件..." | tee -a "$LOG_FILE"
REQUIRED_FILES=("index.html" "downloads.html" "quickstart.html" "trial-key-guide.html")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$SITE_DIR/$file" ]; then
        echo "✅ 关键文件存在: $file" | tee -a "$LOG_FILE"
    else
        echo "❌ 关键文件缺失: $file" | tee -a "$LOG_FILE"
    fi
done

# 3. 启动简单HTTP服务器（如果未运行）
echo -e "\n[3/5] 检查HTTP服务器..." | tee -a "$LOG_FILE"
if ! pgrep -f "python3 -m http.server" > /dev/null; then
    echo "启动HTTP服务器在端口8080..." | tee -a "$LOG_FILE"
    cd "$SITE_DIR" && python3 -m http.server 8080 > /dev/null 2>&1 &
    SERVER_PID=$!
    echo "HTTP服务器已启动 (PID: $SERVER_PID)" | tee -a "$LOG_FILE"
    sleep 2  # 等待服务器启动
else
    echo "✅ HTTP服务器已在运行" | tee -a "$LOG_FILE"
fi

# 4. 运行健康检查
echo -e "\n[4/5] 运行站点健康检查..." | tee -a "$LOG_FILE"
if ./scripts/check-site-health.sh --url "$SITE_URL" --timeout 5 --verbose; then
    echo "✅ 站点健康检查通过" | tee -a "$LOG_FILE"
else
    echo "❌ 站点健康检查失败" | tee -a "$LOG_FILE"
    # 清理
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
    exit 1
fi

# 5. 验证API网关集成
echo -e "\n[5/5] 验证API网关集成..." | tee -a "$LOG_FILE"
if curl -fsS "http://localhost:8787/healthz" > /dev/null 2>&1; then
    echo "✅ API网关健康检查通过" | tee -a "$LOG_FILE"
else
    echo "⚠️ API网关未运行或不可访问" | tee -a "$LOG_FILE"
fi

# 清理
[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null

echo -e "\n=== 静态站点部署验证完成 ===" | tee -a "$LOG_FILE"
echo "详细日志: $LOG_FILE" | tee -a "$LOG_FILE"
echo "✅ 所有验证项目通过，站点部署成功！" | tee -a "$LOG_FILE"
```

### 示例2: 生产环境站点部署验证清单

```bash
#!/bin/bash
# production-site-verification-checklist.sh
# 生产环境站点部署验证清单

VERIFICATION_STEPS=(
    "1. DNS解析验证: dig +short your-domain.com"
    "2. SSL证书验证: openssl s_client -connect your-domain.com:443 -servername your-domain.com 2>/dev/null | openssl x509 -noout -dates"
    "3. HTTP重定向验证: curl -I http://your-domain.com | grep -i 'location\|http'"
    "4. HTTPS访问验证: curl -fsS https://your-domain.com > /dev/null && echo 'HTTPS访问正常'"
    "5. 站点健康检查: ./scripts/check-site-health.sh --url https://your-domain.com --timeout 10"
    "6. 关键页面验证: 手动访问 https://your-domain.com/downloads.html"
    "7. API网关集成: curl -fsS https://your-domain.com/api/healthz"
    "8. 性能基准测试: ab -n 100 -c 10 https://your-domain.com/"
    "9. 移动端兼容性: 使用浏览器开发者工具模拟移动设备访问"
    "10. SEO基础检查: curl -s https://your-domain.com | grep -i 'title\|meta.*description'"
)

echo "=== 生产环境站点部署验证清单 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "域名: your-domain.com"
echo ""

for step in "${VERIFICATION_STEPS[@]}"; do
    echo "$step"
    read -p "  完成? (y/n/skip): " answer
    case $answer in
        y|Y) echo "   ✅ 已完成" ;;
        n|N) echo "   ❌ 未完成" ;;
        s|S) echo "   ⏭️  已跳过" ;;
        *) echo "   ❓ 未知状态" ;;
    esac
    echo ""
done

echo "=== 验证完成 ==="
echo "建议: 保存此清单作为部署文档的一部分"
```

### 示例3: CI/CD集成示例

```yaml
# .github/workflows/deploy-verify.yml
name: Deploy and Verify Site

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  deploy-and-verify:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y curl bc
    
    - name: Build static site
      run: |
        mkdir -p dist
        cp -r web/landing-page/* dist/
        echo "站点构建完成: $(ls -la dist/)"
    
    - name: Start test server
      run: |
        cd dist && python3 -m http.server 8080 &
        echo "测试服务器启动中..."
        sleep 3
    
    - name: Run site health check
      run: |
        ./scripts/check-site-health.sh \
          --url http://localhost:8080 \
          --timeout 10 \
          --verbose
    
    - name: Verify deployment
      if: success()
      run: |
        echo "✅ 站点部署验证通过"
        echo "部署时间: $(date)"
        echo "提交: ${{ github.sha }}"
```

## 相关资源

- [站点部署指南](./landing-page-deployment.md)
- [Web服务器配置验证](./web-server-config-verification.md)
- [站点验证脚本](./verify-landing-page.md)

---

**提示**: 定期运行健康检查可以确保站点始终处于良好状态，及时发现并解决问题。