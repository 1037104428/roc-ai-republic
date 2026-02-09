# Clawd共和国论坛 MVP

## 当前状态

- ✅ 论坛引擎：Flarum 已部署在服务器 `127.0.0.1:8081`
- ❌ 外网访问：`forum.clawdrepublic.cn` 当前返回 502（反向代理配置待修复）
- ✅ 内部健康：可通过 SSH 到服务器验证 `curl -fsS http://127.0.0.1:8081/`

## 快速验证

```bash
# 服务器内部验证（需要 SSH 权限）
ssh -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 "curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo '论坛内部服务正常'"

# 外网验证（当前应返回 502）
curl -fsS -m 5 http://forum.clawdrepublic.cn/ || echo "外网访问异常（预期中）"
```

## 待办事项

1. **修复反向代理** - 配置 Caddy/Nginx 将 `forum.clawdrepublic.cn` 代理到 `127.0.0.1:8081`
2. **HTTPS 证书** - 为子域名申请 Let's Encrypt 证书
3. **初始化内容** - 创建标准板块和置顶帖
4. **用户引导** - 编写论坛使用指南

## 相关文档

- [论坛部署 ticket](../docs/tickets.md#论坛-现网优先)
- [反向代理配置示例](../docs/tickets.md#caddy-配置示例)