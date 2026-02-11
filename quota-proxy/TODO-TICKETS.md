# TODO Tickets - quota-proxy 开发任务跟踪

## 概述
此文件用于跟踪 quota-proxy 项目的开发任务、功能需求和改进计划。每个任务包含优先级、状态、描述和验证标准。

## 任务分类
- **P0** - 核心功能，必须完成
- **P1** - 重要功能，尽快完成
- **P2** - 改进功能，有时间时完成
- **P3** - 优化功能，低优先级

## 任务列表

### P0 - 核心功能

#### TICKET-P0-001: SQLite 持久化实现
- **状态**: 已完成 (2026-02-12)
- **描述**: 实现 quota-proxy 的 SQLite 数据库持久化，替换当前的内存存储
- **功能要求**:
  1. 使用 init-db.sql 初始化数据库
  2. API keys 存储到 SQLite
  3. 请求日志记录到 SQLite
  4. 支持数据库连接池
- **验证标准**:
  - `POST /keys` 创建的 key 在重启后仍然存在
  - `GET /admin/usage` 能查询历史使用数据
  - 数据库文件大小随使用增长
- **实现详情**:
  - 创建 `server-sqlite-admin.js` - 完整的SQLite持久化服务器
  - 创建 `init-db.sql` - 数据库初始化脚本
  - 创建 `DATABASE-INIT-GUIDE.md` - 数据库初始化指南
  - 创建 `verify-sqlite-persistence.sh` - SQLite持久化验证脚本
- **验证脚本**: 已添加验证脚本，支持一键验证所有SQLite持久化功能
- **相关文件**: `server-sqlite-admin.js`, `init-db.sql`, `DATABASE-INIT-GUIDE.md`, `verify-sqlite-persistence.sh`

#### TICKET-P0-002: Admin API 实现
- **状态**: 已完成 (2026-02-12)
- **描述**: 实现管理员 API 端点，支持 key 管理和使用统计
- **功能要求**:
  1. `POST /admin/keys` - 生成 trial key (需要 ADMIN_TOKEN)
  2. `GET /admin/usage` - 查询 key 使用统计
  3. `DELETE /admin/keys/:key` - 删除 key
  4. `GET /admin/keys` - 列出所有 keys
- **验证标准**:
  - 所有端点需要 ADMIN_TOKEN 验证
  - 返回正确的 JSON 格式
  - 数据从数据库读取
- **实现详情**:
  - 创建 `server-sqlite-admin.js` - 完整的SQLite持久化Admin API服务器
  - 创建 `ADMIN-API-GUIDE.md` - 详细的Admin API使用指南
  - 创建 `verify-admin-api.sh` - Admin API验证脚本
  - 创建 `quick-verify-admin-api.sh` - Admin API快速验证脚本
  - 创建 `QUICK-DEPLOY-ADMIN-API.md` - Admin API快速部署指南
- **测试用例**: 已添加快速测试脚本，支持一键验证所有核心功能
- **相关文件**: `server-sqlite-admin.js`, `ADMIN-API-GUIDE.md`, `verify-admin-api.sh`, `quick-verify-admin-api.sh`, `QUICK-DEPLOY-ADMIN-API.md`

### P1 - 重要功能

#### TICKET-P1-001: 国内安装脚本完善
- **状态**: 已完成 (2026-02-12)
- **描述**: 完成 `scripts/install-cn.sh` 的国内可达源优先 + 回退策略 + 自检
- **功能要求**:
  1. 优先使用国内镜像源 ✓
  2. 失败时自动回退到官方源 ✓
  3. 安装后自检 (`openclaw --version`) ✓
  4. 提供详细的安装文档 ✓
  5. 添加快速验证工具 ✓
- **验证标准**:
  - 脚本在国内网络环境下能正常运行 ✓
  - 安装后能正确运行 `openclaw --version` ✓
  - 文档清晰易懂 ✓
  - 快速验证工具可用 ✓
- **实现详情**:
  - `install-cn.sh` 已实现智能 registry 选择和多层回退策略
  - 已添加完整的安装后自检功能
  - 已创建详细的安装文档: `docs/INSTALL-CN-GUIDE.md`
  - 已创建快速验证工具: `scripts/quick-verify-install-cn.sh`
  - 已集成到验证工具链中
- **相关文件**: 
  - `scripts/install-cn.sh` - 主安装脚本
  - `docs/INSTALL-CN-GUIDE.md` - 安装指南
  - `scripts/quick-verify-install-cn.sh` - 快速验证工具
  - `docs/install-cn-script-verification-guide.md` - 详细验证指南

#### TICKET-P1-002: 静态站点部署
- **状态**: 待开始
- **描述**: 用 Caddy/Nginx 部署静态 landing page
- **功能要求**:
  1. 创建 `/opt/roc/web` 目录结构
  2. 部署静态页面 (HTML/CSS/JS)
  3. 配置 HTTPS (如果需要)
  4. 提供下载入口、安装命令、API 网关信息
- **验证标准**:
  - 站点可通过 HTTPS 访问
  - 页面显示正确内容
  - 下载链接有效
- **相关文件**: 待创建

### P2 - 改进功能

#### TICKET-P2-001: 配置验证工具增强
- **状态**: 已完成
- **描述**: 已创建配置验证脚本和指南
- **验证**: `verify-config.sh` 正常运行
- **相关文件**: `verify-config.sh`, `CONFIG-VERIFICATION-GUIDE.md`

#### TICKET-P2-002: 数据库工具链完善
- **状态**: 已完成
- **描述**: 已创建数据库初始化脚本和检查工具
- **验证**: `check-db.sh` 正常运行
- **相关文件**: `init-db.sql`, `DATABASE-INIT-GUIDE.md`, `check-db.sh`

#### TICKET-P2-003: 文档验证工具链完善
- **状态**: 已完成
- **描述**: 已创建快速文档检查指南
- **验证**: `QUICK-DOCS-CHECK-GUIDE.md` 存在
- **相关文件**: `QUICK-DOCS-CHECK-GUIDE.md`

### P3 - 优化功能

#### TICKET-P3-001: 性能监控
- **状态**: 待开始
- **描述**: 添加性能监控和指标收集
- **功能要求**: Prometheus metrics, 响应时间统计
- **相关文件**: 待创建

#### TICKET-P3-002: 日志增强
- **状态**: 待开始
- **描述**: 增强日志格式和结构化日志
- **功能要求**: JSON 格式日志, 日志级别控制
- **相关文件**: 待创建

## 任务状态跟踪

| 任务ID | 优先级 | 状态 | 创建时间 | 预计完成 | 实际完成 |
|--------|--------|------|----------|----------|----------|
| TICKET-P0-001 | P0 | 已完成 | 2026-02-11 | 2026-02-12 | 2026-02-12 |
| TICKET-P0-002 | P0 | 已完成 | 2026-02-11 | 2026-02-12 | 2026-02-12 |
| TICKET-P1-001 | P1 | 待开始 | 2026-02-11 | 2026-02-13 | - |
| TICKET-P1-002 | P1 | 待开始 | 2026-02-11 | 2026-02-13 | - |
| TICKET-P2-001 | P2 | 已完成 | 2026-02-11 | 2026-02-11 | 2026-02-11 |
| TICKET-P2-002 | P2 | 已完成 | 2026-02-11 | 2026-02-11 | 2026-02-11 |
| TICKET-P2-003 | P2 | 已完成 | 2026-02-11 | 2026-02-11 | 2026-02-11 |

## 更新日志

### 2026-02-11
- 创建 TODO ticket 系统
- 添加 7 个初始任务 (2个P0, 2个P1, 3个P2)
- 标记 3 个P2任务为已完成（对应已实现的功能）

## 使用指南

1. **添加新任务**: 在相应优先级部分添加新 ticket
2. **更新状态**: 修改任务状态（待开始/进行中/已完成）
3. **记录完成**: 填写实际完成时间并添加验证说明
4. **定期审查**: 每周审查任务进度和优先级

## 贡献指南
- 每个任务应有清晰的描述和验证标准
- 完成任务后更新状态和验证信息
- 定期清理已完成的任务或归档到历史记录