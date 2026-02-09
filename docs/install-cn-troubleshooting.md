# install-cn.sh 安装验证与故障排除指南

## 快速验证安装成功

安装完成后，立即运行以下命令验证：

```bash
# 验证 openclaw 命令可用
openclaw --version

# 验证配置文件目录存在
ls -la ~/.openclaw/

# 验证 workspace 目录存在
ls -la ~/.openclaw/workspace/
```

期望输出示例：
```
$ openclaw --version
0.3.12
```

## 常见问题排查

### 1. Node.js 版本过低（< 20）

**症状**：`openclaw --version` 报错或安装失败

**解决**：
```bash
# 检查当前 Node.js 版本
node --version

# 如果版本 < 20，需要升级 Node.js
# 方法1：使用 nvm（推荐）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
# 重新打开终端后
nvm install --lts
nvm use --lts

# 方法2：使用 NodeSource（Ubuntu/Debian）
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. npm 权限问题（EACCES）

**症状**：安装时出现 `EACCES: permission denied` 错误

**解决**：
```bash
# 方法1：使用 --dry-run 检查
./scripts/install-cn.sh --dry-run

# 方法2：使用本地安装（不推荐，但可作为临时方案）
npm install openclaw@latest --no-audit --no-fund
# 然后手动创建软链接
ln -s "$(pwd)/node_modules/.bin/openclaw" ~/.local/bin/openclaw

# 方法3：修复 npm 权限（推荐长期方案）
# 使用 npm 的修复工具
npm install -g npm@latest
# 或者使用 nvm 重新安装
```

### 3. 网络连接问题（registry 不可达）

**症状**：安装超时或网络错误

**解决**：
```bash
# 测试 registry 连通性
curl -fsS https://registry.npmmirror.com/openclaw -I

# 如果 npmmirror 不可用，尝试其他国内源
./scripts/install-cn.sh --registry-cn https://mirrors.cloud.tencent.com/npm/

# 或者强制使用 npmjs（国际源）
./scripts/install-cn.sh --registry-cn https://registry.npmjs.org --registry-fallback https://registry.npmjs.org
```

### 4. 安装成功但命令找不到

**症状**：`openclaw: command not found`

**解决**：
```bash
# 检查 npm 全局 bin 目录
npm config get prefix

# 将该目录添加到 PATH
# 对于 bash/zsh
echo 'export PATH="$PATH:$(npm config get prefix)/bin"' >> ~/.bashrc
source ~/.bashrc

# 对于 fish
echo 'set -gx PATH $PATH (npm config get prefix)/bin' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish

# 验证路径
which openclaw
```

### 5. 版本冲突或损坏

**症状**：`openclaw --version` 显示奇怪版本或报错

**解决**：
```bash
# 完全卸载后重新安装
npm uninstall -g openclaw

# 清理缓存
npm cache clean --force

# 重新安装
./scripts/install-cn.sh --version latest
```

## 高级调试

### 查看安装日志
```bash
# 启用详细日志
NPM_DEBUG=1 ./scripts/install-cn.sh --version latest

# 或保存日志到文件
./scripts/install-cn.sh --version latest 2>&1 | tee install.log
```

### 检查环境变量
```bash
# 查看所有相关环境变量
env | grep -E "(NODE|NPM|OPENCLAW)"

# 检查 npm 配置
npm config list
```

### 验证安装完整性
```bash
# 创建验证脚本
cat > verify-openclaw.sh << 'EOF'
#!/usr/bin/env bash
set -e

echo "=== OpenClaw 安装完整性验证 ==="
echo "1. 检查命令是否存在..."
which openclaw || { echo "❌ openclaw 命令未找到"; exit 1; }
echo "✅ openclaw 命令位置: $(which openclaw)"

echo "2. 检查版本..."
openclaw --version || { echo "❌ 无法获取版本"; exit 1; }
echo "✅ 版本获取成功"

echo "3. 检查配置文件目录..."
ls -la ~/.openclaw/ || { echo "❌ 配置文件目录不存在"; exit 1; }
echo "✅ 配置文件目录存在"

echo "4. 检查 workspace..."
ls -la ~/.openclaw/workspace/ || { echo "❌ workspace 目录不存在"; exit 1; }
echo "✅ workspace 目录存在"

echo "5. 运行简单状态检查..."
openclaw status --help >/dev/null 2>&1 || { echo "❌ 状态检查失败"; exit 1; }
echo "✅ 基本功能正常"

echo "=== 所有检查通过 ✅ ==="
EOF

chmod +x verify-openclaw.sh
./verify-openclaw.sh
```

## 一键验证脚本

仓库中已提供验证脚本：

```bash
# 运行安装验证
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-install-cn.sh --dry-run

# 实际验证（需要已安装）
./scripts/verify-install-cn.sh
```

## 获取帮助

如果以上方法都无法解决问题：

1. **查看脚本帮助**：
   ```bash
   ./scripts/install-cn.sh --help
   ```

2. **在论坛发帖求助**：
   - 访问：https://clawdrepublic.cn/forum/
   - 在"问题求助"板块发帖
   - 附上：操作系统版本、Node.js版本、完整错误日志

3. **检查已知问题**：
   - 查看 `docs/tickets.md` 中的已知问题
   - 检查 GitHub/Gitee Issues

## 贡献与反馈

如果发现脚本问题或改进建议：

1. 在仓库提交 Issue
2. 或直接修改 `scripts/install-cn.sh` 并提交 Pull Request
3. 文档改进：修改 `docs/install-cn-troubleshooting.md`

记住：安装问题通常与网络环境或系统配置有关，耐心排查通常都能解决。