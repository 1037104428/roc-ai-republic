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

### 5. `verify-install-cn-environment.sh`
**用途**：验证install-cn.sh脚本的执行环境
**检查项目**：
- 脚本语法和结构验证
- 版本兼容性检查功能
- 网络源可达性测试（npm镜像源）
- 回退策略验证
- 自检功能验证（openclaw --version）
- 颜色输出和日志功能

**用法**：
```bash
# 基础验证
./scripts/verify-install-cn-environment.sh

# 详细验证（包含网络测试）
./scripts/verify-install-cn-environment.sh --verbose

# 干运行模式（不实际执行安装）
./scripts/verify-install-cn-environment.sh --dry-run
```

**适用场景**：
- install-cn.sh脚本发布前的质量检查
- 用户安装失败时的环境诊断
- 镜像源切换策略验证
- 版本兼容性测试

### 6. `verify-install-cn-execution-modes.sh`
**用途**：验证install-cn.sh脚本的不同执行模式
**检查项目**：
- 标准安装模式验证
- CI/CD模式验证（CI_MODE=1）
- 指定版本安装验证
- 自定义npm registry验证
- 静默安装模式验证
- 日志记录功能验证

**用法**：
```bash
# 验证所有执行模式（干运行）
./scripts/verify-install-cn-execution-modes.sh --all

# 验证特定模式
./scripts/verify-install-cn-execution-modes.sh --mode ci
./scripts/verify-install-cn-execution-modes.sh --mode version
./scripts/verify-install-cn-execution-modes.sh --mode registry
```

**适用场景**：
- 多环境部署验证
- CI/CD流水线集成测试
- 版本发布验证
- 镜像源切换测试

### 7. `verify-install-cn-features.sh`
**用途**：验证install-cn.sh脚本的高级功能
**检查项目**：
- 智能版本兼容性检查
- 网络源优先级和回退策略
- 错误处理和恢复机制
- 颜色输出和用户界面
- 日志记录和轮转功能
- 脚本更新检查功能

**用法**：
```bash
# 验证所有高级功能
./scripts/verify-install-cn-features.sh

# 验证特定功能
./scripts/verify-install-cn-features.sh --feature compatibility
./scripts/verify-install-cn-features.sh --feature fallback
./scripts/verify-install-cn-features.sh --feature error-handling
```

**适用场景**：
- 功能完整性验证
- 用户体验测试
- 错误恢复测试
- 发布质量保证

### 8. `verify-registry-fallback.sh`
**用途**：验证npm镜像源回退策略
**检查项目**：
- 主要镜像源可达性（npmmirror.com）
- 备用镜像源可达性（npmjs.com）
- 回退策略执行验证
- 网络超时和重试机制
- 安装成功率统计

**用法**：
```bash
# 验证回退策略
./scripts/verify-registry-fallback.sh

# 模拟网络故障测试
./scripts/verify-registry-fallback.sh --simulate-failure

# 性能基准测试
./scripts/verify-registry-fallback.sh --benchmark
```

**适用场景**：
- 网络环境不稳定时的安装验证
- 镜像源切换策略测试
- 安装成功率优化
- 国内网络环境适配测试

### 9. `quota-proxy-admin.sh`
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

# 4. 安装脚本验证（如果安装失败）
./scripts/verify-install-cn-environment.sh --verbose
./scripts/verify-install-cn-execution-modes.sh --all
./scripts/verify-registry-fallback.sh
```

### install-cn.sh安装失败专项排查
```bash
# 1. 检查脚本语法和结构
./scripts/verify-install-cn-environment.sh --dry-run

# 2. 验证网络源可达性
./scripts/verify-registry-fallback.sh

# 3. 验证版本兼容性
./scripts/verify-install-cn-features.sh --feature compatibility

# 4. 验证执行模式
./scripts/verify-install-cn-execution-modes.sh --all

# 5. 完整功能验证
./scripts/verify-install-cn-features.sh
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
- `docs/install-cn-verification-guide.md` - install-cn.sh安装脚本验证指南

## install-cn.sh验证脚本体系

install-cn.sh脚本拥有完整的验证工具链，确保安装过程可靠：

### 验证层级
1. **环境层** (`verify-install-cn-environment.sh`) - 基础环境验证
2. **功能层** (`verify-install-cn-features.sh`) - 高级功能验证
3. **执行层** (`verify-install-cn-execution-modes.sh`) - 多模式验证
4. **网络层** (`verify-registry-fallback.sh`) - 网络策略验证
5. **集成层** (`verify-install-cn.sh`) - 完整集成验证

### 验证覆盖
- ✅ 语法和结构验证
- ✅ 版本兼容性检查
- ✅ 网络源可达性测试
- ✅ 回退策略验证
- ✅ 错误处理机制
- ✅ 多环境适配
- ✅ 用户体验测试
- ✅ 性能基准测试

### 质量保证
每个install-cn.sh版本发布前都应通过完整的验证套件测试，确保：
1. 国内网络环境友好
2. 版本兼容性良好
3. 错误恢复可靠
4. 用户体验优秀
5. 安装成功率高

## 更新维护

当服务架构变更时，需要更新相关验证脚本：
1. API端点变更 → 更新`verify-quickstart-v2.sh`
2. 安装要求变更 → 更新`verify-node-env.sh`
3. 新增服务 → 更新`probe.sh`和相关验证脚本
4. install-cn.sh脚本变更 → 更新相关验证脚本套件：
   - 功能变更 → 更新`verify-install-cn-features.sh`
   - 执行模式变更 → 更新`verify-install-cn-execution-modes.sh`
   - 网络策略变更 → 更新`verify-registry-fallback.sh`
   - 环境要求变更 → 更新`verify-install-cn-environment.sh`

## install-cn.sh验证脚本维护清单

### 定期检查项目
- [ ] 所有验证脚本语法检查
- [ ] 网络源可达性测试
- [ ] 版本兼容性矩阵更新
- [ ] 错误处理场景测试
- [ ] 用户体验流程验证
- [ ] 性能基准测试更新

### 发布前验证流程
1. **环境验证**：运行`verify-install-cn-environment.sh --verbose`
2. **功能验证**：运行`verify-install-cn-features.sh`
3. **执行模式验证**：运行`verify-install-cn-execution-modes.sh --all`
4. **网络策略验证**：运行`verify-registry-fallback.sh`
5. **集成验证**：运行`verify-install-cn.sh`
6. **用户场景测试**：模拟典型用户安装流程

### 问题响应流程
1. 用户报告安装问题
2. 运行相关验证脚本定位问题
3. 修复问题并更新install-cn.sh
4. 运行完整验证套件确认修复
5. 更新验证脚本以覆盖新场景

## 贡献指南

添加新验证脚本时：
1. 保持一致的输出格式（✅/❌/⚠️）
2. 包含详细的错误信息和修复建议
3. 支持`--help`或`--dry-run`选项
4. 更新本README文档
5. 在相关教程文档中添加引用