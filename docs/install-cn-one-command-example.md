# install-cn.sh 一键安装示例

本文档展示 `install-cn.sh` 安装脚本的最简单使用方式，适合快速上手。

## 🚀 最简单的一键安装

### 方法1：直接运行（自动选择最佳版本）
```bash
# 下载脚本
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh -o install-cn.sh

# 赋予执行权限
chmod +x install-cn.sh

# 一键安装最新版OpenClaw
./install-cn.sh
```

### 方法2：使用国内镜像加速
```bash
# 使用国内镜像源（自动选择最快的registry）
./install-cn.sh --force-cn
```

### 方法3：安装特定版本
```bash
# 安装稳定版本
./install-cn.sh --version 0.3.12

# 安装最新开发版
./install-cn.sh --version latest
```

## 📋 安装过程示例

正常安装输出示例：
```
🔍 检测系统环境...
✅ 系统: Linux x86_64
✅ Node.js: v22.22.0
✅ npm: 10.9.0

🌐 选择最佳npm registry...
✅ 使用 registry: https://registry.npmmirror.com

📦 安装 OpenClaw...
✅ 下载包: openclaw@0.3.12
✅ 安装完成！

🔧 配置 OpenClaw...
✅ 配置文件已创建: /home/user/.openclaw/config.json
✅ 工作目录已创建: /home/user/.openclaw/workspace

✅ 安装成功！OpenClaw 0.3.12 已就绪。
💡 运行命令: openclaw --help
```

## 🔍 快速验证安装

安装完成后，运行以下命令验证：

```bash
# 检查版本
openclaw --version

# 查看帮助
openclaw --help

# 检查状态
openclaw status
```

## ⚡ 高级选项

### 干运行模式（测试而不安装）
```bash
# 测试安装过程，不实际执行
./install-cn.sh --dry-run

# 测试特定版本
./install-cn.sh --dry-run --version 0.3.12
```

### 自定义安装路径
```bash
# 安装到自定义目录
./install-cn.sh --prefix /opt/openclaw
```

### 跳过环境检查
```bash
# 跳过系统环境检查（谨慎使用）
./install-cn.sh --skip-checks
```

## 🛠️ 故障排除

### 常见问题

1. **权限不足**
   ```bash
   # 使用sudo（如果需要）
   sudo ./install-cn.sh
   ```

2. **网络连接问题**
   ```bash
   # 强制使用国内源
   ./install-cn.sh --force-cn
   
   # 或手动设置代理
   export HTTP_PROXY=http://your-proxy:port
   export HTTPS_PROXY=http://your-proxy:port
   ./install-cn.sh
   ```

3. **Node.js版本过低**
   ```bash
   # 检查Node.js版本
   node --version
   
   # 需要Node.js 18+
   # 使用nvm升级：https://github.com/nvm-sh/nvm
   ```

### 获取帮助
```bash
# 查看完整帮助
./install-cn.sh --help

# 查看版本信息
./install-cn.sh --version
```

## 📚 下一步

安装完成后，建议：
1. 阅读 [OpenClaw 官方文档](https://docs.openclaw.ai)
2. 配置 [quota-proxy API网关](../quota-proxy/README.md)
3. 获取 [试用密钥](../quota-proxy/TRIAL_KEY_QUICK_EXAMPLE.md)

---

**版本**: 2026.02.11  
**更新**: 为中华AI共和国项目提供最简单的一键安装示例