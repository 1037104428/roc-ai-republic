#!/bin/bash
# 论坛置顶帖初始化脚本
# 用于在论坛部署后创建标准化的置顶帖

set -e

# 配置
FORUM_URL="${FORUM_URL:-https://forum.clawdrepublic.cn}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
FORUM_API_KEY="${FORUM_API_KEY:-}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装 curl"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq 未安装，请先安装 jq"
        exit 1
    fi
}

# 获取 API key
get_api_key() {
    if [ -n "$FORUM_API_KEY" ]; then
        echo "$FORUM_API_KEY"
        return 0
    fi
    
    log_warn "未设置 FORUM_API_KEY，尝试通过登录获取"
    
    if [ -z "$ADMIN_PASSWORD" ]; then
        log_error "需要设置 ADMIN_PASSWORD 环境变量"
        exit 1
    fi
    
    local response
    response=$(curl -s -X POST "$FORUM_URL/api/v2/users/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}" \
        --max-time 30)
    
    if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
        echo "$response" | jq -r '.token'
    else
        log_error "登录失败: $response"
        exit 1
    fi
}

# 创建置顶帖
create_sticky_post() {
    local api_key="$1"
    local category_id="$2"
    local title="$3"
    local content="$4"
    
    log_info "创建置顶帖: $title"
    
    local response
    response=$(curl -s -X POST "$FORUM_URL/api/v2/topics" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "{
            \"cid\": $category_id,
            \"title\": \"$title\",
            \"content\": \"$content\",
            \"pinned\": true,
            \"locked\": false
        }" \
        --max-time 30)
    
    if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
        local topic_id
        topic_id=$(echo "$response" | jq -r '.topic.tid')
        log_info "创建成功，主题ID: $topic_id"
        echo "$topic_id"
    else
        log_error "创建失败: $response"
        return 1
    fi
}

# 新手入门帖内容
newbie_guide_content() {
    cat << 'EOF'
# 必读·新手入门（从 0 到 1）注册安装接入

欢迎来到 Clawd 国度！本贴将指导你完成从注册到使用的完整流程。

## 1. 注册账号
1. 访问 [Clawd 官网](https://clawdrepublic.cn)
2. 点击右上角"注册"按钮
3. 填写邮箱、用户名、密码完成注册
4. 验证邮箱激活账号

## 2. 安装 OpenClaw
### 国内用户推荐使用国内源安装：
```bash
# 下载安装脚本
curl -fsSL https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/scripts/install-cn.sh | bash

# 或手动安装
git clone https://gitee.com/junkaiWang324/roc-ai-republic.git
cd roc-ai-republic
./scripts/install-cn.sh
```

### 国际用户：
```bash
npm install -g openclaw
```

## 3. 获取 TRIAL_KEY
1. 在本论坛"TRIAL_KEY 申请"板块发帖申请
2. 使用以下模板：
```
【TRIAL_KEY 申请】
- 用途：个人学习/项目开发/团队测试
- 预计用量：每月约 X 万 tokens
- 使用场景：API 网关代理、额度管理
- 联系方式：邮箱/Telegram
```

## 4. 配置与验证
```bash
# 配置 TRIAL_KEY
export ROC_API_KEY="你的_TRIAL_KEY"
export ROC_BASE_URL="https://api.clawdrepublic.cn"

# 验证安装
openclaw --version

# 测试连接
curl -fsS https://api.clawdrepublic.cn/healthz
```

## 5. 常见问题
### Q: 安装失败怎么办？
A: 检查网络连接，尝试使用备用源：
```bash
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | bash
```

### Q: TRIAL_KEY 无效？
A: 确保 KEY 格式正确，检查是否过期，或重新申请。

### Q: API 连接超时？
A: 检查网络代理设置，或联系管理员。

## 6. 获取帮助
- 查看官方文档：https://clawdrepublic.cn/docs
- 在"问题求助"板块提问
- 加入 Telegram 群组：[链接待补充]

---
*最后更新: $(date '+%Y-%m-%d')*
*维护者: Clawd 国度管理团队*
EOF
}

# TRIAL_KEY 申请帖内容
trial_key_content() {
    cat << 'EOF'
# 必读·TRIAL_KEY 申请与使用（复制粘贴版）

本贴提供 TRIAL_KEY 的标准申请流程和使用指南。

## 申请前准备
1. 已注册 Clawd 国度账号
2. 了解基本使用场景
3. 准备好联系方式

## 发帖模板（复制填写）
在"TRIAL_KEY 申请"板块发新帖，使用以下模板：

```
【TRIAL_KEY 申请】

### 基本信息
- 用户名：[你的论坛用户名]
- 注册邮箱：[注册时使用的邮箱]

### 使用信息
- 用途：□个人学习 □项目开发 □团队测试 □其他______
- 预计每月用量：______ 万 tokens
- 主要使用场景：API 网关代理、额度管理、开发测试等

### 技术环境
- 操作系统：□Linux □macOS □Windows □其他
- 部署方式：□本地 □云服务器 □容器
- 预计接入应用数量：______ 个

### 承诺与声明
- 我承诺遵守使用条款，不用于违法用途
- 我理解这是试用额度，可能根据使用情况调整
- 我愿意提供使用反馈帮助改进服务

### 联系方式
- 邮箱：[备用联系邮箱]
- Telegram：[可选]
- 其他：[可选]
```

## 审核流程
1. **提交申请** - 在对应板块发帖
2. **人工审核** - 1-3个工作日内管理员审核
3. **发放 KEY** - 审核通过后通过站内信发送 TRIAL_KEY
4. **开始使用** - 配置 KEY 开始试用

## 额度说明
- **试用额度**：每月 10 万 tokens（可申请调整）
- **有效期**：30天（可续期）
- **续期条件**：正常使用、提供反馈、无违规行为

## 拿到 KEY 后的使用步骤
1. 配置环境变量：
```bash
export ROC_API_KEY="你的_TRIAL_KEY"
export ROC_BASE_URL="https://api.clawdrepublic.cn"
```

2. 验证 KEY 有效性：
```bash
curl -H "Authorization: Bearer $ROC_API_KEY" \
  https://api.clawdrepublic.cn/v1/status
```

3. 开始接入应用

## 注意事项
1. KEY 请妥善保管，不要公开分享
2. 每月1号重置用量统计
3. 用量达到80%时会收到预警通知
4. 如需增加额度，可申请评估

## 问题反馈
- 使用问题：在"问题求助"板块提问
- 额度问题：站内信联系管理员
- 违规举报：contact@clawdrepublic.cn

---
*最后更新: $(date '+%Y-%m-%d')*
*维护者: Clawd 国度管理团队*
EOF
}

# 发帖模板帖内容
post_template_content() {
    cat << 'EOF'
# 发帖模板与遇到问题怎么问才能最快解决（复制填写）

正确提问能帮你更快获得解答。请根据问题类型选择合适的模板。

## 通用提问模板
```
【问题类型】标题简要描述问题

### 问题描述
[清晰描述遇到的问题]

### 环境信息
- 操作系统：
- OpenClaw 版本：
- Node.js 版本：
- 网络环境：

### 已尝试的解决步骤
1. [步骤1]
2. [步骤2]
3. [步骤3]

### 错误信息
[粘贴完整的错误日志]

### 期望结果
[描述期望的正常表现]

### 附加信息
- 相关配置：
- 截图/日志文件：
```

## 分类模板

### 安装问题
```
【安装问题】OpenClaw 安装失败

### 错误信息
[完整错误日志]

### 安装命令
[使用的安装命令]

### 系统信息
- 发行版：
- 内核版本：
- 网络代理：

### 已尝试
1. 更换安装源
2. 检查网络连接
3. 查看文档 troubleshooting
```

### API 使用问题
```
【API 问题】quota-proxy 返回 403

### 请求详情
- 端点：
- 请求头：
- 请求体：

### 配置信息
- ROC_API_KEY：[已脱敏]
- ROC_BASE_URL：
- 应用配置：

### 响应信息
- 状态码：
- 响应头：
- 响应体：
```

### 额度问题
```
【额度问题】用量统计不准确

### 问题表现
[描述具体表现]

### 相关配置
- 应用ID：
- 统计周期：
- 预期用量：

### 核查信息
- 管理面板显示：
- 日志记录：
- 时间范围：
```

## 提问技巧

### 要做的事：
1. **先搜索** - 在论坛搜索类似问题
2. **提供上下文** - 完整的错误信息和环境
3. **简化复现步骤** - 提供最小复现代码
4. **使用代码块** - 日志和代码用 \`\`\` 包裹
5. **保持礼貌** - 大家都是在帮忙

### 不要做的事：
1. ❌ 只说"不行了"、"出错了"
2. ❌ 不提供错误信息
3. ❌ 不描述已尝试的解决步骤
4. ❌ 同时问多个不相关的问题
5. ❌ 催促回复或表现不耐烦

## 快速自查清单
遇到问题先按顺序检查：
1. ✅ 网络连接是否正常
2. ✅ 配置是否正确（KEY、URL）
3. ✅ 服务是否运行（docker compose ps）
4. ✅ 日志是否有错误（docker compose logs）
5. ✅ 版本是否兼容

## 紧急问题
如果遇到生产环境紧急问题：
1. 在标题标注【紧急】
2. 提供业务影响程度
3. 提供可联系时间
4. 可同时邮件联系：contact@clawdrepublic.cn

---
*最后更新: $(date '+%Y-%m-%d')*
*维护者: Clawd 国度管理团队*
EOF
}

# 主函数
main() {
    log_info "开始初始化论坛置顶帖"
    log_info "论坛地址: $FORUM_URL"
    
    check_dependencies
    
    # 获取 API key
    local api_key
    api_key=$(get_api_key)
    log_info "获取到 API key: ${api_key:0:10}..."
    
    # 注意：这里需要实际的分类ID，需要根据论坛实际情况调整
    # 以下是示例ID，实际使用时需要替换
    local newbie_category_id=2    # 新手入门分类
    local trial_category_id=3     # TRIAL_KEY 申请分类
    local help_category_id=4      # 问题求助分类
    
    log_warn "请根据实际论坛分类ID修改脚本中的分类ID"
    log_warn "当前使用的分类ID：新手=$newbie_category_id, TRIAL_KEY=$trial_category_id, 帮助=$help_category_id"
    
    # 创建置顶帖
    log_info "创建置顶帖（需要实际分类ID，当前为演示模式）"
    
    # 生成帖子内容
    local newbie_content
    local trial_content
    local template_content
    
    newbie_content=$(newbie_guide_content)
    trial_content=$(trial_key_content)
    template_content=$(post_template_content)
    
    # 保存帖子内容到文件（供手动使用）
    mkdir -p ./forum-templates
    echo "$newbie_content" > ./forum-templates/newbie-guide.md
    echo "$trial_content" > ./forum-templates/trial-key-guide.md
    echo "$template_content" > ./forum-templates/post-template.md
    
    log_info "帖子内容已保存到 ./forum-templates/"
    log_info "请手动登录论坛后台创建置顶帖"
    
    # 显示使用说明
    cat << EOF

=== 手动创建置顶帖步骤 ===

1. 登录论坛后台: $FORUM_URL/login
2. 进入对应分类创建新主题
3. 复制对应模板内容：
   - 新手入门: ./forum-templates/newbie-guide.md
   - TRIAL_KEY申请: ./forum-templates/trial-key-guide.md
   - 发帖模板: ./forum-templates/post-template.md
4. 设置为"置顶"和"锁定"
5. 发布主题

=== 自动化配置（需要正确分类ID）===

修改脚本中的分类ID变量，然后运行：
FORUM_API_KEY="你的API密钥" ./scripts/init-forum-sticky-posts.sh

EOF
    
    log_info "论坛置顶帖初始化准备完成"
}

# 显示帮助
show_help() {
    cat << 'EOF'
论坛置顶帖初始化脚本

用法:
  ./scripts/init-forum-sticky-posts.sh [选项]

选项:
  --help              显示此帮助信息
  --manual            生成模板文件供手动使用（默认）
  --auto              尝试自动创建（需要配置环境变量）

环境变量:
  FORUM_URL           论坛地址 (默认: https://forum.clawdrepublic.cn)
  ADMIN_USERNAME      管理员用户名 (默认: admin)
  ADMIN_PASSWORD      管理员密码
  FORUM_API_KEY       论坛API密钥（优先使用）

示例:
  # 生成模板文件供手动使用
  ./scripts/init-forum-sticky-posts.sh

  # 自动创建（需要API密钥）
  FORUM_API_KEY="your-api-key-here" ./scripts/init-forum-sticky-posts.sh --auto

  # 使用用户名密码自动创建
  ADMIN_PASSWORD="your-password" ./scripts/init-forum-sticky-posts.sh --auto
EOF
}

# 解析参数
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# 执行主函数
main