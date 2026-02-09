# 超小白验证命令（仅需复制粘贴）

## 第一步：检查网络连通性
curl -fsS -m 5 https://clawdrepublic.cn/ > /dev/null && echo '✅ 官网可访问'

## 第二步：检查API健康
curl -fsS -m 5 https://api.clawdrepublic.cn/healthz && echo '✅ API健康'

## 第三步：一键自检（推荐）
curl -fsSL https://clawdrepublic.cn/probe-roc-all.sh | bash

## 第四步：申请TRIAL_KEY
1. 访问论坛：https://clawdrepublic.cn/forum/
2. 在'TRIAL_KEY申请'板块发帖
3. 按模板填写用途和预计使用量
4. 等待管理员发放key

## 第五步：验证TRIAL_KEY
export CLAWD_TRIAL_KEY='你的trial_key'
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}"
