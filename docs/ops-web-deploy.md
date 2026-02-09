# 站点（静态 landing page）部署草案（Caddy / Nginx）

目标：把仓库里的静态站点 `web/site/` 部署到服务器 `/opt/roc/web/`（推荐），并通过 HTTPS 对外提供：

- 下载入口（含 `install-cn.sh`）
- 安装命令
- API 网关 `baseUrl`
- TRIAL_KEY 获取方式（指向 quota-proxy 的 admin 方式/说明）

> 说明：本文是“可复现部署步骤草案”，不默认要求你现在就上线公网服务；运维可先在服务器本机 `curl` 验证静态文件是否可访问。

---

## 目录约定

- 源码：`/home/kai/.openclaw/workspace/roc-ai-republic/web/site/`
- 服务器目标：`/opt/roc/web/`

建议最终对外站点根目录就是 `/opt/roc/web`，其中必须至少包含：

- `index.html`
- `downloads.html`
- `quickstart.html`
- `install-cn.sh`

---

## 部署（文件同步）

在本机（有仓库的一侧）执行（推荐用仓库自带脚本，自动读取 `/tmp/server.txt`）：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/deploy-web-site.sh
```

你也可以先跑一遍 dry-run 看看会做什么：

```bash
./scripts/deploy-web-site.sh --dry-run
```

> 说明：脚本默认目标目录是 `/opt/roc/web`。若你想用子目录（例如 `/opt/roc/web/site`），可用：
>
> ```bash
> ./scripts/deploy-web-site.sh --remote-dir /opt/roc/web/site
> ```

如果你更偏好 rsync（例如增量同步/可选择 `--delete`），也可以手动用：

```bash
rsync -av web/site/ root@<SERVER_HOST>:/opt/roc/web/
```

服务器侧可快速检查：

```bash
ls -la /opt/roc/web | head
```

---

## Caddy（推荐）

### 最小 Caddyfile

`/etc/caddy/Caddyfile` 示例：

```caddyfile
# 先用域名部署（HTTPS 自动证书），或临时用 IP/HTTP 做内网验证
example.com {
  root * /opt/roc/web
  file_server

  # 安全：不要把目录列表开太多花样；只做静态即可
}
```

重载：

```bash
caddy reload --config /etc/caddy/Caddyfile
```

### 验证

```bash
curl -fsS https://example.com/ | head
curl -fsS https://example.com/install-cn.sh | head
```

---

## Nginx

`/etc/nginx/sites-available/roc-web.conf` 示例：

```nginx
server {
  listen 80;
  server_name example.com;

  root /opt/roc/web;
  index index.html;

  location / {
    try_files $uri $uri/ =404;
  }
}
```

启用 + 重载：

```bash
ln -sf /etc/nginx/sites-available/roc-web.conf /etc/nginx/sites-enabled/roc-web.conf
nginx -t && systemctl reload nginx
```

验证：

```bash
curl -fsS http://example.com/ | head
curl -fsS http://example.com/install-cn.sh | head
```

---

## 需要决策/里程碑通知的点（触发 notify-send）

当准备“公开可用 HTTPS”时，需要明确：

1) 使用哪个域名（`example.com`）
2) 证书来源：
   - Caddy/Let’s Encrypt 自动签发（最省心）
   - 或你已有证书（手工配置）
3) 备案/合规要求（如涉及国内访问与域名）

> 满足“quota-proxy + landing page 上线 HTTPS（可公开使用）”时再触发里程碑通知。
