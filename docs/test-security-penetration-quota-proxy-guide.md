# 基础安全渗透测试指南 - quota-proxy

## 概述

本文档提供 `test-security-penetration-quota-proxy.sh` 脚本的使用指南，该脚本用于对 quota-proxy 进行基础安全渗透测试，覆盖常见安全漏洞检查。

## 快速开始

### 1. 设置执行权限

```bash
chmod +x ./scripts/test-security-penetration-quota-proxy.sh
```

### 2. 查看帮助信息

```bash
./scripts/test-security-penetration-quota-proxy.sh --help
```

### 3. 运行基础测试

```bash
# 使用默认配置运行测试
./scripts/test-security-penetration-quota-proxy.sh

# 指定服务器地址和管理员token
./scripts/test-security-penetration-quota-proxy.sh \
  --host 127.0.0.1 \
  --port 8787 \
  --token your-admin-token-here
```

## 测试项目详解

脚本包含以下7个核心安全测试项目：

### 1. 认证绕过测试
- **目的**: 检查未经认证或使用无效凭证是否能访问受保护资源
- **测试内容**:
  - 无token访问admin接口
  - 使用无效token访问
  - 使用空token访问
  - POST请求无token访问
- **期望结果**: 所有未授权访问都应返回401 Unauthorized

### 2. 注入攻击测试
- **目的**: 检查系统对注入攻击的防护能力
- **测试内容**:
  - SQL注入测试（常见payload）
  - 检查服务器是否崩溃或返回异常错误
- **期望结果**: 服务器应正确处理恶意输入而不崩溃

### 3. 敏感信息泄露测试
- **目的**: 检查系统是否泄露敏感信息
- **测试内容**:
  - 错误信息中是否包含堆栈跟踪
  - API响应中是否包含密码、密钥等敏感信息
- **期望结果**: 错误信息应通用化，不泄露内部细节

### 4. 权限提升测试
- **目的**: 检查普通用户是否能访问管理员功能
- **测试内容**:
  - 使用普通用户token尝试访问admin接口
- **期望结果**: 普通用户应被拒绝访问管理员功能

### 5. 速率限制绕过测试
- **目的**: 检查速率限制机制的有效性
- **测试内容**:
  - 快速发送多个请求到健康检查端点
  - 快速发送多个请求到admin端点
- **期望结果**: 关键端点应有适当的速率限制

### 6. 输入验证测试
- **目的**: 检查系统对恶意输入的验证能力
- **测试内容**:
  - XSS攻击payload测试
  - 路径遍历攻击测试
  - Log4j漏洞测试
  - 二进制数据测试
- **期望结果**: 系统应正确处理或拒绝恶意输入

### 7. 错误信息泄露测试
- **目的**: 检查错误响应是否泄露内部信息
- **测试内容**:
  - 访问不存在的端点
  - 发送无效JSON数据
  - 使用无效API密钥
- **期望结果**: 错误信息应友好且不泄露技术细节

## 参数说明

| 参数 | 缩写 | 默认值 | 说明 |
|------|------|--------|------|
| `--host` | `-h` | `127.0.0.1` | 服务器主机地址 |
| `--port` | `-p` | `8787` | 服务器端口 |
| `--token` | `-t` | `test-admin-token` | ADMIN_TOKEN |
| `--format` | `-f` | `text` | 输出格式：text, json, markdown |
| `--timeout` | | `5` | 请求超时时间（秒） |
| `--dry-run` | | `false` | 只显示将要执行的测试，不实际运行 |
| `--verbose` | | `false` | 详细输出模式 |
| `--help` | | | 显示帮助信息 |

## 使用示例

### 示例1: 基础测试
```bash
./scripts/test-security-penetration-quota-proxy.sh
```

### 示例2: JSON格式输出
```bash
./scripts/test-security-penetration-quota-proxy.sh \
  --format json \
  --verbose
```

### 示例3: 模拟运行（不实际发送请求）
```bash
./scripts/test-security-penetration-quota-proxy.sh \
  --dry-run \
  --host example.com \
  --port 8080
```

### 示例4: 生产环境测试
```bash
./scripts/test-security-penetration-quota-proxy.sh \
  --host api.yourdomain.com \
  --port 443 \
  --token $(cat /path/to/admin-token.txt) \
  --timeout 10
```

## 输出说明

### 文本格式输出
```
=== 安全渗透测试报告 ===
测试时间: 2026-02-11 10:05:53 CST
目标服务器: http://127.0.0.1:8787
测试模式: 实际测试
详细模式: 否

[测试1] 认证绕过测试
  ✅ 无token访问被正确拒绝
  ✅ 无效token访问被正确拒绝
  ✅ 空token访问被正确拒绝
  ✅ POST无token访问被正确拒绝
...
```

### 颜色编码
- ✅ 绿色: 测试通过
- ⚠️ 黄色: 警告或需要注意
- ❌ 红色: 测试失败或发现安全问题

## 最佳实践

### 1. 定期测试
建议在以下情况下运行安全测试：
- 部署新版本前
- 添加新功能后
- 定期（如每周）安全检查
- 收到安全漏洞报告后

### 2. 测试环境
- **开发环境**: 频繁测试，使用详细输出
- **测试环境**: 完整测试，模拟生产配置
- **生产环境**: 谨慎测试，避免影响正常服务

### 3. 结果解读
- **所有测试通过**: 系统基础安全防护良好
- **有警告项**: 需要关注并考虑改进
- **有失败项**: 应立即修复的安全问题

### 4. 与其他工具结合
- 使用专业安全扫描工具（如 OWASP ZAP, Burp Suite）
- 结合代码安全扫描（如 SonarQube, Snyk）
- 定期进行第三方安全审计

## 故障排除

### 常见问题

#### 1. 连接失败
```
错误: 无法连接到服务器
```
**解决方案**:
- 检查服务器是否运行
- 检查防火墙设置
- 确认主机和端口正确

#### 2. 权限被拒绝
```
错误: 401 Unauthorized
```
**解决方案**:
- 确认ADMIN_TOKEN正确
- 检查token是否有访问权限
- 验证认证中间件配置

#### 3. 超时错误
```
错误: 请求超时
```
**解决方案**:
- 增加 `--timeout` 参数值
- 检查网络连接
- 确认服务器负载正常

#### 4. 脚本权限问题
```
bash: ./scripts/test-security-penetration-quota-proxy.sh: Permission denied
```
**解决方案**:
```bash
chmod +x ./scripts/test-security-penetration-quota-proxy.sh
```

## 安全注意事项

### 1. 测试范围
- 仅在授权范围内测试
- 避免对生产环境造成影响
- 遵守法律法规和道德规范

### 2. Token管理
- 不要将真实token提交到版本控制
- 使用环境变量或配置文件存储敏感信息
- 测试完成后及时撤销测试token

### 3. 测试影响
- 避免在高峰时段测试生产环境
- 监控系统资源使用情况
- 准备好回滚方案

### 4. 结果处理
- 妥善保存测试报告
- 及时修复发现的安全问题
- 记录安全改进措施

## 扩展和定制

### 1. 添加自定义测试
可以修改脚本添加特定测试项目：
```bash
# 在脚本中添加自定义测试函数
test_custom_vulnerability() {
    echo -e "${BLUE}[自定义测试] 特定漏洞测试${NC}"
    # 添加测试逻辑
}
```

### 2. 集成到CI/CD
将安全测试集成到持续集成流程：
```yaml
# GitHub Actions 示例
jobs:
  security-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: 运行安全测试
        run: |
          chmod +x ./scripts/test-security-penetration-quota-proxy.sh
          ./scripts/test-security-penetration-quota-proxy.sh \
            --host localhost \
            --port 8787 \
            --token ${{ secrets.ADMIN_TOKEN }}
```

### 3. 自动化报告
使用脚本生成自动化报告：
```bash
# 生成Markdown格式报告
./scripts/test-security-penetration-quota-proxy.sh \
  --format markdown \
  > security-report-$(date +%Y%m%d).md
```

## 相关资源

### 1. 安全标准
- OWASP Top 10
- CWE/SANS Top 25
- NIST Cybersecurity Framework

### 2. 工具推荐
- **动态扫描**: OWASP ZAP, Burp Suite
- **静态分析**: SonarQube, Snyk, Semgrep
- **依赖检查**: npm audit, yarn audit, pip-audit

### 3. 学习资源
- OWASP Web Security Testing Guide
- PortSwigger Web Security Academy
- SANS Security Training

---

**最后更新**: 2026-02-11  
**版本**: 1.0.0  
**维护者**: 阿爪推进循环