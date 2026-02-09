# 论坛信息架构设计

## 概述
Clawd 国度社区论坛 MVP 版本，目标是建立一个轻量级、可扩展的讨论平台。

## 核心功能
1. **用户系统**：匿名/注册用户发帖
2. **版块分类**：技术讨论、项目展示、问题求助、公告区
3. **帖子管理**：发帖、回复、置顶、精华
4. **内容审核**：基础关键词过滤、人工审核队列

## 技术栈选择
- **前端**：Vue.js + Tailwind CSS
- **后端**：Node.js + Express
- **数据库**：SQLite（轻量）或 PostgreSQL（生产）
- **部署**：Docker + Nginx

## 数据结构
```sql
-- 用户表
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE,
  email TEXT UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 版块表
CREATE TABLE categories (
  id INTEGER PRIMARY KEY,
  name TEXT,
  description TEXT,
  order_index INTEGER
);

-- 帖子表
CREATE TABLE posts (
  id INTEGER PRIMARY KEY,
  title TEXT,
  content TEXT,
  author_id INTEGER REFERENCES users(id),
  category_id INTEGER REFERENCES categories(id),
  is_pinned BOOLEAN DEFAULT FALSE,
  is_featured BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 回复表
CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  content TEXT,
  post_id INTEGER REFERENCES posts(id),
  author_id INTEGER REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 初始版块设置
1. **公告区**（pinned）：官方公告、规则说明
2. **技术讨论**：OpenClaw、MCP、Agent 开发
3. **项目展示**：社区项目分享
4. **问题求助**：技术问题解答
5. **意见建议**：功能反馈

## 置顶帖模板
### 1. 欢迎帖（公告区）
```
标题：欢迎来到 Clawd 国度社区论坛！
内容：
欢迎各位开发者、爱好者和贡献者！

本论坛是 Clawd 国度项目的官方社区讨论平台，旨在：
- 分享 OpenClaw 使用经验
- 讨论 MCP 服务器开发
- 展示个人项目作品
- 解决技术问题
- 收集功能建议

请遵守社区规则，保持友好交流氛围。

【社区规则】
1. 尊重他人，文明讨论
2. 禁止广告、 spam
3. 技术问题请发到对应版块
4. 反馈建议请提供具体场景
```

### 2. 快速入门指南（技术讨论）
```
标题：[新手必读] OpenClaw 极速入门指南
内容：
## 1. 安装 OpenClaw
```bash
npm install -g openclaw
```

## 2. 基础配置
```bash
# 初始化配置
openclaw init

# 启动网关
openclaw gateway start
```

## 3. 第一个技能
创建 `skills/my-skill/SKILL.md`：
```markdown
# 我的技能
描述：这是一个示例技能
```

## 4. 常见问题
Q: 如何连接 MCP 服务器？
A: 使用 `mcporter` 工具或编辑 config.json
```

## 部署计划
### 阶段1：基础论坛（1周）
- 基础发帖/回复功能
- 版块分类
- 简单用户系统

### 阶段2：增强功能（2周）
- 搜索功能
- 用户权限管理
- 内容审核后台

### 阶段3：社区集成（1周）
- GitHub OAuth 登录
- Discord 同步
- API 接口开放

## 下一步行动
1. 创建 GitHub 仓库：clawd-community-forum
2. 初始化项目结构
3. 实现基础 CRUD 接口
4. 部署测试环境