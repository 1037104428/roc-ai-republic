# CDN连接质量评估指南

## 概述

`evaluate-cdn-quality.sh` 是一个用于评估不同CDN源连接质量的脚本。它通过测试ping延迟、下载速度和连接稳定性来为每个CDN源计算质量分数，帮助 `install-cn.sh` 选择最优的下载源。

## 快速开始

### 基本使用

```bash
# 赋予执行权限
chmod +x ./scripts/evaluate-cdn-quality.sh

# 运行评估（使用默认CDN源）
./scripts/evaluate-cdn-quality.sh

# 指定要测试的CDN源
./scripts/evaluate-cdn-quality.sh --sources "https://mirrors.aliyun.com,https://mirrors.cloud.tencent.com"

# 使用JSON格式输出
./scripts/evaluate-cdn-quality.sh --format json

# 使用Markdown格式输出
./scripts/evaluate-cdn-quality.sh --format markdown
```

### 验证脚本功能

```bash
# 显示帮助信息
./scripts/evaluate-cdn-quality.sh --help

# 显示版本信息
./scripts/evaluate-cdn-quality.sh --version

# 测试基本功能
./scripts/evaluate-cdn-quality.sh --timeout 3 --retries 1
```

## 参数说明

### 主要参数

| 参数 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--sources` | `-s` | 要测试的CDN源URL列表，用逗号分隔 | 预定义的8个国内CDN源 |
| `--timeout` | `-t` | 每个测试的超时时间（秒） | 5 |
| `--retries` | `-r` | 失败重试次数 | 2 |
| `--format` | `-f` | 输出格式：text, json, markdown | text |
| `--verbose` | `-v` | 详细输出模式 | 关闭 |
| `--quiet` | `-q` | 安静模式，只输出结果 | 关闭 |
| `--test-file` |  | 用于下载速度测试的文件名 | 1M.test |
| `--test-size` |  | 测试文件大小（字节） | 1048576 (1MB) |
| `--help` | `-h` | 显示帮助信息 | - |
| `--version` |  | 显示版本信息 | - |

### 默认CDN源

脚本预定义了以下国内CDN源进行测试：

1. `https://mirrors.aliyun.com` - 阿里云镜像站
2. `https://mirrors.cloud.tencent.com` - 腾讯云镜像站
3. `https://mirrors.huaweicloud.com` - 华为云镜像站
4. `https://mirrors.163.com` - 网易镜像站
5. `https://mirrors.bfsu.edu.cn` - 北京外国语大学镜像站
6. `https://mirrors.tuna.tsinghua.edu.cn` - 清华大学镜像站
7. `https://mirrors.ustc.edu.cn` - 中国科学技术大学镜像站
8. `https://mirrors.sjtug.sjtu.edu.cn` - 上海交通大学镜像站

## 评估指标

### 1. Ping延迟（毫秒）
- 通过发送4个ping包计算平均延迟
- 延迟越低，网络响应越快
- 评分权重：40%

### 2. 下载速度（KB/s）
- 通过下载1MB测试文件计算下载速度
- 速度越高，下载效率越高
- 评分权重：40%

### 3. 连接稳定性（%）
- 通过3次连接测试计算成功率
- 稳定性越高，连接越可靠
- 评分权重：20%

### 4. 质量分数（0-100）
- 综合以上三个指标计算的总分
- 分数越高，CDN源质量越好

## 质量评分标准

| 分数范围 | 等级 | 说明 |
|----------|------|------|
| 90-100 | 优秀 | 延迟低、速度快、稳定性高，推荐使用 |
| 70-89 | 良好 | 各方面表现良好，适合使用 |
| 50-69 | 一般 | 基本可用，可能有优化空间 |
| 0-49 | 较差 | 建议考虑其他源 |

## 使用示例

### 示例1：基本评估

```bash
./scripts/evaluate-cdn-quality.sh
```

输出示例：
```
============================================================
CDN连接质量评估报告
生成时间: 2026-02-11 09:35:54 CST
============================================================

CDN源                                    延迟(ms)    速度(KB/s)      稳定性(%)    质量分
------                                    ---------    -----------     ---------    ------
https://mirrors.aliyun.com                45.2         1250.75         100          92
https://mirrors.cloud.tencent.com         52.1         980.32          100          85
https://mirrors.tuna.tsinghua.edu.cn      38.5         1105.43         100          90
...
```

### 示例2：JSON格式输出

```bash
./scripts/evaluate-cdn-quality.sh --format json
```

输出示例：
```json
[
  {
    "url": "https://mirrors.aliyun.com",
    "latency_ms": "45.2",
    "speed_kbps": "1250.75",
    "stability_percent": "100",
    "quality_score": "92"
  },
  ...
]
```

### 示例3：自定义源测试

```bash
./scripts/evaluate-cdn-quality.sh \
  --sources "https://mirrors.aliyun.com,https://mirrors.cloud.tencent.com" \
  --timeout 3 \
  --format markdown \
  --verbose
```

### 示例4：与install-cn.sh集成

```bash
# 先评估CDN质量
./scripts/evaluate-cdn-quality.sh --quiet --format json > cdn-quality.json

# 使用最优源进行安装
BEST_CDN=$(jq -r '.[0].url' cdn-quality.json)
./scripts/install-cn.sh --cdn-source "$BEST_CDN"
```

## 集成到install-cn.sh

### 自动选择最优源

可以在 `install-cn.sh` 中添加以下功能来自动选择最优CDN源：

```bash
# 在install-cn.sh中添加的函数
select_best_cdn_source() {
    log_info "正在评估CDN源质量..."
    
    # 运行评估脚本（安静模式，JSON输出）
    local cdn_results
    cdn_results=$(./scripts/evaluate-cdn-quality.sh --quiet --format json 2>/dev/null)
    
    if [[ -n "$cdn_results" ]]; then
        # 提取最优源URL
        local best_url
        best_url=$(echo "$cdn_results" | jq -r '.[0].url' 2>/dev/null)
        
        if [[ -n "$best_url" && "$best_url" != "null" ]]; then
            log_success "选择最优CDN源: $best_url"
            echo "$best_url"
            return 0
        fi
    fi
    
    # 如果评估失败，使用默认源
    log_warning "CDN质量评估失败，使用默认源"
    echo "https://mirrors.aliyun.com"
    return 1
}
```

### 优化网络策略

基于CDN质量评估结果，可以优化 `install-cn.sh` 的网络策略：

1. **智能源选择**：根据质量分数自动选择最优源
2. **故障转移**：当最优源不可用时，按质量分数降序尝试其他源
3. **性能优化**：根据网络质量调整下载参数（并发数、超时时间等）

## 最佳实践

### 1. 定期评估

建议定期运行CDN质量评估，因为网络状况可能随时间变化：

```bash
# 每周评估一次，保存结果
./scripts/evaluate-cdn-quality.sh --format json > /var/log/cdn-quality-$(date +%Y%m%d).json
```

### 2. 生产环境集成

在生产环境中，可以将CDN质量评估集成到部署流程中：

```bash
#!/bin/bash
# deploy-with-optimal-cdn.sh

# 评估CDN质量
echo "评估CDN源质量..."
CDN_QUALITY=$(./scripts/evaluate-cdn-quality.sh --quiet --format json)

# 检查评估结果
if [[ -z "$CDN_QUALITY" ]]; then
    echo "CDN质量评估失败，使用默认源"
    OPTIMAL_CDN="https://mirrors.aliyun.com"
else
    OPTIMAL_CDN=$(echo "$CDN_QUALITY" | jq -r '.[0].url')
    echo "选择最优CDN源: $OPTIMAL_CDN"
fi

# 使用最优CDN源进行部署
./scripts/install-cn.sh --cdn-source "$OPTIMAL_CDN" "$@"
```

### 3. 监控和告警

可以设置监控，当CDN质量下降时发出告警：

```bash
#!/bin/bash
# monitor-cdn-quality.sh

# 运行评估
RESULTS=$(./scripts/evaluate-cdn-quality.sh --quiet --format json)

# 检查最优源的质量分数
BEST_SCORE=$(echo "$RESULTS" | jq -r '.[0].quality_score')

# 如果质量分数低于阈值，发送告警
THRESHOLD=70
if (( $(echo "$BEST_SCORE < $THRESHOLD" | bc -l) )); then
    echo "警告: 最优CDN源质量分数低于阈值 ($BEST_SCORE < $THRESHOLD)"
    # 发送邮件或通知
    # send-alert "CDN质量下降" "最优CDN源质量分数: $BEST_SCORE"
fi
```

## 故障排除

### 常见问题

#### 1. 评估时间过长
**问题**: 评估过程耗时过长
**解决**: 
- 减少测试源数量：`--sources "源1,源2"`
- 缩短超时时间：`--timeout 3`
- 减少重试次数：`--retries 1`

#### 2. 下载速度测试失败
**问题**: 无法下载测试文件
**解决**:
- 检查网络连接
- 确认CDN源是否提供测试文件
- 使用 `--test-file` 指定其他测试文件

#### 3. Ping测试失败
**问题**: 无法ping通CDN源
**解决**:
- 检查防火墙设置
- 确认主机是否允许ping
- 使用 `--verbose` 查看详细错误信息

#### 4. 命令不存在
**问题**: 提示 `command not found`
**解决**:
- 安装必要命令：`sudo apt-get install curl bc` (Ubuntu/Debian)
- 或使用包管理器安装相应工具

### 调试模式

使用详细输出模式查看调试信息：

```bash
./scripts/evaluate-cdn-quality.sh --verbose
```

## 更新日志

### v2026.02.11.01 (2026-02-11)
- 初始版本发布
- 支持ping延迟、下载速度、连接稳定性测试
- 支持text/json/markdown三种输出格式
- 集成质量评分算法
- 提供详细的使用指南

## 相关资源

- [install-cn.sh 安装脚本](../scripts/install-cn.sh)
- [test-cdn-sources.sh CDN源测试脚本](../scripts/test-cdn-sources.sh)
- [TODO-install-cn-improvements.md 改进计划](./TODO-install-cn-improvements.md)
- [CDN连接质量评估原理文档](./cdn-quality-evaluation-principles.md) (待创建)

## 贡献指南

欢迎提交问题和改进建议：

1. 在GitHub仓库创建Issue
2. 提交Pull Request
3. 参与讨论和改进

## 许可证

本脚本遵循MIT许可证。详见 [LICENSE](../LICENSE) 文件。