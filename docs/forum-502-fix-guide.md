# Forum 502 修复指南

## 问题描述
`forum.clawdrepublic.cn` 返回 502 错误，原因是：
1. DNS 记录 `forum.clawdrepublic.cn` 不存在（NXDOMAIN）
2. Caddy 无法获取 SSL 证书，因此拒绝连接

## 临时解决方案
将 `forum.clawdrepublic.cn` 重定向到主域名的 `/forum` 路径。

### 一键修复脚本
```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/fix-forum-502.sh
```

### 手动修复步骤
1. SSH 登录服务器：
   ```bash
   ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194
   ```

2. 备份当前 Caddyfile：
   ```bash
   cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%s)
   ```

3. 移除现有的 `forum.clawdrepublic.cn` 配置块：
   ```bash
   sed -i '/^forum\.clawdrepublic\.cn {/,/^}/d' /etc/caddy/Caddyfile
   ```

4. 添加重定向配置：
   ```bash
   cat >> /etc/caddy/Caddyfile <<'EOF'
   # Temporary fix for forum.clawdrepublic.cn 502
   # Redirect to main domain /forum until DNS is configured
   forum.clawdrepublic.cn {
       redir https://clawdrepublic.cn/forum{uri} permanent
   }
   EOF
   ```

5. 重新加载 Caddy：
   ```bash
   systemctl reload caddy || systemctl restart caddy
   ```

## 验证修复
```bash
# 测试重定向
curl -fsS -L http://forum.clawdrepublic.cn/

# 或直接访问
curl -fsS https://clawdrepublic.cn/forum/
```

## 永久解决方案
需要配置 DNS 记录：
1. 添加 `forum.clawdrepublic.cn` 的 A 记录指向服务器 IP
2. 或使用 CNAME 记录指向 `clawdrepublic.cn`

### DNS 配置示例
```
forum.clawdrepublic.cn.  IN  A      8.210.185.194
# 或
forum.clawdrepublic.cn.  IN  CNAME  clawdrepublic.cn.
```

配置 DNS 后，恢复原始反向代理配置：
```caddy
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081
}
```

## 相关文件
- `scripts/fix-forum-502.sh` - 一键修复脚本
- `/etc/caddy/Caddyfile` - Caddy 配置文件
- `docs/tickets.md` - 问题跟踪