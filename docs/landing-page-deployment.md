# 静态落地页部署指南

本文档介绍如何部署中华AI共和国 / OpenClaw 小白中文包项目的静态落地页。

## 概述

静态落地页是一个响应式网站，提供以下功能：
- 项目介绍和快速开始指南
- 一键安装命令（国内优化版）
- API网关服务（quota-proxy）功能介绍
- 完整的工具链文档链接
- 试用密钥获取方式

## 文件结构

```
web/
├── index.html          # 主页面
└── (未来可添加更多静态资源)
```

## 部署方式

### 1. 使用部署脚本（推荐）

项目提供了自动化部署脚本：

```bash
# 查看帮助
./scripts/deploy-landing-page.sh --help

# 模拟运行（不实际执行）
./scripts/deploy-landing-page.sh --dry-run

# 详细模式部署
./scripts/deploy-landing-page.sh --verbose

# 部署到指定服务器
./scripts/deploy-landing-page.sh --server 192.168.1.100

# 部署到指定目录
./scripts/deploy-landing-page.sh --path /var/www/html
```

### 2. 手动部署

#### 2.1 准备服务器

确保服务器满足以下条件：
- 已安装SSH服务
- 有足够的磁盘空间
- 有Web服务器（Nginx/Caddy/Apache）或计划安装

#### 2.2 上传文件

```bash
# 创建web目录
ssh root@服务器IP "mkdir -p /opt/roc/web"

# 上传文件
scp -r web/* root@服务器IP:/opt/roc/web/
```

#### 2.3 配置Web服务器

##### Nginx配置示例：

```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /opt/roc/web;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # 启用gzip压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
```

##### Caddy配置示例：

```
your-domain.com {
    root * /opt/roc/web
    file_server
    encode gzip
}
```

### 3. 服务器端快速部署

如果已经在服务器上，可以直接从仓库拉取：

```bash
# 克隆仓库
cd /opt/roc
git clone https://github.com/1037104428/roc-ai-republic.git
# 或使用Gitee镜像
git clone https://gitee.com/junkaiWang324/roc-ai-republic.git

# 复制web文件
cp -r roc-ai-republic/web/* /opt/roc/web/
```

## 部署验证

部署完成后，验证步骤：

1. **检查文件是否存在**：
   ```bash
   ssh root@服务器IP "ls -la /opt/roc/web/"
   ```

2. **检查index.html内容**：
   ```bash
   ssh root@服务器IP "head -20 /opt/roc/web/index.html"
   ```

3. **测试Web服务器**：
   ```bash
   curl -I http://服务器IP/
   # 或
   curl -fsS http://服务器IP/healthz
   ```

4. **使用部署脚本验证**：
   ```bash
   ./scripts/deploy-landing-page.sh --dry-run --verbose
   ```

## 配置选项

### 部署脚本选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `-h, --help` | 显示帮助信息 | - |
| `-v, --verbose` | 详细输出模式 | false |
| `-q, --quiet` | 安静模式 | false |
| `-d, --dry-run` | 模拟运行 | false |
| `-s, --server` | 服务器IP地址 | 8.210.185.194 |
| `-p, --path` | 服务器web根目录 | /opt/roc/web |
| `-l, --local` | 本地web目录 | 项目根目录下的web目录 |
| `--skip-ssh-check` | 跳过SSH连接检查 | false |
| `--skip-backup` | 跳过备份现有文件 | false |

### 环境变量

可以通过环境变量覆盖默认值：

```bash
export ROC_SERVER_IP="192.168.1.100"
export ROC_WEB_ROOT="/var/www/html"
export ROC_SSH_KEY="$HOME/.ssh/id_rsa"
```

## 备份与恢复

### 自动备份

部署脚本会自动备份现有文件到 `${WEB_ROOT}.backup.时间戳` 目录。

### 手动备份

```bash
# 备份
ssh root@服务器IP "cp -r /opt/roc/web /opt/roc/web.backup.$(date +%Y%m%d)"

# 恢复
ssh root@服务器IP "rm -rf /opt/roc/web && cp -r /opt/roc/web.backup.时间戳 /opt/roc/web"
```

## 故障排除

### 常见问题

1. **SSH连接失败**
   - 检查服务器IP是否正确
   - 检查SSH密钥是否存在：`ls -la ~/.ssh/id_ed25519_roc_server`
   - 检查防火墙设置
   - 尝试手动连接：`ssh -i ~/.ssh/id_ed25519_roc_server root@服务器IP`

2. **文件上传失败**
   - 检查磁盘空间：`ssh root@服务器IP "df -h"`
   - 检查目录权限：`ssh root@服务器IP "ls -la /opt/roc/"`
   - 尝试使用scp手动上传

3. **Web服务器不响应**
   - 检查Web服务是否运行：`systemctl status nginx` 或 `systemctl status caddy`
   - 检查端口是否开放：`netstat -tlnp | grep :80`
   - 检查防火墙：`firewall-cmd --list-all` 或 `ufw status`

### 调试模式

使用详细模式获取更多信息：

```bash
./scripts/deploy-landing-page.sh --verbose --dry-run
```

## 安全建议

1. **使用HTTPS**
   - 为生产环境配置SSL证书
   - 使用Let's Encrypt免费证书
   - 配置HTTP到HTTPS重定向

2. **访问控制**
   - 配置防火墙，只开放必要端口
   - 使用Web服务器的访问控制功能
   - 定期更新系统和软件

3. **监控与日志**
   - 配置Web服务器日志
   - 设置日志轮转
   - 监控磁盘空间和系统负载

## 更新流程

当需要更新落地页时：

1. 修改本地web文件
2. 测试修改：`./scripts/deploy-landing-page.sh --dry-run`
3. 部署更新：`./scripts/deploy-landing-page.sh --verbose`
4. 验证更新：访问网站检查更改

## 集成到CI/CD

可以将部署脚本集成到CI/CD流程中：

```yaml
# GitHub Actions示例
name: Deploy Landing Page
on:
  push:
    paths:
      - 'web/**'
      - 'scripts/deploy-landing-page.sh'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Server
        run: |
          chmod +x ./scripts/deploy-landing-page.sh
          ./scripts/deploy-landing-page.sh --verbose
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          SERVER_IP: ${{ secrets.SERVER_IP }}
```

## 相关文档

- [quota-proxy 部署指南](../docs/quota-proxy-deployment.md)
- [安装脚本使用指南](../docs/install-cn-guide.md)
- [API 网关文档](../docs/quota-proxy-api.md)
- [工具链概览](../docs/quota-proxy-toolchain-overview.md)

## 支持与反馈

如有问题或建议：
1. 查看项目文档
2. 提交GitHub Issue
3. 联系项目维护者

---

**最后更新**: 2026-02-10  
**版本**: 1.0.0