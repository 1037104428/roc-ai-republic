# 小白一条龙：从拿到 Key 到第一次调用（草案）

## 你将获得什么

- 1 个可用的 TRIAL_KEY（先人工发放）
- 1 条可直接复制运行的 curl 命令
- 1 个能看懂的“用量/额度”查询方式

## 0) 你需要准备

- 一台能上网的电脑
- 安装 curl（Mac/Linux 通常自带；Windows 建议用 Git Bash 或 WSL）

## 1) 获取 TRIAL_KEY（当前流程：人工发放）

- 方式：在官网/论坛指定帖子留言（附用途），管理员发放。
- 你会拿到：类似 `trial_xxx...` 的字符串（不要发到公开场合）。

## 2) 第一次调用（复制运行）

把下面的 `YOUR_TRIAL_KEY` 换成你的 key：

```bash
curl -sS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "clawd-default",
    "messages": [{"role": "user", "content": "你好，给我一个 3 步学习计划"}]
  }'
```

## 3) 查看用量/额度（示例）

```bash
curl -sS https://api.clawdrepublic.cn/admin/usage \
  -H "Authorization: Bearer YOUR_TRIAL_KEY"
```

> 说明：字段含义与常见问题，会在 quota-proxy 文档里解释。
