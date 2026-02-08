# 小白一条龙：从 0 到用上（10 分钟）

> 目标：让完全没接触过的人也能一步步跑通。

## 你需要准备
- 一个能上网的电脑
- 一个终端（Windows 用 PowerShell / macOS 用 Terminal）

## 1) 打开官网
- 访问：https://clawdrepublic.cn/

## 2) 获取试用 Key（TRIAL_KEY）
- 目前为“人工发放”（先加群/联系管理员）
- 拿到后先保存到本地（不要泄露）

## 3) 最小验证（curl）
```bash
export TRIAL_KEY=替换成你拿到的key
curl -fsS -H "Authorization: Bearer $TRIAL_KEY" https://api.clawdrepublic.cn/healthz
```

如果返回 `ok` / 200，说明通了。

## 4) 下一步
- 看 quota-proxy 的用量/配额说明（docs 目录下对应章节）
