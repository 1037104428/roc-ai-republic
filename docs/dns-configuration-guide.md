# DNS 配置指南 - forum.clawdrepublic.cn

## 问题描述

论坛子域名 `forum.clawdrepublic.cn` 当前无法通过 HTTPS 访问，原因是 DNS 记录不存在（NXDOMAIN）。Caddy 无法为不存在的域名申请 Let's Encrypt SSL 证书。

## 解决方案

### 方案A：添加 DNS A 记录（推荐）

在您的域名管理面板（如阿里云、腾讯云、Cloudflare 等）中添加以下 DNS 记录：

```
类型: A
名称: forum
值: 8.210.185.194
TTL: 300 (5分钟) 或 3600 (1小时)
```

**验证命令：**
```bash
# 添加后等待 DNS 传播（通常 5-60 分钟）
dig forum.clawdrepublic.cn +short
# 应该返回: 8.210.185.194

# 测试 HTTPS 访问
curl -fsS -m 5 https://forum.clawdrepublic.cn/ | grep -q "Clawd 国度论坛" && echo "✅ 论坛正常"
```

### 方案B：使用通配符证书（如果已有 `*.clawdrepublic.cn`）

如果主域名 `clawdrepublic.cn` 已经配置了通配符证书，修改 Caddy 配置使用该证书：

1. 编辑服务器上的 `/etc/caddy/Caddyfile`：
```caddy
forum.clawdrepublic.cn {
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
    reverse_proxy 127.0.0.1:8081
    # ... 其他配置
}
```

2. 重新加载 Caddy：
```bash
caddy reload --config /etc/caddy/Caddyfile
```

### 方案C：临时使用自签名证书（仅测试）

对于测试环境，可以使用自签名证书：

```bash
# 生成自签名证书
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes -subj "/CN=forum.clawdrepublic.cn"

# 修改 Caddy 配置使用该证书
cat >> /etc/caddy/Caddyfile << 'EOF'
forum.clawdrepublic.cn {
    tls /path/to/cert.pem /path/to/key.pem
    reverse_proxy 127.0.0.1:8081
}
EOF

caddy reload --config /etc/caddy/Caddyfile
```

**注意：** 自签名证书会导致浏览器安全警告，不适合生产环境。

## 自动化脚本

仓库中已提供自动化部署脚本：

```bash
# 1. 检查当前状态
./scripts/verify-forum-access.sh

# 2. 部署反向代理（假设 DNS 已配置）
./scripts/deploy-forum-reverse-proxy.sh --caddy

# 3. 验证部署
./scripts/verify-forum-access.sh --quiet
```

## 故障排查

### 1. DNS 问题
```bash
# 检查 DNS 解析
dig forum.clawdrepublic.cn +short
nslookup forum.clawdrepublic.cn

# 检查 DNS 传播状态
# 使用在线工具: https://dnschecker.org/
```

### 2. SSL 证书问题
```bash
# 检查证书状态
openssl s_client -connect forum.clawdrepublic.cn:443 -servername forum.clawdrepublic.cn < /dev/null 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject:"

# 检查 Caddy 证书日志
ssh root@8.210.185.194 'journalctl -u caddy --since "1 hour ago" | grep -i certificate'
```

### 3. 服务状态
```bash
# 检查论坛容器
ssh root@8.210.185.194 'docker ps --filter "name=flarum"'

# 检查本地端口
ssh root@8.210.185.194 'curl -fsS http://127.0.0.1:8081/ >/dev/null && echo "本地端口正常"'

# 检查 Caddy 配置
ssh root@8.210.185.194 'caddy validate --config /etc/caddy/Caddyfile'
```

## 预期时间线

1. **DNS 配置**: 5-60 分钟（传播时间）
2. **证书申请**: 2-5 分钟（Let's Encrypt 自动申请）
3. **服务生效**: 立即（Caddy 自动重载）

## 验证清单

- [ ] DNS A 记录已添加：`forum.clawdrepublic.cn` → `8.210.185.194`
- [ ] DNS 解析正常：`dig forum.clawdrepublic.cn +short` 返回正确 IP
- [ ] HTTPS 访问正常：`curl -fsS https://forum.clawdrepublic.cn/` 返回 200
- [ ] 页面内容正确：页面包含 "Clawd 国度论坛"
- [ ] SSL 证书有效：浏览器显示绿色锁标志

## 相关资源

- **服务器 IP**: 8.210.185.194
- **论坛端口**: 8081 (本地), 443 (HTTPS)
- **部署脚本**: `./scripts/deploy-forum-reverse-proxy.sh`
- **验证脚本**: `./scripts/verify-forum-access.sh`
- **Caddy 配置**: `/etc/caddy/Caddyfile` (服务器)
- **论坛容器**: `forum-flarum-1` (Docker)

## 紧急联系方式

如需紧急协助，请在论坛中发帖或联系管理员。

---

**最后更新**: 2026-02-10  
**状态**: 等待 DNS 配置  
**负责人**: 项目维护团队