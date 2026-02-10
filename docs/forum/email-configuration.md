# Flarum 邮件系统配置指南

## 概述
为 Clawd 国度论坛配置邮件通知系统，支持：
- 新用户邮箱验证
- 密码重置
- 帖子回复通知
- 私信通知
- 系统公告

## 推荐邮件服务商

### 1. SendGrid（推荐）
- **优点**: 免费额度充足（100封/天），API 简单，送达率高
- **注册**: https://sendgrid.com
- **免费计划**: 100封/天，无需信用卡

### 2. Mailgun
- **优点**: 开发者友好，API 强大
- **注册**: https://www.mailgun.com
- **免费计划**: 5000封/月，需要验证信用卡

### 3. SMTP2GO
- **优点**: 简单易用，免费额度充足
- **注册**: https://www.smtp2go.com
- **免费计划**: 1000封/月

### 4. 腾讯企业邮 / 阿里云邮件推送
- **优点**: 国内服务，送达率高
- **缺点**: 需要备案域名和企业认证

## SendGrid 配置步骤

### 步骤1：注册 SendGrid 账户
1. 访问 https://sendgrid.com
2. 点击 "Start for Free"
3. 使用 GitHub 或 Google 登录
4. 选择 "I'm a Developer"
5. 创建 API Key（选择 "Full Access"）

### 步骤2：验证发件人域名
1. 在 SendGrid 控制台 → Settings → Sender Authentication
2. 点击 "Authenticate Your Domain"
3. 按照向导添加 DNS 记录：
   ```
   TXT 记录: v=spf1 include:sendgrid.net ~all
   CNAME 记录: emXXXX.sendgrid.net (SendGrid 提供)
   CNAME 记录: s1._domainkey.clawdrepublic.cn → s1.domainkey.uXXXX.sendgrid.net
   CNAME 记录: s2._domainkey.clawdrepublic.cn → s2.domainkey.uXXXX.sendgrid.net
   ```

### 步骤3：获取 API Key
1. 在 SendGrid 控制台 → Settings → API Keys
2. 点击 "Create API Key"
3. 命名: "Flarum Forum"
4. 权限: "Full Access"
5. 复制生成的 API Key（只显示一次）

## Flarum 邮件配置

### 方法1：通过 Flarum 后台配置
1. 登录 Flarum 管理员账户
2. 进入 "管理" → "邮件"
3. 配置以下设置：
   ```
   邮件驱动: SMTP
   Host: smtp.sendgrid.net
   Port: 587 (TLS) 或 465 (SSL)
   加密: TLS (推荐)
   用户名: apikey
   密码: [你的 SendGrid API Key]
   发件人地址: forum@clawdrepublic.cn
   发件人名称: Clawd 国度论坛
   ```

### 方法2：通过配置文件配置
编辑 Flarum 的 `config.php` 文件：

```php
<?php

return [
    'mail_driver' => 'smtp',
    'mail_host' => 'smtp.sendgrid.net',
    'mail_port' => 587,
    'mail_username' => 'apikey',
    'mail_password' => 'SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    'mail_encryption' => 'tls',
    'mail_from' => 'forum@clawdrepublic.cn',
    'mail_from_name' => 'Clawd 国度论坛',
];
```

### 方法3：通过环境变量配置（推荐）
在服务器上设置环境变量：

```bash
# 编辑 /etc/environment 或创建 .env 文件
export MAIL_DRIVER=smtp
export MAIL_HOST=smtp.sendgrid.net
export MAIL_PORT=587
export MAIL_USERNAME=apikey
export MAIL_PASSWORD=SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export MAIL_ENCRYPTION=tls
export MAIL_FROM_ADDRESS=forum@clawdrepublic.cn
export MAIL_FROM_NAME="Clawd 国度论坛"
```

## 测试邮件配置

### 测试命令
```bash
# 在 Flarum 目录下执行
php flarum mail:test admin@example.com
```

### 通过 Flarum 后台测试
1. 进入 "管理" → "邮件"
2. 点击 "发送测试邮件"
3. 输入测试邮箱地址
4. 检查是否收到测试邮件

## 邮件模板定制

### 修改欢迎邮件
编辑文件：`/vendor/flarum/core/src/Mail/NewUserWelcomeMail.php`

或通过扩展修改：
1. 安装 `flarum/translations` 扩展
2. 在语言文件中覆盖邮件模板

### 自定义邮件主题
在 `config.php` 中添加：
```php
'mail_theme' => [
    'primary_color' => '#4D698E',  // Clawd 主题色
    'logo_url' => 'https://clawdrepublic.cn/logo.png',
    'footer_text' => 'Clawd 国度论坛 - 面向纯新手的 AI 自建社区',
],
```

## 故障排除

### 常见问题

#### 1. 邮件发送失败
```
检查项：
- API Key 是否正确
- 端口是否被防火墙阻挡
- 域名是否已验证
- 发件人地址是否已验证
```

#### 2. 邮件进入垃圾箱
```
解决方法：
- 完善 SPF/DKIM/DMARC 记录
- 使用已验证的发件人域名
- 避免发送频率过高
- 添加退订链接
```

#### 3. 连接超时
```
解决方法：
- 检查网络连接
- 尝试使用端口 465 (SSL)
- 检查服务器防火墙设置
```

### 日志查看
```bash
# 查看 Flarum 邮件日志
tail -f /var/log/flarum/mail.log

# 查看 PHP 错误日志
tail -f /var/log/php7.4-fpm.log
```

## 监控与维护

### 1. 发送量监控
- 定期检查 SendGrid 控制台的统计数据
- 设置发送量告警（超过 80% 时通知）

### 2. 送达率监控
- 监控退信率和投诉率
- 定期清理无效邮箱地址

### 3. 安全性
- 定期轮换 API Key
- 监控异常发送行为
- 设置发送频率限制

## 自动化配置脚本

创建配置脚本 `scripts/configure-email.sh`：

```bash
#!/bin/bash

# 配置 Flarum 邮件
echo "配置 Flarum 邮件系统..."

# 设置环境变量
cat > /opt/flarum/.env << EOF
MAIL_DRIVER=smtp
MAIL_HOST=smtp.sendgrid.net
MAIL_PORT=587
MAIL_USERNAME=apikey
MAIL_PASSWORD=${SENDGRID_API_KEY}
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=forum@clawdrepublic.cn
MAIL_FROM_NAME="Clawd 国度论坛"
EOF

# 重启 PHP-FPM
systemctl restart php7.4-fpm

# 测试配置
cd /opt/flarum
php flarum mail:test admin@clawdrepublic.cn

echo "邮件配置完成！"
```

## 最佳实践

1. **分阶段启用**：
   - 第一阶段：仅启用邮箱验证
   - 第二阶段：启用密码重置
   - 第三阶段：启用通知功能

2. **用户教育**：
   - 在注册页面说明邮箱验证的重要性
   - 提供邮箱验证失败的处理指南
   - 设置常见问题解答

3. **备份配置**：
   - 定期备份邮件配置
   - 记录 API Key 的创建时间和用途
   - 准备备用邮件服务商

## 下一步
1. 注册 SendGrid 账户并验证域名
2. 配置 Flarum 邮件设置
3. 测试邮件发送功能
4. 监控邮件送达率
5. 根据反馈优化配置

---
*最后更新: 2026-02-10*
*状态: 待配置*