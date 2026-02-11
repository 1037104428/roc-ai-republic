# 论坛引擎部署指南

## 概述

本文档提供 Clawd 社区论坛引擎的部署方案，包含开源论坛系统的选择、部署步骤、权限配置和与现有系统的集成方案。

## 论坛系统选择

### 候选方案

1. **Discourse**
   - 优点：功能完整、现代化、社区活跃、插件丰富
   - 缺点：资源消耗较大、部署相对复杂
   - 适合：大型社区、需要完整功能

2. **Flarum**
   - 优点：轻量级、现代化、扩展性强
   - 缺点：插件生态相对较小
   - 适合：中小型社区、追求简洁

3. **NodeBB**
   - 优点：Node.js 开发、实时性强、性能好
   - 缺点：插件生态一般
   - 适合：技术社区、需要实时功能

### 推荐方案：Flarum

基于 Clawd 社区的当前规模和需求，推荐使用 **Flarum**：
- 轻量级，资源消耗小
- 现代化界面，用户体验好
- 易于定制和扩展
- 部署相对简单

## 部署架构

```
┌─────────────────┐
│  用户浏览器     │
└────────┬────────┘
         │ HTTPS
┌────────▼────────┐
│  Nginx 反向代理 │
└────────┬────────┘
         │
┌────────▼────────┐
│   Flarum 应用   │
├─────────────────┤
│  PHP 8.1+       │
│  MySQL 8.0+     │
│  Redis 缓存     │
└─────────────────┘
```

## 部署步骤

### 1. 环境准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础依赖
sudo apt install -y nginx mysql-server redis-server

# 安装 PHP 8.1+
sudo apt install -y php8.1 php8.1-fpm php8.1-mysql php8.1-mbstring \
    php8.1-tokenizer php8.1-xml php8.1-curl php8.1-gd \
    php8.1-zip php8.1-redis php8.1-intl
```

### 2. 数据库配置

```bash
# 登录 MySQL
sudo mysql

# 创建数据库和用户
CREATE DATABASE clawd_forum CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'clawd_forum'@'localhost' IDENTIFIED BY 'secure_password_here';
GRANT ALL PRIVILEGES ON clawd_forum.* TO 'clawd_forum'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. 安装 Composer

```bash
# 下载 Composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/local/bin/composer
```

### 4. 安装 Flarum

```bash
# 创建项目目录
sudo mkdir -p /var/www/clawd-forum
sudo chown -R $USER:$USER /var/www/clawd-forum
cd /var/www/clawd-forum

# 通过 Composer 创建 Flarum 项目
composer create-project flarum/flarum .

# 设置目录权限
sudo chown -R www-data:www-data /var/www/clawd-forum/storage
sudo chown -R www-data:www-data /var/www/clawd-forum/public/assets
sudo chmod -R 775 /var/www/clawd-forum/storage
sudo chmod -R 775 /var/www/clawd-forum/public/assets
```

### 5. Nginx 配置

创建 `/etc/nginx/sites-available/clawd-forum`：

```nginx
server {
    listen 80;
    server_name forum.clawd.ai;
    root /var/www/clawd-forum/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~* \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_index index.php;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

启用站点：
```bash
sudo ln -s /etc/nginx/sites-available/clawd-forum /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 6. 完成安装

访问 `http://forum.clawd.ai` 完成 Flarum 的 Web 安装向导，填写数据库信息和管理员账户。

## 权限配置

### 用户角色体系

1. **管理员 (Administrator)**
   - 完全控制论坛
   - 管理用户、版块、插件、设置

2. **版主 (Moderator)**
   - 管理指定版块
   - 审核帖子、管理用户

3. **会员 (Member)**
   - 发帖、回复、投票
   - 参与社区讨论

4. **游客 (Guest)**
   - 浏览公开内容
   - 注册账户

### 权限矩阵

| 权限 | 管理员 | 版主 | 会员 | 游客 |
|------|--------|------|------|------|
| 创建版块 | ✓ | ✗ | ✗ | ✗ |
| 编辑版块 | ✓ | ✗ | ✗ | ✗ |
| 删除版块 | ✓ | ✗ | ✗ | ✗ |
| 置顶帖子 | ✓ | ✓ | ✗ | ✗ |
| 删除帖子 | ✓ | ✓ | ✗ | ✗ |
| 编辑他人帖子 | ✓ | ✓ | ✗ | ✗ |
| 发帖 | ✓ | ✓ | ✓ | ✗ |
| 回复 | ✓ | ✓ | ✓ | ✗ |
| 浏览 | ✓ | ✓ | ✓ | ✓ |

## 与现有系统集成

### 1. 用户系统集成

**方案A：SSO（单点登录）**
- 使用 OAuth 2.0 或 OpenID Connect
- 现有用户系统作为身份提供者
- Flarum 通过插件支持 SSO

**方案B：用户同步**
- 定期同步用户数据
- 使用 API 或数据库同步
- 保持用户信息一致

### 2. 内容同步

**论坛与文档系统同步：**
- 技术讨论 → 文档更新
- FAQ 帖子 → 官方文档 FAQ
- 教程帖子 → 教程文档

### 3. 通知集成

**统一通知中心：**
- 论坛回复通知
- @提及通知
- 私信通知
- 与现有通知系统集成

## 扩展插件推荐

### 核心插件
1. **flarum/tags** - 标签/版块管理
2. **flarum/likes** - 点赞功能
3. **flarum/mentions** - @提及功能
4. **flarum/subscriptions** - 订阅功能

### 增强插件
1. **fof/oauth** - OAuth 集成
2. **fof/sitemap** - 站点地图
3. **fof/formatting** - 富文本格式化
4. **fof/nightmode** - 夜间模式

### Clawd 定制插件
1. **clawd-integration** - 与 Clawd 系统集成
2. **clawd-badges** - 成就徽章系统
3. **clawd-gamification** - 游戏化元素

## 维护与监控

### 日常维护
```bash
# 更新 Flarum
cd /var/www/clawd-forum
composer update --prefer-dist --no-dev -a

# 清理缓存
php flarum cache:clear

# 备份数据库
mysqldump -u clawd_forum -p clawd_forum > /backup/clawd-forum-$(date +%Y%m%d).sql
```

### 监控指标
1. **性能监控**
   - 页面加载时间
   - 数据库查询性能
   - 内存使用情况

2. **业务监控**
   - 活跃用户数
   - 新帖子/回复数
   - 用户留存率

3. **安全监控**
   - 登录失败次数
   - 可疑活动检测
   - 安全更新提醒

## 故障排除

### 常见问题

1. **502 Bad Gateway**
   ```bash
   # 检查 PHP-FPM 状态
   sudo systemctl status php8.1-fpm
   
   # 检查 socket 权限
   ls -la /var/run/php/php8.1-fpm.sock
   ```

2. **数据库连接错误**
   ```bash
   # 检查 MySQL 服务
   sudo systemctl status mysql
   
   # 检查用户权限
   mysql -u clawd_forum -p -e "SHOW GRANTS;"
   ```

3. **文件权限问题**
   ```bash
   # 修复权限
   sudo chown -R www-data:www-data /var/www/clawd-forum/storage
   sudo chmod -R 775 /var/www/clawd-forum/storage
   ```

## 下一步计划

### 短期目标（1-2周）
1. 完成 Flarum 基础部署
2. 配置基本版块和权限
3. 导入初始内容（置顶帖）

### 中期目标（1个月）
1. 实现用户系统集成
2. 部署定制插件
3. 建立内容管理流程

### 长期目标（3个月）
1. 完善游戏化系统
2. 建立社区治理机制
3. 实现与其他系统深度集成

## 参考资料

1. [Flarum 官方文档](https://docs.flarum.org/)
2. [Flarum 中文社区](https://discuss.flarum.org.cn/)
3. [Nginx 配置指南](https://nginx.org/en/docs/)
4. [PHP-FPM 配置](https://www.php.net/manual/zh/install.fpm.configuration.php)

---

**最后更新：** 2026-02-11  
**维护者：** Clawd 社区技术团队  
**状态：** 草案 - 待评审