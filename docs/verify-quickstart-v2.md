# 小白一条龙验证脚本 v2

## 概述

`verify-quickstart-v2.sh` 是一个全面的验证脚本，用于检查 OpenClaw 小白一条龙教程中所有关键组件的可用性。它验证官网、API网关、论坛、安装脚本以及 TRIAL_KEY 的有效性。

## 功能

1. **官网可达性检查** - 验证 `https://clawdrepublic.cn/` 可访问
2. **API健康检查** - 验证 `https://api.clawdrepublic.cn/healthz` 返回 `{"ok":true}`
3. **论坛可达性检查** - 验证论坛可访问且标题正确（包含 502 错误修复验证）
4. **TRIAL_KEY 有效性检查** - 验证 key 可正常调用 `/v1/models` 接口
5. **安装脚本可达性检查** - 验证 `https://clawdrepublic.cn/install-cn.sh` 可下载

## 使用方法

### 基础检查（无需 TRIAL_KEY）
```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-quickstart-v2.sh
```

### 完整检查（包含 TRIAL_KEY 验证）
```bash
# 方法1：通过参数传递
./scripts/verify-quickstart-v2.sh --key YOUR_TRIAL_KEY_HERE

# 方法2：通过环境变量
export CLAWD_TRIAL_KEY="YOUR_TRIAL_KEY_HERE"
./scripts/verify-quickstart-v2.sh

# 方法3：使用 OPENAI_API_KEY 环境变量
export OPENAI_API_KEY="YOUR_TRIAL_KEY_HERE"
./scripts/verify-quickstart-v2.sh
```

## 输出示例

```
=== OpenClaw 小白一条龙验证脚本 v2 ===
包含：官网、API、论坛、安装脚本、TRIAL_KEY（可选）

使用环境变量 CLAWD_TRIAL_KEY 进行验证

1. 检查官网可达性...
   ✅ 官网可访问
2. 检查 API 健康状态...
   ✅ API 健康检查通过
3. 检查论坛可达性...
   ✅ 论坛可访问，标题正确
   ✅ 论坛无502错误（历史问题已修复）
4. 检查 TRIAL_KEY 有效性...
   ✅ TRIAL_KEY 有效，可获取模型列表
   发现 5 个可用模型
5. 检查安装脚本可达性...
   ✅ 安装脚本可下载

=== 验证完成 ===
✅ 所有检查通过

总结：
- 官网: ✅ 可访问
- API网关: ✅ 健康
- 论坛: ✅ 可访问（502错误已修复）
- 安装脚本: ✅ 可下载
- TRIAL_KEY: ✅ 有效

下一步：
1. 运行安装脚本: curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
2. 配置环境变量: export CLAWD_TRIAL_KEY="你的key"
3. 启动OpenClaw: openclaw gateway start
4. 遇到问题？去论坛提问: https://clawdrepublic.cn/forum/
```

## 错误处理

脚本使用 `set -e`，任何检查失败都会立即退出并显示错误信息：

- **官网不可访问**：检查网络连接或 DNS 解析
- **API 健康检查失败**：API 网关可能宕机
- **论坛不可访问**：论坛可能返回 502 错误（历史问题）
- **TRIAL_KEY 无效**：key 可能过期或被吊销
- **安装脚本不可下载**：CDN 或服务器问题

## 集成到小白一条龙教程

这个脚本已集成到 `docs/小白一条龙_从0到可用.md` 中，作为"一键自检"步骤。

## 维护说明

- 脚本位置：`scripts/verify-quickstart-v2.sh`
- 文档位置：`docs/verify-quickstart-v2.md`
- 更新时需同步更新教程文档中的引用
- 保持与官网、API、论坛的实际状态同步