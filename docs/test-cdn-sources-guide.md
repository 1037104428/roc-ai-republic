# CDN源测试脚本使用指南

## 概述

`test-cdn-sources.sh` 是一个轻量级的CDN源测试工具，用于测试多个国内CDN源的连接速度和可用性。该脚本为 `install-cn.sh` 选择最优源提供数据支持，帮助在网络受限环境下选择最快的安装源。

## 快速开始

### 1. 授予执行权限
```bash
chmod +x ./scripts/test-cdn-sources.sh
```

### 2. 基本使用
```bash
# 测试所有预配置的CDN源
./scripts/test-cdn-sources.sh

# 详细输出模式
./scripts/test-cdn-sources.sh --verbose

# 自定义超时时间和重试次数
./scripts/test-cdn-sources.sh --timeout 10 --retries 3
```

### 3. 输出格式选择
```bash
# 文本格式（默认）
./scripts/test-cdn-sources.sh

# JSON格式
./scripts/test-cdn-sources.sh --format json

# Markdown格式
./scripts/test-cdn-sources.sh --format markdown
```

## 功能特性

### 1. 多CDN源测试
脚本预配置了多个国内可达的CDN源：
- `https://registry.npmmirror.com` - 阿里云镜像
- `https://mirrors.cloud.tencent.com/npm` - 腾讯云镜像
- `https://registry.npm.taobao.org` - 淘宝NPM镜像
- `https://npm.pkg.github.com` - GitHub Packages
- `https://registry.yarnpkg.com` - Yarn官方源

### 2. 连接质量评估
脚本测量以下指标：
- **可用性**：成功连接的比例
- **平均响应时间**：多次测试的平均值
- **最佳响应时间**：最快的一次响应
- **最差响应时间**：最慢的一次响应

### 3. 智能推荐
脚本根据测试结果自动排序，推荐响应时间最短的CDN源。

## 参数说明

| 参数 | 缩写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--timeout N` | `-t N` | 设置超时时间（秒） | `5` |
| `--retries N` | `-r N` | 设置重试次数 | `2` |
| `--format FORMAT` | `-f FORMAT` | 输出格式（text/json/markdown） | `text` |
| `--test-url URL` | - | 测试特定URL | - |

## 使用示例

### 示例1：快速测试
```bash
./scripts/test-cdn-sources.sh
```
输出示例：
```
[INFO] 开始CDN源测试
[INFO] 超时时间: 5秒
[INFO] 重试次数: 2次
[INFO] 测试源数量: 5

========================================
[INFO] 测试 URL: https://registry.npmmirror.com
  ✅ 可用性: 100% (2/2)
     平均响应时间: 245ms
     最佳响应时间: 230ms
     最差响应时间: 260ms

========================================
[SUCCESS] 找到 5 个可用CDN源
推荐顺序（按响应时间排序）:
----------------------------------------
1. https://registry.npmmirror.com
   可用性: 100% | 平均响应: 245ms
2. https://mirrors.cloud.tencent.com/npm
   可用性: 100% | 平均响应: 320ms

[SUCCESS] 推荐使用: https://registry.npmmirror.com
   理由: 平均响应时间最短 (245ms)，可用性 100%
```

### 示例2：JSON格式输出
```bash
./scripts/test-cdn-sources.sh --format json --timeout 8
```
输出示例：
```json
{
  "test_results": [
    {
      "url": "https://registry.npmmirror.com",
      "availability_percent": 100,
      "avg_response_ms": 245,
      "best_response_ms": 230,
      "worst_response_ms": 260
    }
  ]
}
```

### 示例3：测试特定URL
```bash
./scripts/test-cdn-sources.sh --test-url https://example.com --verbose
```

## 集成到 install-cn.sh

### 1. 在安装前测试最优源
可以在 `install-cn.sh` 中添加以下逻辑：
```bash
# 测试CDN源并选择最优
if [ "$ENABLE_CDN_TEST" = "true" ]; then
    echo "正在测试CDN源..."
    BEST_CDN=$(./scripts/test-cdn-sources.sh --format json | jq -r '.test_results[0].url')
    echo "选择最优CDN源: $BEST_CDN"
    export NPM_REGISTRY="$BEST_CDN"
fi
```

### 2. 作为网络诊断工具
```bash
# 网络诊断模式
if [ "$NETWORK_DIAGNOSTIC" = "true" ]; then
    echo "=== 网络诊断报告 ==="
    ./scripts/test-cdn-sources.sh --verbose
    echo "=== 诊断完成 ==="
fi
```

## 最佳实践

### 1. 生产环境使用
```bash
# 增加测试可靠性
./scripts/test-cdn-sources.sh --timeout 10 --retries 3

# 定期测试更新最优源
0 */6 * * * cd /path/to/roc-ai-republic && ./scripts/test-cdn-sources.sh --format json > /var/log/cdn-test.log
```

### 2. 故障排除
```bash
# 检查脚本权限
ls -la ./scripts/test-cdn-sources.sh

# 检查依赖
which curl

# 测试单个源
./scripts/test-cdn-sources.sh --test-url https://registry.npmmirror.com --verbose

# 查看详细错误
bash -x ./scripts/test-cdn-sources.sh 2>&1 | tee debug.log
```

### 3. 自定义CDN源列表
编辑脚本中的 `CDN_SOURCES` 数组添加自定义源：
```bash
# 在脚本中修改
CDN_SOURCES=(
    "https://registry.npmmirror.com"
    "https://mirrors.cloud.tencent.com/npm"
    "https://custom.cdn.example.com"  # 添加自定义源
)
```

## 退出码说明

| 退出码 | 说明 |
|--------|------|
| 0 | 成功完成测试 |
| 1 | 参数错误或脚本错误 |
| 2 | 没有可用的CDN源 |
| 3 | 依赖命令缺失（如curl） |

## 更新记录

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持多CDN源测试
- 支持三种输出格式
- 提供智能推荐功能
- 完整的参数支持和错误处理

## 相关文档

- [install-cn.sh 安装脚本](../scripts/install-cn.sh)
- [TODO-install-cn-improvements.md](TODO-install-cn-improvements.md) - 安装脚本改进计划
- [代理检测集成指南](proxy-detection-integration-guide.md) - 网络优化相关文档

## 技术支持

如有问题，请参考：
1. 检查脚本权限：`chmod +x ./scripts/test-cdn-sources.sh`
2. 检查curl是否安装：`which curl`
3. 查看详细日志：添加 `--verbose` 参数
4. 提交Issue到项目仓库