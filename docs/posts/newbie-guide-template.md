# 新手入门（从 0 到 1）注册安装接入

## 第一步：注册账号
1. 访问 https://clawdrepublic.cn/
2. 点击右上角"注册"按钮
3. 填写邮箱、用户名、密码
4. 查收验证邮件并点击链接激活

## 第二步：安装 OpenClaw（国内源优先）

### 一键安装命令
```bash
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

### 验证安装
```bash
openclaw --version
# 应该输出类似：openclaw/1.0.0
```

## 第三步：配置 TRIAL_KEY

### 1. 获取配置文件
创建或编辑 `~/.openclaw/openclaw.json`：

```json
{
  "agents": {
    "defaults": {
      "model": { "primary": "clawd-gateway/deepseek-chat" },
      "models": {
        "clawd-gateway/deepseek-chat": {},
        "clawd-gateway/deepseek-reasoner": {}
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "clawd-gateway": {
        "baseUrl": "https://api.clawdrepublic.cn/v1",
        "apiKey": "${CLAWD_TRIAL_KEY}",
        "api": "openai-completions",
        "models": [
          { "id": "deepseek-chat", "name": "DeepSeek Chat" },
          { "id": "deepseek-reasoner", "name": "DeepSeek Reasoner" }
        ]
      }
    }
  }
}
```

### 2. 申请 TRIAL_KEY
1. 到「TRIAL_KEY 申请」板块发帖
2. 使用标准模板填写申请信息
3. 等待管理员审核发放

### 3. 设置环境变量
```bash
export TRIAL_KEY="sk-xxx"
export CLAWD_TRIAL_KEY="${TRIAL_KEY}"
```

## 第四步：验证与首次使用

### 健康检查
```bash
curl -fsS https://api.clawdrepublic.cn/healthz
# 应该返回：{"ok":true}
```

### 测试 API 调用
```bash
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -H 'content-type: application/json' \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"用一句话介绍 Clawd 国度"}]
  }'
```

### 启动 OpenClaw 网关
```bash
openclaw gateway start
openclaw models status
```

## 第五步：常见问题排查

### 问题1：安装失败
**症状：** `curl` 命令报错或超时
**解决：**
1. 检查网络连接
2. 尝试使用代理（如有需要）
3. 手动下载安装脚本：
   ```bash
   wget https://clawdrepublic.cn/install-cn.sh
   bash install-cn.sh
   ```

### 问题2：TRIAL_KEY 无效
**症状：** API 返回 401 错误
**解决：**
1. 检查环境变量是否正确设置：`echo $CLAWD_TRIAL_KEY`
2. 确认 key 格式为 `sk-` 开头
3. 联系管理员确认 key 状态

### 问题3：网关启动失败
**症状：** `openclaw gateway start` 报错
**解决：**
1. 检查配置文件语法：`cat ~/.openclaw/openclaw.json | jq .`
2. 查看日志：`openclaw gateway logs`
3. 确保端口 3000 未被占用

## 需要帮助？
如果遇到以上未覆盖的问题，请到「问题求助」板块发帖，使用标准提问模板。