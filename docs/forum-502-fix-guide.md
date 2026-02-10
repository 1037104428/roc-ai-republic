# 论坛 502 错误修复指南

## 问题描述

访问 `https://forum.clawdrepublic.cn/` 返回 502 Bad Gateway 错误。

## 根本原因

Caddy 配置中定义了 `forum.clawdrepublic.cn` 子域名，但该子域名的 DNS A 记录不存在。
Caddy 尝试为这个子域名获取 Let's Encrypt SSL 证书时失败，导致无法建立 HTTPS 连接。

从 Caddy 日志可以看到：
```
DNS problem: NXDOMAIN looking up A for forum.clawdrepublic.cn - check that a DNS record exists for this domain
```

## 当前状态

- ✅ 论坛服务在内网正常运行：`http://127.0.0.1:8081/`
- ✅ 主域名正常：`https://clawdrepublic.cn/`
- ✅ API 网关正常：`https://api.clawdrepublic.cn/healthz`
- ❌ 论坛子域名无法访问：`https://forum.clawdrepublic.cn/` (502)
- ⚠️ 路径方式可能可用：`https://clawdrepublic.cn/forum/` (需要测试)

## 解决方案

### 方案 A：添加 DNS 记录（推荐）

1. **登录域名管理面板**（如阿里云、腾讯云、Cloudflare 等）
2. **添加 A 记录**：
   - 主机名：`forum`
   - 记录类型：`A`
   - 记录值：`8.210.185.194`
   - TTL：默认（通常 600 秒）

3. **等待 DNS 传播**：
   - 通常需要几分钟到几小时
   - 可以使用命令检查：`dig forum.clawdrepublic.cn +short`

4. **Caddy 会自动处理**：
   - DNS 记录生效后，Caddy 会自动获取 SSL 证书
   - 无需重启服务

### 方案 B：临时修复 - 使用路径方式

如果暂时无法添加 DNS 记录，可以：

1. **修改 Caddy 配置**，注释掉子域名配置：
   ```bash
   # 备份原配置
   cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d-%H%M%S)
   
   # 注释掉 forum.clawdrepublic.cn 块
   sed -i '/^forum\.clawdrepublic\.cn {/,/^}/s/^/# /' /etc/caddy/Caddyfile
   
   # 重启 Caddy
   systemctl restart caddy
   ```

2. **通过路径访问**：
   - 论坛地址变为：`https://clawdrepublic.cn/forum/`
   - 更新相关文档和链接

3. **恢复子域名**（添加 DNS 记录后）：
   ```bash
   # 取消注释
   sed -i '/^# forum\.clawdrepublic\.cn {/,/^# }/s/^# //' /etc/caddy/Caddyfile
   
   # 重启 Caddy
   systemctl restart caddy
   ```

### 方案 C：使用自动化脚本

项目已提供修复脚本：

```bash
# 运行修复脚本
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/fix-forum-502.sh
```

脚本会：
1. 检测当前状态
2. 提供两种解决方案
3. 可执行临时修复（方案B）

## 验证步骤

修复后验证：

```bash
# 测试论坛访问
curl -fsS -m 5 https://clawdrepublic.cn/forum/ && echo "✓ 论坛访问正常" || echo "✗ 论坛访问失败"

# 查看 Caddy 状态
ssh root@8.210.185.194 'systemctl status caddy --no-pager -l'

# 查看 Caddy 日志
ssh root@8.210.185.194 'journalctl -u caddy --no-pager -n 20'
```

## 预防措施

1. **DNS 记录管理**：
   - 在部署新服务前，确保 DNS 记录已添加
   - 使用 DNS 检查工具验证：`nslookup forum.clawdrepublic.cn`

2. **Caddy 配置优化**：
   - 考虑使用通配符证书：`*.clawdrepublic.cn`
   - 或使用 DNS-01 挑战方式（需要 API 密钥）

3. **监控告警**：
   - 设置监控检查论坛可访问性
   - 配置告警通知

## 相关文件

- Caddy 配置：`/etc/caddy/Caddyfile`
- 修复脚本：`scripts/fix-forum-502.sh`
- 论坛服务：`/opt/roc/forum/`（Docker 容器）
- 部署文档：`docs/deployment.md`

## 时间线

- 2026-02-09：首次部署论坛，配置子域名
- 2026-02-10：发现 502 错误，诊断为 DNS 问题
- 2026-02-10：创建修复脚本和文档

## 后续改进

1. **自动化部署**：在部署脚本中自动检查 DNS 记录
2. **备用方案**：配置回退到路径方式
3. **文档更新**：更新所有文档中的论坛链接
4. **测试套件**：添加论坛可访问性测试到 CI/CD