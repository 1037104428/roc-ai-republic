# Clawd 国度 - 开源 AI 社区项目

欢迎来到 Clawd 国度！这是一个面向 AI 开发者的开源社区项目，包含额度代理服务、社区论坛和开发者工具。

## 🚀 快速开始

如果你是第一次接触 Clawd 国度，请从这里开始：

1. **阅读小白教程**：[小白一条龙：从拿到 Key 到第一次调用](./roc-ai-republic/docs/小白一条龙_从拿到key到第一次调用.md) - 5分钟完成第一次 AI 调用
2. **申请试用密钥**：[TRIAL_KEY 申请指南](./docs/website/quota-proxy-trial-key.md)
3. **加入社区**：[论坛信息架构](./docs/forum/info-architecture.md)

## 📁 项目结构

```
.
├── docs/                    # 项目文档
│   ├── tutorials/          # 教程与指南
│   ├── website/           # 官网文档
│   ├── forum/             # 论坛相关文档
│   ├── quota-proxy/       # 额度代理文档
│   └── posts/             # 技术文章与公告
├── roc-ai-republic/       # 主代码仓库（子模块）
├── scripts/               # 部署与维护脚本
└── memory/                # 项目记忆与日志
```

## 🛠️ 核心组件

### 1. quota-proxy（额度代理服务）
- **功能**: API 调用额度管理、试用密钥发放、用量统计
- **文档**: [quota-proxy 文档](./docs/quota-proxy/)
- **状态**: ✅ 文档完善，待部署验证

### 2. 论坛引擎（社区平台）
- **功能**: 开发者交流、问题讨论、公告发布
- **文档**: [论坛部署指南](./docs/forum/)
- **状态**: 🟡 文档完善，待 Docker 部署

### 3. 官网文档
- **功能**: 项目介绍、教程、API 文档
- **文档**: [官网文档](./docs/website/README.md)
- **状态**: ✅ 基础结构完成

## 🚧 当前进展

### 已完成
- [x] 小白教程文档体系
- [x] quota-proxy 文档与 API 设计
- [x] 论坛信息架构设计
- [x] 官网文档结构搭建
- [x] 部署脚本编写

### 进行中
- [ ] quota-proxy 服务部署与验证
- [ ] 论坛 Docker 部署
- [ ] 自助申请 TRIAL_KEY 流程实现
- [ ] 官网静态站点生成

## 🧪 测试与验证

### API 测试
```bash
# 验证 admin API
./roc-ai-republic/scripts/verify-admin-api.sh

# 测试 quota-proxy 部署
./scripts/deploy-quota-proxy.sh
```

### 论坛部署测试
```bash
# 启动论坛服务
./scripts/deploy-forum.sh
```

## 🤝 参与贡献

### 开发流程
1. Fork 项目仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 文档贡献
- 完善教程文档
- 翻译多语言版本
- 修复文档错误

### 代码贡献
- 修复 bug
- 添加新功能
- 优化性能

## 📞 联系与支持

- **问题反馈**: 在论坛「问题反馈」板块发帖
- **功能建议**: 提交 GitHub Issue
- **紧急联系**: 管理员邮箱

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](./roc-ai-republic/LICENSE) 文件了解详情。

---

**最后更新**: 2026-02-09  
**项目状态**: 🟡 开发中（文档完善，服务待部署）  
**下一步重点**: 部署验证核心服务，实现自助申请流程

> 💡 提示：本项目正在积极开发中，文档和功能会持续更新。
