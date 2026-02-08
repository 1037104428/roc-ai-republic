# 小白一条龙（入口页）

这份文件只做“入口索引”，避免与官网内容重复、产生不一致。

## 一条龙教程（仓库版，建议从这里开始）

- `docs/小白一条龙_从0到可用.md`

覆盖：TRIAL_KEY → 连通性体检 → curl 最小调用 →（可选）OpenClaw 安装/配置/验证。

## 官网版（给外部用户的可视化页面）

- https://clawdrepublic.cn/quickstart.html

## 验证命令（不调用模型，不花费额度）

```bash
curl -fsS https://api.clawdrepublic.cn/healthz
```

期望输出（类似）：

```json
{"ok":true}
```
