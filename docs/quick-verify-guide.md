# OpenClaw 快速验证指南

## 概述

`quick-verify-openclaw.sh` 是一个安装后验证脚本，帮助用户快速确认 OpenClaw 安装是否成功，并检查基本功能是否正常。

## 使用场景

1. **安装后验证**：运行一键安装脚本后，使用此脚本验证安装结果
2. **故障排查**：当 OpenClaw 出现问题时，使用此脚本定位问题
3. **环境检查**：在新机器上部署前，检查环境是否符合要求

## 快速开始

### 从仓库运行

```bash
# 进入仓库目录
cd /path/to/roc-ai-republic

# 运行验证脚本
./scripts/quick-verify-openclaw.sh
```

### 从网络运行（如果已安装）

```bash
# 下载验证脚本
curl -fsSL https://clawdrepublic.cn/quick-verify-openclaw.sh -o quick-verify.sh
chmod +x quick-verify.sh

# 运行
./quick-verify.sh
```

## 验证项目

脚本会检查以下项目：

### 1. 命令可用性
- 检查 `openclaw` 命令是否在 PATH 中
- 如果未找到，提供排查建议

### 2. 版本信息
- 运行 `openclaw --version` 获取版本信息
- 验证版本输出格式是否正确

### 3. 基本状态
- 运行 `openclaw status` 检查服务状态
- 首次运行可能提示需要初始化

### 4. 网络连通性（可选）
- 测试中华AI共和国官网可访问性
- 测试 API 网关健康检查端点
- 测试安装脚本源可下载性

## 命令行选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--help` | 显示帮助信息 | - |
| `--verbose` | 显示详细输出 | 关闭 |
| `--skip-network` | 跳过网络测试 | 关闭 |
| `--skip-version` | 跳过版本检查 | 关闭 |
| `--skip-status` | 跳过状态检查 | 关闭 |

## 使用示例

### 完整验证（推荐）
```bash
./scripts/quick-verify-openclaw.sh
```

### 仅验证本地功能（不测试网络）
```bash
./scripts/quick-verify-openclaw.sh --skip-network
```

### 详细输出模式
```bash
./scripts/quick-verify-openclaw.sh --verbose
```

### 仅检查命令和版本
```bash
./scripts/quick-verify-openclaw.sh --skip-network --skip-status
```

## 输出解读

### 成功输出示例
```
=== OpenClaw 快速验证开始 ===
时间: 2026-02-09 23:50:52 CST

[1/4] 检查 openclaw 命令...
✓ openclaw 命令找到: /usr/local/bin/openclaw

[2/4] 检查版本信息...
✓ 版本检查通过: openclaw/0.3.12 linux-x64 node-v22.22.0

[3/4] 检查基本状态...
✓ 状态检查通过

[4/4] 网络连通性测试...
  测试官网连通性...
  ✓ 官网可访问
  测试API网关连通性...
  ✓ API网关健康检查通过
  测试安装脚本源...
  ✓ 安装脚本可下载

=== 验证完成 ===
总结:
  - openclaw 命令: ✓ 可用
  - 版本检查: ✓ 通过
  - 状态检查: ✓ 通过
  - 网络测试: ✓ 完成（详见上方）
```

### 失败情况处理

#### 情况1：openclaw 命令未找到
```
✗ openclaw 命令未找到
提示:
  - 确保已运行 'source ~/.bashrc' 或 'source ~/.zshrc'
  - 或使用 'npx openclaw' 运行
```

**解决方案**：
1. 重新打开终端
2. 运行 `source ~/.bashrc` 或 `source ~/.zshrc`
3. 检查 npm 全局路径：`npm bin -g`

#### 情况2：版本检查失败
```
✗ 无法获取版本信息
提示:
  - 尝试: npx openclaw --version
  - 或重新运行安装脚本
```

**解决方案**：
1. 使用 npx 运行：`npx openclaw --version`
2. 重新运行安装脚本

#### 情况3：状态检查失败
```
⚠ 状态检查失败（可能是首次运行）
提示:
  - 首次运行可能需要初始化配置
  - 运行 'openclaw gateway start' 启动服务
```

**解决方案**：
1. 运行 `openclaw gateway start` 启动服务
2. 检查配置文件：`~/.openclaw/openclaw.json`

#### 情况4：网络测试失败
```
⚠ 官网访问失败（可能网络问题）
⚠ API网关访问失败
```

**解决方案**：
1. 检查网络连接
2. 使用 `--skip-network` 跳过网络测试
3. 如果是国内网络问题，等待重试或使用代理

## 与 install-cn.sh 集成

安装脚本会在安装完成后提示使用验证脚本：

```bash
# 安装完成后会看到提示
[cn-pack] Next steps:
1) Create/verify config: ~/.openclaw/openclaw.json
2) Add DeepSeek provider snippet (see docs/openclaw-cn-pack-deepseek-v0.md)
3) Start gateway: openclaw gateway start
4) Verify: openclaw status && openclaw models status
5) Quick verification: ./scripts/quick-verify-openclaw.sh (if in repo)
```

## 自动化集成

### CI/CD 管道
```yaml
# GitHub Actions 示例
- name: Verify OpenClaw installation
  run: |
    curl -fsSL https://clawdrepublic.cn/quick-verify-openclaw.sh | bash -s -- --skip-network
```

### 部署后检查
```bash
# 部署后自动验证
deploy_openclaw() {
  # 安装步骤...
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
  
  # 验证安装
  ./scripts/quick-verify-openclaw.sh --skip-network
  
  echo "部署完成"
}
```

## 故障排除

### 常见问题

#### Q1: 脚本提示权限不足
```
bash: ./scripts/quick-verify-openclaw.sh: Permission denied
```
**解决**：`chmod +x scripts/quick-verify-openclaw.sh`

#### Q2: curl 下载失败
```
curl: (7) Failed to connect to clawdrepublic.cn port 443: Connection refused
```
**解决**：使用 `--skip-network` 选项，或检查网络连接

#### Q3: 脚本在 Windows 上无法运行
**解决**：使用 Git Bash、WSL 或 Linux 环境运行

#### Q4: 验证通过但实际无法使用
**解决**：
1. 检查配置文件：`~/.openclaw/openclaw.json`
2. 检查 TRIAL_KEY：`echo $CLAWD_TRIAL_KEY`
3. 查看日志：`openclaw gateway logs`

## 贡献与反馈

如果发现脚本问题或有改进建议：
1. 在论坛发帖：https://clawdrepublic.cn/forum/
2. 提交 Issue：https://github.com/1037104428/roc-ai-republic/issues
3. 提交 Pull Request

## 更新日志

- **v1.0.0** (2026-02-09): 初始版本
  - 基础命令验证
  - 版本检查
  - 状态检查
  - 网络连通性测试
  - 详细输出选项

## 相关资源

- [OpenClaw 官网](https://clawdrepublic.cn/)
- [一键安装脚本](https://clawdrepublic.cn/install-cn.sh)
- [安装指南](docs/install-cn-guide.md)
- [故障排除](docs/install-cn-troubleshooting.md)
- [网络指南](docs/install-cn-network-guide.md)