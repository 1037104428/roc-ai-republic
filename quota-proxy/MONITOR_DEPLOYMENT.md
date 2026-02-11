# quota-proxy 部署状态监控脚本

## 概述

`monitor-deployment.sh` 是一个用于监控 quota-proxy 部署状态的脚本。它可以定期检查服务的健康状态、状态端点和 Docker 容器状态，并将结果记录到日志文件中。

## 功能特性

- ✅ **健康端点检查**: 检查 `/healthz` 端点是否正常响应
- ✅ **状态端点检查**: 检查 `/status` 端点是否正常响应  
- ✅ **Docker容器检查**: 检查 quota-proxy Docker 容器是否正常运行
- ✅ **日志记录**: 将检查结果记录到指定的日志文件
- ✅ **日志轮转**: 自动轮转过大的日志文件
- ✅ **守护进程模式**: 支持以守护进程模式持续监控
- ✅ **详细输出**: 支持详细输出模式，便于调试
- ✅ **干运行模式**: 支持干运行模式，不实际执行检查

## 快速开始

### 基本使用

```bash
# 授予执行权限
chmod +x monitor-deployment.sh

# 执行一次检查
./monitor-deployment.sh
```

### 指定监控目标

```bash
# 监控远程主机
./monitor-deployment.sh --host 192.168.1.100 --port 8787

# 缩短检查间隔
./monitor-deployment.sh --interval 60
```

### 守护进程模式

```bash
# 以守护进程模式运行，每5分钟检查一次
./monitor-deployment.sh --daemon --interval 300

# 指定日志文件
./monitor-deployment.sh --daemon --log /var/log/my-monitor.log
```

## 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--host` | `-H` | 监控主机地址 | `127.0.0.1` |
| `--port` | `-p` | 监控端口 | `8787` |
| `--interval` | `-i` | 检查间隔秒数（守护进程模式） | `300` |
| `--log` | `-l` | 日志文件路径 | `/var/log/quota-proxy-monitor.log` |
| `--max-size` | `-m` | 日志文件最大大小（字节） | `10485760` (10MB) |
| `--daemon` | `-d` | 以守护进程模式运行 | `false` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--dry-run` | - | 干运行模式，不实际执行检查 | `false` |

## 使用示例

### 示例 1: 基本监控

```bash
# 检查本地服务状态
./monitor-deployment.sh
```

输出示例:
```
[2026-02-11 18:15:30] [INFO] 启动 quota-proxy 部署状态监控
[2026-02-11 18:15:30] [INFO] 配置: 主机=127.0.0.1, 端口=8787, 间隔=300秒
[2026-02-11 18:15:30] [INFO] 日志: /var/log/quota-proxy-monitor.log, 最大大小=10485760字节
[2026-02-11 18:15:30] [INFO] 开始执行部署状态检查
[2026-02-11 18:15:30] [INFO] 健康端点检查成功: http://127.0.0.1:8787/healthz
[2026-02-11 18:15:30] [INFO] 状态端点检查成功: http://127.0.0.1:8787/status
[2026-02-11 18:15:30] [INFO] Docker容器运行正常: quota-proxy   Up 2 days
[2026-02-11 18:15:30] [INFO] 所有检查通过: 服务运行正常
[2026-02-11 18:15:30] [INFO] 监控检查完成，退出码: 0
```

### 示例 2: 守护进程模式

```bash
# 以守护进程模式运行，每分钟检查一次
./monitor-deployment.sh --daemon --interval 60 --log /tmp/monitor.log
```

### 示例 3: 远程监控

```bash
# 监控远程服务器
./monitor-deployment.sh --host api.example.com --port 8787 --verbose
```

### 示例 4: 干运行模式

```bash
# 干运行模式，查看将执行的操作
./monitor-deployment.sh --dry-run --verbose
```

## 集成到系统服务

### Systemd 服务配置

创建 `/etc/systemd/system/quota-proxy-monitor.service`:

```ini
[Unit]
Description=quota-proxy Deployment Monitor
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/roc/quota-proxy
ExecStart=/opt/roc/quota-proxy/monitor-deployment.sh --daemon --interval 300
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

启用并启动服务:

```bash
sudo systemctl daemon-reload
sudo systemctl enable quota-proxy-monitor
sudo systemctl start quota-proxy-monitor
```

### Cron 定时任务

添加到 crontab，每5分钟执行一次:

```bash
# 编辑 crontab
crontab -e

# 添加以下行
*/5 * * * * /opt/roc/quota-proxy/monitor-deployment.sh >> /var/log/quota-proxy-monitor-cron.log 2>&1
```

## 故障排除

### 常见问题

1. **健康端点检查失败**
   - 检查 quota-proxy 服务是否运行: `docker compose ps`
   - 检查端口是否监听: `netstat -tlnp | grep 8787`
   - 检查防火墙设置

2. **Docker 容器检查失败**
   - 检查 Docker 服务状态: `systemctl status docker`
   - 检查容器是否运行: `docker ps | grep quota-proxy`

3. **权限问题**
   - 确保脚本有执行权限: `chmod +x monitor-deployment.sh`
   - 确保日志目录可写

### 调试模式

使用详细输出模式查看详细信息:

```bash
./monitor-deployment.sh --verbose
```

## 相关文档

- [部署指南](./DEPLOYMENT.md) - quota-proxy 部署说明
- [健康检查](./HEALTH_CHECK.md) - 健康检查端点说明
- [状态端点](./STATUS_ENDPOINT.md) - 状态端点说明
- [Docker 部署](./DOCKER_DEPLOYMENT.md) - Docker 部署说明

## 版本历史

| 版本 | 日期 | 描述 |
|------|------|------|
| 1.0.0 | 2026-02-11 | 初始版本，包含基本监控功能 |
| 1.0.1 | 2026-02-11 | 添加日志轮转和详细输出模式 |

## 许可证

MIT License
