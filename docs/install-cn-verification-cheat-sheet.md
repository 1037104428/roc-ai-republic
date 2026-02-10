# install-cn.sh 验证命令速查表

本文档提供 `install-cn.sh` 安装脚本的验证命令快速参考，帮助用户根据需求选择合适的验证级别和命令组合。

## 验证级别概览

| 级别 | 说明 | 适用场景 |
|------|------|----------|
| `basic` | 基础验证：仅检查OpenClaw版本 | 快速安装，信任网络环境 |
| `quick` | 快速验证：检查版本 + 网络连通性 | 常规安装，需要基本网络检查 |
| `full` | 完整验证：全部检查（版本、网络、依赖、配置） | 生产环境，需要全面验证 |
| `none` | 跳过所有验证 | 仅安装，不验证 |
| `auto` | 自动选择（默认：quick） | 大多数场景 |

## 常用命令组合

### 1. 快速安装（默认验证）
```bash
# 使用默认验证级别（auto → quick）
./scripts/install-cn.sh

# 明确指定快速验证
./scripts/install-cn.sh --verify-level quick
```

### 2. 生产环境安装（完整验证）
```bash
# 完整验证，确保所有依赖和配置正确
./scripts/install-cn.sh --verify-level full

# 完整验证 + 详细输出
./scripts/install-cn.sh --verify-level full --verbose
```

### 3. 仅安装不验证
```bash
# 跳过所有验证，仅执行安装
./scripts/install-cn.sh --verify-level none

# 适用于已知环境或离线安装
./scripts/install-cn.sh --verify-level none --no-network-check
```

### 4. 模拟运行（测试）
```bash
# 模拟运行，不实际安装
./scripts/install-cn.sh --dry-run

# 模拟运行 + 详细输出
./scripts/install-cn.sh --dry-run --verbose

# 模拟运行 + 指定验证级别
./scripts/install-cn.sh --dry-run --verify-level full
```

### 5. 环境变量覆盖
```bash
# 通过环境变量设置验证级别
export OPENCLAW_VERIFY_LEVEL=full
./scripts/install-cn.sh

# 组合使用
export OPENCLAW_VERIFY_LEVEL=basic
export OPENCLAW_DRY_RUN=true
./scripts/install-cn.sh --verbose
```

## 验证步骤详解

### basic 级别验证
1. 检查OpenClaw版本命令是否可用
2. 运行 `openclaw --version` 获取版本信息

### quick 级别验证（默认）
1. basic 验证全部步骤
2. 网络连通性检查：
   - 检查GitHub API可达性
   - 检查Gitee API可达性
   - 检查npm registry可达性

### full 级别验证
1. quick 验证全部步骤
2. 依赖检查：
   - 检查Node.js版本（>=18）
   - 检查npm版本
   - 检查git版本
3. 配置检查：
   - 检查OpenClaw配置文件
   - 检查工作目录权限
   - 检查环境变量设置

## 故障排除命令

### 1. 验证脚本本身
```bash
# 检查脚本语法
bash -n scripts/install-cn.sh

# 显示脚本帮助
./scripts/install-cn.sh --help

# 显示版本信息
./scripts/install-cn.sh --version
```

### 2. 分步验证
```bash
# 仅检查网络
./scripts/install-cn.sh --verify-level quick --dry-run 2>&1 | grep -i "network"

# 仅检查依赖
./scripts/install-cn.sh --verify-level full --dry-run 2>&1 | grep -i "depend\|node\|npm"

# 仅检查配置
./scripts/install-cn.sh --verify-level full --dry-run 2>&1 | grep -i "config\|permission"
```

### 3. 调试模式
```bash
# 启用调试输出
bash -x scripts/install-cn.sh --dry-run --verify-level quick 2>&1 | head -50

# 详细输出 + 错误跟踪
./scripts/install-cn.sh --verbose --verify-level full 2>&1 | tee install.log
```

## 实际使用场景

### 场景1：快速部署测试环境
```bash
# 使用快速验证，节省时间
./scripts/install-cn.sh --verify-level quick

# 验证安装结果
openclaw --version
openclaw status
```

### 场景2：生产环境部署
```bash
# 完整验证，确保环境准备就绪
./scripts/install-cn.sh --verify-level full --verbose

# 验证服务状态
openclaw gateway status
openclaw health
```

### 场景3：CI/CD流水线
```bash
# 在CI中使用，设置环境变量
export OPENCLAW_VERIFY_LEVEL=full
export OPENCLAW_DRY_RUN=false

# 执行安装
./scripts/install-cn.sh

# 检查退出码
if [ $? -eq 0 ]; then
    echo "安装成功"
else
    echo "安装失败，退出码: $?"
    exit 1
fi
```

### 场景4：离线环境
```bash
# 跳过网络检查
./scripts/install-cn.sh --verify-level basic --no-network-check

# 或完全跳过验证
./scripts/install-cn.sh --verify-level none --no-network-check
```

## 最佳实践

1. **开发环境**：使用 `--verify-level quick`（默认）
2. **测试环境**：使用 `--verify-level full --dry-run` 先测试
3. **生产环境**：使用 `--verify-level full --verbose` 完整验证
4. **CI/CD**：设置 `OPENCLAW_VERIFY_LEVEL=full` 环境变量
5. **故障排查**：结合 `--dry-run` 和 `--verbose` 分析问题

## 退出码说明

| 退出码 | 含义 | 建议操作 |
|--------|------|----------|
| 0 | 成功 | 安装完成 |
| 1 | 通用错误 | 查看详细输出 |
| 2 | 参数错误 | 检查命令参数 |
| 3 | 网络错误 | 检查网络连接 |
| 4 | 依赖错误 | 检查Node.js/npm/git |
| 5 | 权限错误 | 检查文件权限 |
| 6 | 配置错误 | 检查OpenClaw配置 |
| 7 | 验证失败 | 根据验证级别检查具体问题 |

## 更新记录

- **v2026.02.10.02**: 新增 `--verify-level` 参数，支持多级别验证
- **v2026.02.10.01**: 初始版本，支持国内源优先 + 回退策略

---

**相关文档**：
- [install-cn.sh 使用指南](../docs/install-cn-guide.md)
- [OpenClaw 中文安装文档](../docs/openclaw-cn-installation.md)
- [故障排除指南](../docs/troubleshooting-guide.md)