# 状态监控页面部署指南

## 概述

状态监控页面是一个静态 HTML 页面，用于展示 quota-proxy 服务的实时状态、API 接入信息和快速验证命令。这是优先级 C（站点）的基础组件。

## 功能特性

- ✅ 实时显示 quota-proxy 服务状态
- ✅ API 网关接入信息展示
- ✅ 快速验证命令生成
- ✅ 文档链接整合
- ✅ 响应式设计，支持移动端
- ✅ 一键部署到服务器

## 部署步骤

### 1. 生成状态页面

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/create-quota-proxy-status-page.sh
```

页面将生成到 `/tmp/quota-proxy-status.html`

### 2. 部署到服务器

```bash
# 干运行模式（预览命令）
./scripts/deploy-status-page.sh --dry-run

# 实际部署
./scripts/deploy-status-page.sh
```

### 3. 验证部署

```bash
# 检查服务器上的文件
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 'ls -la /opt/roc/web/'

# 本地预览
python3 -m http.server 8080 --directory /tmp/ &
xdg-open http://localhost:8080/quota-proxy-status.html
```

## 文件结构

```
/opt/roc/web/
├── quota-proxy-status.html          # 状态监控页面
└── (后续添加更多静态资源)
```

## 自动化脚本

### deploy-status-page.sh

一键部署脚本，功能包括：
- 自动生成状态页面
- 检查服务器配置
- 部署到服务器 `/opt/roc/web/` 目录
- 提供验证命令

### create-quota-proxy-status-page.sh

状态页面生成脚本，功能包括：
- 从环境变量和配置文件读取信息
- 生成美观的 HTML 页面
- 包含实时状态检查
- 提供 API 接入指南

## 后续集成

### 与 Caddy/Nginx 集成

状态页面可以作为静态站点的基础，后续可配置：

```nginx
# Nginx 示例配置
server {
    listen 80;
    server_name status.roc-ai-republic.cn;
    
    location / {
        root /opt/roc/web;
        index quota-proxy-status.html;
    }
}
```

### 与 landing page 集成

状态页面可作为 landing page 的一部分，提供：
1. 服务状态监控
2. API 文档
3. 下载入口
4. 安装指南

## 故障排除

### 问题：服务器连接失败

```bash
# 检查服务器配置
cat /tmp/server.txt

# 测试 SSH 连接
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 'echo "连接成功"'
```

### 问题：状态页面未生成

```bash
# 检查脚本权限
chmod +x scripts/create-quota-proxy-status-page.sh

# 手动运行生成
cd scripts && ./create-quota-proxy-status-page.sh
```

### 问题：部署权限不足

```bash
# 检查服务器目录权限
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 'ls -la /opt/roc/'
```

## 更新与维护

### 更新状态页面

```bash
# 重新生成并部署
./scripts/create-quota-proxy-status-page.sh
./scripts/deploy-status-page.sh
```

### 添加新功能

1. 修改 `create-quota-proxy-status-page.sh` 脚本
2. 更新 HTML 模板部分
3. 测试生成效果
4. 部署到服务器

## 安全考虑

- 状态页面为静态 HTML，不包含敏感信息
- API key 和 token 不会暴露在页面中
- 管理员接口仍受 ADMIN_TOKEN 保护
- 建议通过 HTTPS 访问

## 性能优化

- 页面为纯静态，加载速度快
- 可配置 CDN 加速
- 支持浏览器缓存
- 响应式设计，适配各种设备