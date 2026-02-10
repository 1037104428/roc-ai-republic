# 网络诊断工具文档

## 概述

`diagnose-network.sh` 是一个专为 OpenClaw CN 用户设计的网络诊断工具，帮助用户快速识别和解决网络连接问题，特别是在国内网络环境下可能遇到的访问限制。

## 功能特性

### 1. 全面的网络测试
- **npm 注册表测试**: 检查国内镜像和国际镜像的可达性
- **代码仓库测试**: 验证 GitHub 和 Gitee 的访问状态
- **API 服务测试**: 测试 quota-proxy API 和论坛页面的可用性
- **DNS 解析测试**: 检查关键域名的 DNS 解析情况

### 2. 智能诊断
- 自动检测代理设置
- 提供详细的故障排除建议
- 支持多种测试模式（全部、部分、详细输出）

### 3. 用户友好
- 彩色输出，清晰区分信息级别
- 中文界面，降低使用门槛
- 逐步指导，从检测到修复

## 使用方法

### 基本使用
```bash
# 运行所有网络测试
./scripts/diagnose-network.sh --all

# 只测试 npm 注册表
./scripts/diagnose-network.sh --npm

# 显示详细输出
./scripts/diagnose-network.sh --all --verbose

# 获取帮助
./scripts/diagnose-network.sh --help
```

### 环境变量
```bash
# 设置代理
export HTTP_PROXY=http://proxy:8080
export HTTPS_PROXY=http://proxy:8080
export NO_PROXY=localhost,127.0.0.1

# 运行诊断
./scripts/diagnose-network.sh --all
```

## 测试项目详解

### 1. npm 注册表测试
- **国内镜像**: `https://registry.npmmirror.com`
- **国际镜像**: `https://registry.npmjs.org`
- **测试方法**: 发送 HTTP 请求检查服务状态

### 2. 代码仓库测试
- **GitHub Raw**: `https://raw.githubusercontent.com`
- **Gitee Raw**: `https://gitee.com`
- **目的**: 验证安装脚本和文档的可访问性

### 3. API 服务测试
- **quota-proxy API**: `https://api.clawdrepublic.cn/healthz`
- **论坛页面**: `https://clawdrepublic.cn/forum/`
- **注意**: API 可能需要有效的 TRIAL_KEY

### 4. DNS 解析测试
测试以下关键域名的 DNS 解析：
- `registry.npmmirror.com`
- `registry.npmjs.org`
- `raw.githubusercontent.com`
- `gitee.com`
- `api.clawdrepublic.cn`
- `clawdrepublic.cn`

## 输出说明

### 颜色编码
- **蓝色**: 信息性消息
- **绿色**: 成功/正常状态
- **黄色**: 警告/需要注意
- **红色**: 错误/严重问题

### 信息级别
- `[INFO]`: 一般信息
- `[SUCCESS]`: 测试通过
- `[WARNING]`: 测试失败但可继续
- `[ERROR]`: 测试失败需要处理

## 故障排除指南

### 常见问题及解决方案

#### 1. npm 注册表不可达
**症状**: npm 安装失败，国内和国际镜像都不可用

**解决方案**:
```bash
# 检查网络连接
ping registry.npmmirror.com

# 尝试使用代理
export HTTP_PROXY=http://your-proxy:8080
./scripts/diagnose-network.sh --npm

# 手动设置 npm 注册表
npm config set registry https://registry.npmmirror.com
```

#### 2. GitHub 访问缓慢
**症状**: GitHub Raw 响应慢或超时

**解决方案**:
```bash
# 使用 Gitee 镜像
export GITHUB_MIRROR=https://gitee.com/mirrors

# 修改 hosts 文件（临时加速）
echo "199.232.68.133 raw.githubusercontent.com" | sudo tee -a /etc/hosts

# 使用代理
export HTTPS_PROXY=http://proxy:8080
```

#### 3. DNS 解析失败
**症状**: 域名无法解析，返回 "unknown host"

**解决方案**:
```bash
# 使用公共 DNS
echo "nameserver 114.114.114.114" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# 刷新 DNS 缓存
sudo systemctl restart systemd-resolved  # systemd
sudo dscacheutil -flushcache            # macOS
ipconfig /flushdns                      # Windows
```

#### 4. 代理配置问题
**症状**: 设置了代理但连接仍然失败

**解决方案**:
```bash
# 验证代理设置
echo $HTTP_PROXY
echo $HTTPS_PROXY

# 测试代理连接
curl -x http://proxy:8080 https://registry.npmjs.org

# 临时禁用代理
unset HTTP_PROXY HTTPS_PROXY NO_PROXY
```

#### 5. 防火墙限制
**症状**: 本地网络正常，但特定服务无法访问

**解决方案**:
```bash
# 检查防火墙规则
sudo iptables -L -n

# 测试端口连通性
nc -zv registry.npmjs.org 443

# 联系网络管理员
# 可能需要企业网络策略调整
```

## 集成使用

### 1. 与 install-cn.sh 集成
```bash
# 在安装前运行网络诊断
./scripts/diagnose-network.sh --all

# 根据诊断结果调整安装参数
./scripts/install-cn.sh --registry-fallback https://registry.npmjs.org
```

### 2. 自动化脚本集成
```bash
#!/bin/bash
# 自动化安装脚本示例

# 运行网络诊断
if ./scripts/diagnose-network.sh --npm --quiet; then
    echo "网络正常，开始安装..."
    ./scripts/install-cn.sh
else
    echo "网络异常，使用备用方案..."
    ./scripts/install-offline.sh
fi
```

### 3. CI/CD 集成
```yaml
# GitHub Actions 示例
name: Network Diagnosis
on: [push, pull_request]

jobs:
  network-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run network diagnosis
        run: ./scripts/diagnose-network.sh --all
      - name: Install OpenClaw
        if: success()
        run: ./scripts/install-cn.sh
```

## 高级功能

### 1. 自定义测试目标
```bash
# 添加自定义测试目标
export CUSTOM_TEST_URLS="https://your-api.com/healthz,https://your-site.com"
./scripts/diagnose-network.sh --all
```

### 2. 输出格式控制
```bash
# JSON 格式输出（未来版本）
./scripts/diagnose-network.sh --all --format json > network-report.json

# 简洁模式
./scripts/diagnose-network.sh --all --quiet
```

### 3. 定时监控
```bash
# 创建定时监控任务
crontab -e
# 每30分钟运行一次网络诊断
*/30 * * * * /path/to/roc-ai-republic/scripts/diagnose-network.sh --all --quiet >> /var/log/network-monitor.log
```

## 最佳实践

### 1. 安装前诊断
```bash
# 推荐在安装 OpenClaw 前运行网络诊断
cd /path/to/roc-ai-republic
./scripts/diagnose-network.sh --all

# 根据结果选择合适的安装选项
if grep -q "国内镜像可达" network-diagnosis.log; then
    ./scripts/install-cn.sh
else
    ./scripts/install-cn.sh --registry-fallback https://registry.npmjs.org
fi
```

### 2. 故障排查流程
1. **运行完整诊断**: `./scripts/diagnose-network.sh --all`
2. **查看详细输出**: `./scripts/diagnose-network.sh --all --verbose`
3. **应用建议修复**: 按照输出中的建议操作
4. **重新测试**: 修复后再次运行诊断
5. **记录结果**: 保存诊断日志供技术支持参考

### 3. 网络优化建议
- **使用国内镜像**: 优先使用 `registry.npmmirror.com`
- **配置代理**: 在企业网络中使用代理服务器
- **DNS 优化**: 使用稳定的公共 DNS 服务
- **网络缓存**: 考虑设置本地 npm 缓存代理

## 技术支持

### 1. 获取帮助
- **查看文档**: `docs/` 目录下的相关文档
- **论坛求助**: https://clawdrepublic.cn/forum/
- **GitHub Issues**: https://github.com/openclaw/openclaw/issues

### 2. 报告问题
```bash
# 收集诊断信息
./scripts/diagnose-network.sh --all --verbose > diagnosis.log

# 包含系统信息
uname -a >> diagnosis.log
node --version >> diagnosis.log
npm --version >> diagnosis.log

# 提交问题报告时附上 diagnosis.log
```

### 3. 贡献指南
欢迎贡献代码改进网络诊断工具：
1. Fork 仓库
2. 创建功能分支
3. 提交 Pull Request
4. 包含测试用例和文档更新

## 版本历史

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持 npm、GitHub/Gitee、API、DNS 测试
- 提供中文故障排除建议
- 彩色输出和详细日志

### 未来计划
- 支持更多测试类型（端口扫描、延迟测试）
- 添加图形界面版本
- 集成到 OpenClaw CLI
- 支持更多网络协议（WebSocket、gRPC）

---

**注意**: 本工具仅用于诊断网络连接问题，不收集或上传任何用户数据。所有测试都在本地进行，结果仅显示在终端中。