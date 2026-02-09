# 论坛子域名 DNS 配置说明

## 问题描述

论坛可以通过以下两种方式访问：
1. **路径方式**：`https://clawdrepublic.cn/forum/` ✅ 正常工作
2. **子域名方式**：`https://forum.clawdrepublic.cn/` ❌ 502 错误

## 根本原因

`forum.clawdrepublic.cn` 子域名缺少 DNS A 记录，导致无法解析到服务器 IP。

## 验证方法

```bash
# 检查 DNS 解析
nslookup forum.clawdrepublic.cn 8.8.8.8
# 预期输出：server can't find forum.clawdrepublic.cn: NXDOMAIN

# 对比其他子域名
nslookup api.clawdrepublic.cn 8.8.8.8
# 预期输出：8.210.185.194

nslookup clawdrepublic.cn 8.8.8.8
# 预期输出：8.210.185.194
```

## 解决方案

### 方案 A：添加 DNS A 记录（推荐）

在域名管理面板（如阿里云、腾讯云、Cloudflare 等）中添加以下 DNS 记录：

```
类型：A
主机：forum
值：8.210.185.194
TTL：300（或默认）
```

**验证命令**：
```bash
# 等待 DNS 传播（通常 5-30 分钟）
nslookup forum.clawdrepublic.cn 8.8.8.8
# 预期输出：8.210.185.194

# 测试访问
curl -fsS -m 5 https://forum.clawdrepublic.cn/ | head -3
```

### 方案 B：使用 CNAME 记录（如果支持）

```
类型：CNAME
主机：forum
值：clawdrepublic.cn
TTL：300
```

### 方案 C：暂时使用路径方式访问

如果无法修改 DNS 记录，可以：
1. 使用 `https://clawdrepublic.cn/forum/` 访问论坛
2. 在文档和链接中使用路径方式

## 服务器端配置

服务器端的 Caddy 配置已经准备就绪，支持两种访问方式：

```caddy
# 路径方式（已启用）
clawdrepublic.cn {
    handle /forum/* {
        reverse_proxy http://127.0.0.1:8081
    }
}

# 子域名方式（已启用，等待 DNS）
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081
}
```

## 一键修复脚本

仓库中提供了修复脚本，但需要先配置 DNS：

```bash
# 1. 先配置 DNS 记录（方案 A 或 B）
# 2. 等待 DNS 传播
# 3. 运行修复脚本
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/fix-forum-subdomain.sh
```

## 故障排除

### 如果 DNS 已配置但仍无法访问

1. **检查 DNS 传播**：
   ```bash
   dig forum.clawdrepublic.cn @8.8.8.8
   ```

2. **检查服务器配置**：
   ```bash
   ssh root@8.210.185.194 "cat /etc/caddy/Caddyfile | grep -A5 'forum.clawdrepublic.cn'"
   ```

3. **检查 Caddy 日志**：
   ```bash
   ssh root@8.210.185.194 "tail -f /var/log/caddy/access.log | grep forum"
   ```

### 如果遇到 502 错误

1. **检查论坛服务状态**：
   ```bash
   ssh root@8.210.185.194 "curl -fsS http://127.0.0.1:8081/"
   ```

2. **重启论坛服务**：
   ```bash
   ssh root@8.210.185.194 "cd /opt/roc/forum && docker compose restart"
   ```

## 最佳实践建议

1. **对于新用户**：在教程和文档中使用路径方式 `clawdrepublic.cn/forum/`
2. **对于 SEO**：配置 301 重定向，将子域名重定向到路径方式
3. **对于维护**：保持两种方式都可用，提高容错能力

## 相关文件

- `scripts/fix-forum-subdomain.sh` - 修复脚本
- `/etc/caddy/Caddyfile` - Caddy 配置文件
- `docs/tickets.md` - 问题跟踪

---

**最后更新**：2026-02-09  
**状态**：等待 DNS 配置  
**负责人**：系统管理员  
**优先级**：中（路径方式可用，不影响核心功能）