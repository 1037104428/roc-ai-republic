# 验证脚本说明

本目录包含用于验证中华AI共和国/OpenClaw小白一条龙教程各环节的脚本。

## 脚本列表

### 1. `verify-node-env.sh`
**用途**：验证Node.js环境是否符合OpenClaw安装要求
**检查项目**：
- Node.js版本（>=16，推荐v18+）
- npm/npx可用性
- OpenClaw CLI是否已安装
- 网络连接（npm registry、GitHub、官网）
- 国内用户友好提示（镜像源配置）

**用法**：
```bash
# 基础检查
./scripts/verify-node-env.sh

# 详细检查（包含npm配置等）
./scripts/verify-node-env.sh --verbose
```

**适用场景**：
- 新手安装OpenClaw前的环境检查
- 安装失败时的故障排查
- 环境迁移或升级时的兼容性检查

### 2. `verify-quickstart-v2.sh`
**用途**：验证小白一条龙教程的完整链路
**检查项目**：
- 官网可达性（https://clawdrepublic.cn/）
- API网关健康状态（https://api.clawdrepublic.cn/healthz）
- 论坛可达性（https://clawdrepublic.cn/forum/）
- TRIAL_KEY有效性（可选）
- 安装脚本可达性（https://clawdrepublic.cn/install-cn.sh）

**用法**：
```bash
# 基础健康检查（无需key）
./scripts/verify-quickstart-v2.sh

# 使用环境变量中的key检查
export CLAWD_TRIAL_KEY="your_key_here"
./scripts/verify-quickstart-v2.sh

# 或直接指定key
./scripts/verify-quickstart-v2.sh --key your_key_here
```

**适用场景**：
- 教程每一步的验收验证
- 用户问题复现和排查
- 部署后的健康检查
- 论坛502错误修复验证

### 3. `probe.sh` / `probe-roc-all.sh`
**用途**：一键探活所有服务
**检查项目**：官网、API、论坛、服务器quota-proxy
**特点**：支持`--no-ssh`选项（无服务器权限时使用）

### 4. `verify-install-cn.sh`
**用途**：验证install-cn.sh安装脚本
**检查项目**：语法检查、网络源可达性、版本检查

### 5. `quota-proxy-admin.sh`
**用途**：quota-proxy管理接口命令行工具
**功能**：密钥创建、列表查询、用量统计

## 使用流程

### 新手安装前验证
```bash
# 1. 检查Node.js环境
./scripts/verify-node-env.sh

# 2. 检查服务健康状态
./scripts/verify-quickstart-v2.sh

# 3. 验证安装脚本
./scripts/verify-install-cn.sh --dry-run
```

### 问题排查流程
```bash
# 1. 快速探活
./scripts/probe.sh

# 2. 详细验证
./scripts/verify-quickstart-v2.sh --key $CLAWD_TRIAL_KEY

# 3. 环境检查
./scripts/verify-node-env.sh --verbose
```

### 管理员维护
```bash
# 1. 服务器健康检查
./scripts/ssh-healthz-quota-proxy.sh

# 2. 管理接口操作
./scripts/quota-proxy-admin.sh keys-create --label "测试用户"
./scripts/quota-proxy-admin.sh keys-list
./scripts/quota-proxy-admin.sh usage
```

## 设计原则

1. **渐进式验证**：从基础环境到完整链路，逐步排查
2. **友好提示**：针对国内用户提供镜像源建议
3. **错误明确**：明确失败原因和修复建议
4. **可复制性**：输出可直接复制的命令
5. **安全第一**：不暴露敏感信息，提示安全注意事项

## 集成到教程

这些脚本已集成到以下文档：
- `docs/小白一条龙_从0到可用.md` - 安装前环境验证
- `docs/quickstart.md` - 快速开始验证步骤
- `docs/verify.md` - 完整验证清单
- `docs/ops-server-healthcheck.md` - 运维健康检查

## 更新维护

当服务架构变更时，需要更新相关验证脚本：
1. API端点变更 → 更新`verify-quickstart-v2.sh`
2. 安装要求变更 → 更新`verify-node-env.sh`
3. 新增服务 → 更新`probe.sh`和相关验证脚本

## 贡献指南

添加新验证脚本时：
1. 保持一致的输出格式（✅/❌/⚠️）
2. 包含详细的错误信息和修复建议
3. 支持`--help`或`--dry-run`选项
4. 更新本README文档
5. 在相关教程文档中添加引用