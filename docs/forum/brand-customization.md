# Clawd 国度论坛品牌定制指南

## 概述
为 Flarum 论坛添加 Clawd 品牌元素，提升品牌识别度和用户体验。

## 品牌元素

### 1. 颜色方案
- **主色调**: `#4D698E` (深蓝色)
- **辅助色**: `#6C8CB5` (浅蓝色)
- **强调色**: `#FF6B35` (橙色)
- **背景色**: `#F8F9FA` (浅灰色)
- **文字色**: `#333333` (深灰色)

### 2. 字体
- **英文**: `Inter` 或 `Roboto`
- **中文**: `PingFang SC`, `Microsoft YaHei`, `sans-serif`
- **代码**: `Monaco`, `Consolas`, `monospace`

### 3. Logo
- **主 Logo**: Clawd 爪印图标 + "Clawd 国度" 文字
- **尺寸**: 建议 200×60px (导航栏), 400×120px (页头)
- **格式**: SVG (优先) 或 PNG (透明背景)

## 定制步骤

### 阶段1：基础样式定制

#### 1.1 修改主题颜色
创建自定义 CSS 文件 `assets/forum/custom.css`：

```css
/* 主色调 */
:root {
  --clawd-primary: #4D698E;
  --clawd-secondary: #6C8CB5;
  --clawd-accent: #FF6B35;
  --clawd-bg: #F8F9FA;
  --clawd-text: #333333;
}

/* 应用主色调 */
.DiscussionList-nav .item--active,
.Button--primary,
.Checkbox:checked + .Checkbox-display {
  background-color: var(--clawd-primary) !important;
  border-color: var(--clawd-primary) !important;
}

/* 链接颜色 */
a,
.Post-body a {
  color: var(--clawd-primary) !important;
}

a:hover,
.Post-body a:hover {
  color: var(--clawd-secondary) !important;
}

/* 导航栏 */
.Navigation {
  background-color: var(--clawd-primary) !important;
}

/* 按钮悬停 */
.Button--primary:hover {
  background-color: var(--clawd-secondary) !important;
  border-color: var(--clawd-secondary) !important;
}

/* 强调元素 */
.Badge--highlight {
  background-color: var(--clawd-accent) !important;
}
```

#### 1.2 添加 Logo
在 Flarum 后台配置：
1. 进入 "管理" → "外观"
2. 上传 Logo 图片
3. 设置 Logo 高度（建议 40px）
4. 设置 Favicon

或通过 CSS 自定义：
```css
/* 自定义 Logo */
.Header-logo img {
  content: url('https://clawdrepublic.cn/logo.png');
  height: 40px;
  width: auto;
}
```

### 阶段2：高级定制

#### 2.1 自定义页脚
在 `config.php` 中添加：

```php
'custom_footer' => '
<div class="Container">
  <div class="Footer">
    <div class="Footer-links">
      <a href="https://clawdrepublic.cn">官网首页</a>
      <a href="https://clawdrepublic.cn/quickstart.html">新手教程</a>
      <a href="https://clawdrepublic.cn/quota-proxy.html">API 配额</a>
      <a href="/privacy">隐私政策</a>
      <a href="/terms">服务条款</a>
    </div>
    <div class="Footer-copyright">
      © 2026 Clawd 国度论坛 · 面向纯新手的 AI 自建社区
    </div>
    <div class="Footer-social">
      <a href="https://github.com/clawd" title="GitHub"><i class="fab fa-github"></i></a>
      <a href="https://discord.gg/clawd" title="Discord"><i class="fab fa-discord"></i></a>
    </div>
  </div>
</div>
',
```

#### 2.2 自定义欢迎信息
修改 `config.php`：

```php
'welcome_title' => '欢迎来到 Clawd 国度',
'welcome_message' => '这里是 Clawd 国度论坛：面向纯新手的中文 AI 自建社区。

建议先看：站点首页 → 小白一条龙（免翻墙） → 试用/配额 API（TRIAL_KEY）申请与使用。

发帖求助时，请尽量带上：
- 你在做哪一步（复制了哪条命令/点了哪个按钮）
- 你看到的完整报错（原样粘贴）
- 你的系统/环境（Windows/macOS/Linux、是否 Docker、是否 WSL）

我们尽量做到：一步一步、复制粘贴、告诉你"你应该看到什么"。',
```

### 阶段3：扩展功能

#### 3.1 安装品牌相关扩展
推荐扩展：
1. **flarum/tags** - 标签管理（已安装）
2. **flarum/lock** - 帖子锁定
3. **flarum/sticky** - 置顶帖子（已使用）
4. **flarum/bbcode** - BBCode 支持
5. **clarkwinkelmann/author-change** - 允许修改发帖人
6. **askvortsov/flarum-rich-text** - 富文本编辑器

#### 3.2 自定义板块图标
为每个板块设置自定义图标：

```css
/* 新手入门板块 */
.TagIcon[data-tag-slug="getting-started"]::before {
  content: "🌱";
}

/* TRIAL_KEY 申请板块 */
.TagIcon[data-tag-slug="trial-key"]::before {
  content: "🔑";
}

/* 问题求助板块 */
.TagIcon[data-tag-slug="help"]::before {
  content: "🆘";
}

/* Clawd 入驻板块 */
.TagIcon[data-tag-slug="clawd-onboarding"]::before {
  content: "🐾";
}

/* 杂谈板块 */
.TagIcon[data-tag-slug="general"]::before {
  content: "💬";
}
```

## 品牌资产文件

### 1. Logo 文件
创建目录 `assets/brand/` 并添加：
- `logo.svg` - SVG 矢量 Logo
- `logo-200x60.png` - 导航栏 Logo
- `logo-400x120.png` - 页头 Logo
- `favicon.ico` - 网站图标
- `apple-touch-icon.png` - iOS 图标

### 2. 颜色配置文件
创建 `assets/brand/colors.css`：

```css
/* Clawd 品牌颜色系统 */
:root {
  /* 主色系 */
  --color-primary-50: #E8EDF5;
  --color-primary-100: #C5D2E6;
  --color-primary-200: #9FB5D5;
  --color-primary-300: #7A98C4;
  --color-primary-400: #5E83B8;
  --color-primary-500: #4D698E; /* 主色调 */
  --color-primary-600: #455F81;
  --color-primary-700: #3C5472;
  --color-primary-800: #344A64;
  --color-primary-900: #25384A;
  
  /* 辅助色 */
  --color-secondary-500: #6C8CB5;
  
  /* 强调色 */
  --color-accent-500: #FF6B35;
  
  /* 中性色 */
  --color-gray-50: #F8F9FA;
  --color-gray-100: #E9ECEF;
  --color-gray-200: #DEE2E6;
  --color-gray-300: #CED4DA;
  --color-gray-400: #ADB5BD;
  --color-gray-500: #6C757D;
  --color-gray-600: #495057;
  --color-gray-700: #343A40;
  --color-gray-800: #212529;
  --color-gray-900: #121416;
  
  /* 功能色 */
  --color-success: #28A745;
  --color-warning: #FFC107;
  --color-danger: #DC3545;
  --color-info: #17A2B8;
}
```

### 3. 字体文件
如果使用自定义字体，添加：
- `assets/fonts/Inter.woff2`
- `assets/fonts/Inter.woff`
- `assets/fonts/Inter.ttf`

## 实施步骤

### 步骤1：准备品牌资产
1. 设计或获取 Clawd Logo
2. 确定颜色方案
3. 准备字体文件（如果需要）

### 步骤2：基础配置
1. 上传 Logo 和 Favicon
2. 配置欢迎信息
3. 设置基础颜色

### 步骤3：CSS 定制
1. 创建 `custom.css` 文件
2. 应用品牌颜色
3. 添加自定义样式

### 步骤4：高级定制
1. 自定义页脚
2. 设置板块图标
3. 安装必要扩展

### 步骤5：测试与优化
1. 在不同设备上测试显示效果
2. 收集用户反馈
3. 优化加载性能

## 性能优化建议

### 1. 图片优化
```bash
# 压缩 PNG 图片
optipng -o7 logo.png

# 压缩 SVG
svgo logo.svg

# 生成 WebP 格式
cwebp logo.png -o logo.webp
```

### 2. CSS 优化
- 合并 CSS 文件
- 移除未使用的样式
- 使用 CSS 变量
- 启用 CSS 压缩

### 3. 缓存策略
```nginx
# Nginx 配置
location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## 维护指南

### 1. 定期检查
- 每月检查品牌一致性
- 测试所有自定义功能
- 更新过时的内容

### 2. 备份策略
```bash
# 备份品牌资产
tar -czf brand-assets-$(date +%Y%m%d).tar.gz assets/brand/ assets/forum/custom.css

# 备份配置
cp config.php config-backup-$(date +%Y%m%d).php
```

### 3. 版本控制
- 使用 Git 管理自定义文件
- 记录每次修改的原因
- 维护更新日志

## 故障排除

### 常见问题

#### 1. Logo 不显示
```
检查：
- 文件路径是否正确
- 文件权限是否可读
- 文件格式是否支持
- 缓存是否已清除
```

#### 2. CSS 不生效
```
检查：
- CSS 文件路径
- 缓存问题（强制刷新 Ctrl+F5）
- CSS 语法错误
- 选择器优先级
```

#### 3. 颜色不一致
```
检查：
- CSS 变量定义
- 浏览器兼容性
- 颜色值格式
- 继承关系
```

### 调试工具
```javascript
// 在浏览器控制台检查样式
// 检查元素样式
$0.style

// 检查计算样式
getComputedStyle($0)

// 检查 CSS 变量
getComputedStyle(document.documentElement).getPropertyValue('--clawd-primary')
```

## 扩展开发（可选）

如果需要深度定制，可以考虑开发 Flarum 扩展：

### 简单扩展结构
```
clawd-brand-extension/
├── src/
│   ├── Extend/
│   │   └── Forum.php
│   └── Providers/
│       └── BrandServiceProvider.php
├── resources/
│   ├── less/
│   │   └── forum.less
│   └── views/
│       └── footer.blade.php
├── composer.json
└── extend.php
```

## 下一步行动

### 短期（本周）
1. [ ] 准备品牌资产（Logo、颜色方案）
2. [ ] 配置基础品牌元素
3. [ ] 测试显示效果

### 中期（本月）
1. [ ] 完成高级定制
2. [ ] 优化性能
3. [ ] 收集用户反馈

### 长期（本季度）
1. [ ] 开发品牌扩展
2. [ ] 建立品牌指南
3. [ ] 培训社区管理员

---
*最后更新: 2026-02-10*
*状态: 规划阶段*