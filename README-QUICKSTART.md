# 中华AI共和国 / OpenClaw 小白中文包 - 快速入门指南

## 🚀 5分钟快速开始

### 1. 环境准备
```bash
# 确保已安装 Docker 和 Docker Compose
docker --version
docker compose version
```

### 2. 一键部署
```bash
# 克隆仓库
git clone https://github.com/1037104428/roc-ai-republic.git
cd roc-ai-republic/quota-proxy

# 启动服务
docker compose up -d
```

### 3. 验证部署
```bash
# 检查服务状态
docker compose ps

# 健康检查
curl http://127.0.0.1:8787/healthz
```

### 4. 获取试用密钥
```bash
# 使用默认管理员令牌
ADMIN_TOKEN="your-admin-token-here"

# 生成试用密钥
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"trial-user","quota":1000}'
```

### 5. 使用API
```bash
# 使用试用密钥调用API
API_KEY="your-trial-api-key"

curl -X POST http://127.0.0.1:8787/api/chat \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message":"你好，世界！"}'
```

## 📁 项目结构
```
roc-ai-republic/
├── quota-proxy/          # API配额代理服务
│   ├── docker-compose.yml    # Docker部署配置
│   ├── init-db.sql           # 数据库初始化脚本
│   ├── src/                  # 源代码
│   └── scripts/              # 工具脚本
├── docs/                  # 详细文档
├── scripts/              # 安装和管理脚本
└── web/                  # 静态网站文件
```

## 🔧 常用命令

### 服务管理
```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart
```

### 数据库管理
```bash
# 初始化数据库
docker compose exec quota-proxy sqlite3 /data/quota-proxy.db < init-db.sql

# 备份数据库
docker compose exec quota-proxy sqlite3 /data/quota-proxy.db .dump > backup.sql
```

### 验证工具
```bash
# 运行所有验证
./quota-proxy/run-all-validations.sh

# 测试Admin API
./quota-proxy/test-admin-api.sh

# 验证SQLite数据库
./quota-proxy/verify-sqlite-integrity.sh

# 远程服务器健康检查（先写入服务器地址）
# /tmp/server.txt 支持格式：
#   your.server.ip.or.domain
#   ip:your.server.ip.or.domain
#   host=your.server.ip.or.domain
./scripts/prepare-server-target.sh --server your.server.ip.or.domain
# 或手工写入：echo 'your.server.ip.or.domain' > /tmp/server.txt
# 或让巡检脚本自己写入目标文件（默认 /tmp/server.txt）
./scripts/check-server-health-via-target.sh --set-server your.server.ip.or.domain
./scripts/check-server-health-via-target.sh

# 也可通过环境变量直连（不依赖 /tmp/server.txt）
ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh

# 也可指定自定义目标文件
./scripts/check-server-health-via-target.sh /path/to/server.txt

# 或通过环境变量指定目标文件（便于脚本/CI注入）
ROC_SERVER_FILE=/path/to/server.txt ./scripts/check-server-health-via-target.sh

# 可选：自定义 SSH 用户/端口/连接超时/StrictHostKeyChecking/私钥/远端目录/compose 命令/健康检查地址与 healthz 超时
ROC_SSH_USER=ubuntu ROC_SSH_PORT=2222 ROC_SSH_CONNECT_TIMEOUT=12 ROC_SSH_STRICT_HOST_KEY_CHECKING=accept-new ROC_SSH_IDENTITY_FILE=~/.ssh/id_ed25519 ROC_REMOTE_DIR=/opt/roc/quota-proxy ROC_DOCKER_COMPOSE_CMD='docker compose' ROC_HEALTHZ_TIMEOUT=8 \
ROC_HEALTHZ_URL='http://127.0.0.1:8787/healthz' \
ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh

# 巡检前 10 秒自检：先校验目标文件是否存在且可解析
./scripts/prepare-server-target.sh --check

# 若需机器可读输出（cron/CI 记录），可用 JSON 自检
./scripts/prepare-server-target.sh --check-json

# 若不想依赖 /tmp/server.txt，可直接环境变量直连并先看将执行的 SSH 命令
ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh --dry-run

# 如果远端仍是旧版 docker-compose，可显式切换 compose 命令
ROC_DOCKER_COMPOSE_CMD='docker-compose' ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh --dry-run

# 仅验证目标解析（不发起SSH），适合在CI里先做自检
./scripts/check-server-health-via-target.sh --print-target

# 仅输出纯服务器地址（无 [INFO] 前缀），适合 shell 变量拼接
SERVER=$(./scripts/check-server-health-via-target.sh --print-server)

# 打印将执行的SSH命令（不真正连接远端），便于审计/排障
./scripts/check-server-health-via-target.sh --dry-run

# 仅打印远端命令片段（复制到现有 ssh 命令里复用）
./scripts/check-server-health-via-target.sh --print-remote-cmd

# 仅打印完整 SSH 命令（纯文本一行，适合命令替换/日志采集）
./scripts/check-server-health-via-target.sh --print-ssh-cmd

# 直接执行脚本生成的 SSH 命令（推荐先 --dry-run 审计后再执行）
ROC_SERVER=your.server.ip.or.domain bash -lc "$(./scripts/check-server-health-via-target.sh --print-ssh-cmd)"

# 仅打印 healthz curl 命令（便于复用到现有 SSH/监控平台）
./scripts/check-server-health-via-target.sh --print-healthz-cmd

# 仅打印 healthz URL（便于 Prometheus/UptimeRobot 等监控直接复用地址）
./scripts/check-server-health-via-target.sh --print-healthz-url

# 仅打印 compose ps 命令（便于复用到现有 SSH/监控平台）
./scripts/check-server-health-via-target.sh --print-compose-cmd

# 仅打印 compose+healthz 合并命令（便于监控平台做一次性巡检）
./scripts/check-server-health-via-target.sh --print-check-cmd

# 仅打印“写入目标 + 巡检”一行命令（适合首次接管新服务器）
ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh --print-bootstrap-cmd

# 当还没写 /tmp/server.txt 且不想先 export ROC_SERVER 时，可直接指定目标主机生成同款一行命令
./scripts/check-server-health-via-target.sh --print-bootstrap-cmd-for your.server.ip.or.domain

# 无 /tmp/server.txt 时，直接一条命令恢复“写入目标 + 巡检”（适合 cron/值班交接）
bash -lc "$(./scripts/check-server-health-via-target.sh --print-bootstrap-cmd-for your.server.ip.or.domain)"

# 仅做 healthz 快速探测（跳过 docker compose ps，适合服务已稳定时高频探活）
ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh --healthz-only

# 仅做 compose 状态检查（跳过 healthz curl，适合定位容器拉起/重启问题）
ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh --compose-only

# 临时覆盖 SSH 用户/端口/超时（无需污染环境变量，适合一次性排障）
ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh --ssh-user ubuntu --ssh-port 2222 --connect-timeout 12 --healthz-timeout 8 --dry-run

# 查看巡检脚本参数与环境变量说明
./scripts/check-server-health-via-target.sh --help

# 仅校验目标文件存在且可解析（不改写文件）
./scripts/prepare-server-target.sh --check

# 打印 /tmp/server.txt 可接受示例格式（避免写错 host/ip 键名）
./scripts/prepare-server-target.sh --example

# 15 分钟落地窗口检查（支持 ROC_SERVER 或 ROC_SERVER_FILE 指定目标文件）
ROC_SERVER=your.server.ip.or.domain ./scripts/check-artifact-window.sh --json --strict
ROC_SERVER_FILE=/path/to/server.txt ./scripts/check-artifact-window.sh --json --strict

# cron 友好的一体化巡检（时间戳 + git log + server compose/healthz + 进度日志 tail + 15 分钟窗口判定）
./scripts/cron-check-quota-proxy.sh

# 可通过参数临时调整窗口（例如值班时改为 20 分钟），不改环境变量
./scripts/cron-check-quota-proxy.sh --window-minutes 20

# 覆盖 server 目标文件路径（交接时常见），避免依赖默认 /tmp/server.txt
./scripts/cron-check-quota-proxy.sh --server-file /path/to/server.txt

# 慢网络/跨境链路可调高 SSH 连接超时（默认 8 秒）
./scripts/cron-check-quota-proxy.sh --ssh-timeout 15

# 可配合退出码做告警：0=窗口内有落地，2=窗口 MISS
./scripts/cron-check-quota-proxy.sh >/tmp/roc-cron-check.out 2>&1 || rc=$?; echo "exit=${rc:-0}"; grep -E 'artifact_window=' /tmp/roc-cron-check.out

# 远程巡检要求严格成功（缺失 server 文件 / SSH / healthz 失败会返回 exit=3，便于告警）
./scripts/cron-check-quota-proxy.sh --strict-remote >/tmp/roc-cron-check-remote.out 2>&1 || rc=$?; echo "exit=${rc:-0}"; tail -n 5 /tmp/roc-cron-check-remote.out

# 查看脚本参数帮助
./scripts/cron-check-quota-proxy.sh --help

# 打印“进度日志可粘贴”的验证命令模板（避免 rc/$SERVER 在记录时被提前展开）
./scripts/cron-check-quota-proxy.sh --print-log-snippets

# 模板中包含 server 文件缺失时的 bootstrap 引导命令
./scripts/cron-check-quota-proxy.sh --print-log-snippets | tail -n 1

# 输出 JSON 摘要（便于 cron/告警系统解析 remote_ok 与 artifact_window）
./scripts/cron-check-quota-proxy.sh --json-summary >/tmp/roc-cron-check-json.out 2>&1 || rc=$?; echo "exit=${rc:-0}"; tail -n 2 /tmp/roc-cron-check-json.out

# 仅输出 JSON（静默文本日志，适合机器采集 stdout）
./scripts/cron-check-quota-proxy.sh --json-only || rc=$?; echo "exit=${rc:-0}"

# 可选：窗口检查也支持同一套 SSH/目录/healthz 参数（便于非 root/非 22 端口）
ROC_SSH_USER=ubuntu ROC_SSH_PORT=2222 ROC_SSH_CONNECT_TIMEOUT=12 ROC_REMOTE_DIR=/srv/roc/quota-proxy ROC_HEALTHZ_TIMEOUT=8 \
ROC_HEALTHZ_URL='http://127.0.0.1:8787/healthz' ROC_SERVER=your.server.ip.or.domain \
./scripts/check-artifact-window.sh --json --strict

# 一条命令完成“写入目标 + 远程健康检查”（适合首次排障）
./scripts/prepare-server-target.sh --server your.server.ip.or.domain && ./scripts/check-server-health-via-target.sh

# prepare-server-target 默认写 /tmp/server.txt；可用 ROC_SERVER_FILE 覆盖默认路径
ROC_SERVER_FILE=/tmp/roc-server.txt ./scripts/prepare-server-target.sh --server your.server.ip.or.domain

# 当 /tmp/server.txt 缺失时，显式使用 ROC_SERVER 仍可完成巡检
ROC_SERVER=your.server.ip.or.domain ./scripts/check-server-health-via-target.sh --dry-run

# 或先一键生成 /tmp/server.txt，再执行巡检
./scripts/prepare-server-target.sh --server your.server.ip.or.domain && ./scripts/check-server-health-via-target.sh
```



## 📚 详细文档
- [安装指南](docs/install-cn-quick-reference.md) - 完整安装步骤
- [API文档](docs/api-reference.md) - API接口说明
- [部署指南](docs/deployment-guide.md) - 生产环境部署
- [故障排除](docs/troubleshooting.md) - 常见问题解决

## 🆘 获取帮助
1. 查看 [常见问题解答](docs/faq.md)
2. 检查服务日志：`docker compose logs quota-proxy`
3. 运行验证脚本：`./quota-proxy/run-all-validations.sh`
4. 提交 [GitHub Issue](https://github.com/1037104428/roc-ai-republic/issues)

## 📊 状态检查
```bash
# 服务状态
curl -s http://127.0.0.1:8787/healthz | jq .

# 数据库状态
docker compose exec quota-proxy sqlite3 /data/quota-proxy.db "SELECT COUNT(*) FROM api_keys;"

# 系统资源
docker stats quota-proxy-quota-proxy-1
```

---
*最后更新: 2026-02-18*
