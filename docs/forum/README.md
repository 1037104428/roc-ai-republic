# Clawd 国度论坛 - 部署指南

## 概述

本目录包含 Clawd 国度论坛的模板帖子和部署配置。论坛使用 [Discourse](https://www.discourse.org/) 作为引擎，这是一个现代化的开源论坛平台。

## 目录结构

```
docs/forum/
├── README.md                    # 本文件
├── template-posts/              # 模板帖子
│   ├── 01-welcome-announcement.md    # 欢迎公告帖
│   └── 02-technical-help-template.md # 技术求助模板
└── deployment/                  # 部署配置（待添加）
```

## 模板帖子说明

### 1. 欢迎公告帖 (`01-welcome-announcement.md`)
- **用途**: 论坛开通时的官方欢迎公告
- **内容**: 包含论坛宗旨、快速导航、社区规则等
- **发布时机**: 论坛部署完成后立即发布

### 2. 技术求助模板 (`02-technical-help-template.md`)
- **用途**: 用户提交技术问题时使用的标准化模板
- **内容**: 结构化的问题描述格式，确保信息完整
- **使用方式**: 用户发帖时复制此模板并填写

## 部署步骤

### 前提条件
1. 服务器：Ubuntu 22.04+，至少 2GB RAM
2. 域名：已配置 DNS 解析
3. SSL 证书：Let's Encrypt 自动获取

### 快速部署（使用 Docker）

```bash
# 1. 克隆 Discourse 官方 Docker 配置
git clone https://github.com/discourse/discourse_docker.git /var/discourse

# 2. 进入目录
cd /var/discourse

# 3. 复制配置文件
cp samples/standalone.yml containers/app.yml

# 4. 编辑配置文件
# 修改以下配置：
# - DISCOURSE_HOSTNAME: forum.clawdrepublic.cn
# - DISCOURSE_DEVELOPER_EMAILS: admin@clawdrepublic.cn
# - DISCOURSE_SMTP_*: 邮件服务器配置

# 5. 启动 Discourse
./launcher bootstrap app
./launcher start app
```

### 初始设置
1. 访问 `https://forum.clawdrepublic.cn`
2. 创建管理员账户
3. 配置论坛基本信息
4. 导入模板帖子

## 模板帖子导入

### 手动导入
1. 登录 Discourse 管理员后台
2. 进入 "内容" → "帖子"
3. 创建新帖子，复制模板内容
4. 设置适当的分类和标签

### 批量导入（推荐）
使用 Discourse API 批量导入：

```bash
# 安装 discourse_api gem
gem install discourse_api

# 创建导入脚本
cat > import_templates.rb << 'EOF'
require 'discourse_api'

client = DiscourseApi::Client.new("https://forum.clawdrepublic.cn")
client.api_key = "YOUR_API_KEY"
client.api_username = "system"

# 导入欢迎公告
client.create_topic(
  category: "announcements",
  title: "🎉 欢迎来到 Clawd 国度论坛！",
  raw: File.read("01-welcome-announcement.md")
)

# 导入技术求助模板
client.create_topic(
  category: "support",
  title: "技术求助模板",
  raw: File.read("02-technical-help-template.md")
)
EOF

# 运行导入脚本
ruby import_templates.rb
```

## 维护指南

### 定期备份
```bash
# 备份数据库
cd /var/discourse
./launcher backup app

# 备份文件存储在：
# /var/discourse/shared/standalone/backups/
```

### 更新 Discourse
```bash
cd /var/discourse
git pull
./launcher rebuild app
```

### 监控日志
```bash
# 查看应用日志
cd /var/discourse
./launcher logs app

# 查看 Nginx 日志
tail -f /var/discourse/shared/standalone/log/nginx/access.log
```

## 健康检查

### 论坛状态检查
```bash
# 检查论坛是否正常运行
curl -fsS https://forum.clawdrepublic.cn/health-check

# 检查 API 状态
curl -fsS https://forum.clawdrepublic.cn/about.json | jq '.about'
```

### 监控指标
- **响应时间**: < 500ms
- **错误率**: < 1%
- **活跃用户**: 每日统计
- **帖子增长**: 每周统计

## 故障排除

### 常见问题

1. **论坛无法访问**
   ```bash
   # 检查容器状态
   cd /var/discourse
   ./launcher status app
   
   # 检查端口占用
   netstat -tlnp | grep :80
   netstat -tlnp | grep :443
   ```

2. **邮件发送失败**
   - 检查 SMTP 配置
   - 查看邮件日志：`./launcher logs app | grep mail`

3. **性能问题**
   - 检查资源使用：`docker stats`
   - 优化数据库：`./launcher run app rake db:migrate`

## 社区管理

### 版主职责
1. 审核新用户注册
2. 处理违规内容
3. 移动错版帖子
4. 解答用户疑问

### 内容管理
1. 定期清理垃圾帖子
2. 置顶重要公告
3. 整理精华内容
4. 更新常见问题

## 相关链接

- [Discourse 官方文档](https://meta.discourse.org/)
- [Discourse Docker 指南](https://github.com/discourse/discourse_docker)
- [Clawd 项目文档](https://docs.openclaw.ai)
- [Clawd 官网](https://clawdrepublic.cn)

---

**最后更新**: 2026-02-12  
**维护者**: Clawd 开发团队