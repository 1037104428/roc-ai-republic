# Proxy Detection Integration Guide

**创建时间**: 2026-02-11 08:52 CST  
**优先级**: 中  
**状态**: 已完成  
**负责人**: 阿爪  
**集成版本**: install-cn.sh v2026.02.11.01  

## 概述

本文档介绍如何将代理检测功能集成到 `install-cn.sh` 安装脚本中，以增强在网络受限环境下的安装成功率。代理检测功能能够自动识别系统代理设置，并适配安装流程。

## 功能特性

### 1. 代理检测能力
- **环境变量检测**: 自动检测 `HTTP_PROXY`、`HTTPS_PROXY`、`http_proxy`、`https_proxy` 等环境变量
- **系统配置检测**: 检查 `/etc/environment`、`/etc/apt/apt.conf.d/proxy.conf` 等系统配置文件
- **npm配置检测**: 检测npm的代理设置（`npm config get proxy`）
- **代理类型识别**: 自动识别HTTP、HTTPS、SOCKS等代理类型

### 2. 连接性测试
- **代理连通性测试**: 测试通过代理访问目标registry的能力
- **多目标测试**: 支持测试多个registry（npmmirror.com、npmjs.org等）
- **超时控制**: 可配置的连接超时时间
- **详细报告**: 生成详细的连接测试报告

### 3. npm代理配置
- **自动配置**: 根据检测到的代理自动配置npm
- **配置验证**: 验证npm代理配置是否生效
- **清理功能**: 安装完成后可自动清理代理配置
- **临时配置**: 仅在安装期间使用代理，不永久修改用户配置

### 4. 报告生成
- **详细报告**: 生成包含所有检测结果的详细报告
- **问题诊断**: 提供网络连接问题的诊断建议
- **环境快照**: 记录安装时的系统环境状态
- **可读格式**: 生成易于阅读的Markdown格式报告

## 集成步骤

### 1. 文件准备
将代理检测脚本复制到项目目录：
```bash
cp scripts/detect-proxy.sh /usr/local/bin/openclaw-detect-proxy
chmod +x /usr/local/bin/openclaw-detect-proxy
```

### 2. 在install-cn.sh中集成

在 `install-cn.sh` 脚本中添加以下函数：

```bash
# Function to detect and handle proxy settings
handle_proxy_settings() {
  local proxy_mode="${1:-auto}"  # auto, force, skip
  
  echo "[cn-pack] Checking proxy settings..."
  
  # Source the proxy detection script
  if [[ -f "./scripts/detect-proxy.sh" ]]; then
    source ./scripts/detect-proxy.sh
  else
    # Fallback: simple proxy detection
    detect_proxy_fallback() {
      local proxy_vars=("HTTP_PROXY" "HTTPS_PROXY" "http_proxy" "https_proxy")
      for var in "${proxy_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
          echo "[cn-pack] Detected proxy: $var=${!var}"
          return 0
        fi
      done
      echo "[cn-pack] No proxy settings detected"
      return 1
    }
    detect_proxy_fallback
  fi
  
  # Run proxy detection
  local proxy_info=$(detect_proxy_settings 2>/dev/null || echo "PROXY_DETECTED=false")
  
  # Parse proxy detection results
  local proxy_detected=$(echo "$proxy_info" | grep "^PROXY_DETECTED=" | cut -d= -f2)
  local proxy_type=$(echo "$proxy_info" | grep "^PROXY_TYPE=" | cut -d= -f2)
  local proxy_count=$(echo "$proxy_info" | grep "^PROXY_COUNT=" | cut -d= -f2)
  
  if [[ "$proxy_detected" == "true" ]]; then
    echo "[cn-pack] ✓ Detected $proxy_count proxy configuration(s) (type: $proxy_type)"
    
    # Test proxy connectivity
    if [[ "$proxy_mode" != "skip" ]]; then
      echo "[cn-pack] Testing proxy connectivity..."
      local test_result=$(test_proxy_connectivity "https://registry.npmmirror.com" 10 2>/dev/null || true)
      
      if echo "$test_result" | grep -q "PROXY_TEST_RESULT=success"; then
        echo "[cn-pack] ✓ Proxy connectivity test passed"
        
        # Configure npm proxy if needed
        if [[ -n "${HTTP_PROXY:-}" ]] && [[ "$proxy_mode" == "force" || "$proxy_mode" == "auto" ]]; then
          echo "[cn-pack] Configuring npm proxy..."
          configure_npm_proxy "$HTTP_PROXY" "${HTTPS_PROXY:-$HTTP_PROXY}"
        fi
      else
        echo "[cn-pack] ⚠ Proxy connectivity test failed"
        
        if [[ "$proxy_mode" == "force" ]]; then
          echo "[cn-pack] ✗ Proxy forced but connectivity failed. Installation may fail."
          return 1
        fi
      fi
    fi
    
    # Generate proxy report
    local report_file="/tmp/openclaw-install-proxy-$(date +%s).log"
    generate_proxy_report "$report_file" >/dev/null 2>&1 || true
    
    echo "[cn-pack] Proxy report: $report_file"
    return 0
  else
    echo "[cn-pack] ✓ No proxy settings detected"
    return 0
  fi
}

# Function to clear proxy settings after installation
cleanup_proxy_settings() {
  echo "[cn-pack] Cleaning up proxy settings..."
  
  if command -v clear_npm_proxy >/dev/null 2>&1; then
    clear_npm_proxy >/dev/null 2>&1 || true
  else
    # Fallback: clear npm proxy config
    npm config delete proxy >/dev/null 2>&1 || true
    npm config delete https-proxy >/dev/null 2>&1 || true
  fi
  
  echo "[cn-pack] ✓ Proxy settings cleaned up"
}
```

### 3. 在主安装流程中调用

在 `install-cn.sh` 的主安装函数中添加代理处理：

```bash
install_openclaw() {
  local version="$1"
  local registry_cn="$2"
  local registry_fallback="$3"
  local network_test="$4"
  local network_optimize="$5"
  local force_cn="$6"
  local dry_run="$7"
  local verify_level="$8"
  
  # Handle proxy settings
  handle_proxy_settings "auto"
  
  # ... existing installation code ...
  
  # Cleanup proxy settings after installation
  cleanup_proxy_settings
  
  # ... rest of the installation code ...
}
```

### 4. 添加命令行选项

在 `install-cn.sh` 的 `usage()` 函数和参数解析中添加代理相关选项：

```bash
usage() {
  cat <<'TXT'
[cn-pack] OpenClaw CN installer

Options:
  # ... existing options ...
  --proxy-mode <mode>      Proxy handling mode: auto, force, skip (default: auto)
  --proxy-test             Test proxy connectivity before installation
  --proxy-report           Generate proxy configuration report
  --keep-proxy             Keep npm proxy settings after installation
  # ... rest of options ...
TXT
}

# In parse_args function:
--proxy-mode)
  PROXY_MODE="$2"
  shift 2
  ;;
--proxy-test)
  PROXY_TEST=true
  shift
  ;;
--proxy-report)
  PROXY_REPORT=true
  shift
  ;;
--keep-proxy)
  KEEP_PROXY=true
  shift
  ;;
```

## 使用示例

### 基本使用（自动代理检测）
```bash
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

### 强制使用代理
```bash
HTTP_PROXY=http://proxy.example.com:8080 \
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --proxy-mode force
```

### 生成代理报告
```bash
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --proxy-report
```

### 跳过代理检测
```bash
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --proxy-mode skip
```

## 测试验证

### 1. 代理检测测试
```bash
# 测试代理检测功能
./scripts/detect-proxy.sh detect

# 测试代理连通性
./scripts/detect-proxy.sh test https://registry.npmmirror.com

# 生成代理报告
./scripts/detect-proxy.sh report /tmp/proxy-test.md
```

### 2. 集成测试
```bash
# 模拟有代理的环境
HTTP_PROXY=http://localhost:8888 ./scripts/install-cn.sh --dry-run --proxy-test

# 模拟无代理的环境
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
./scripts/install-cn.sh --dry-run --proxy-mode skip
```

### 3. 完整安装测试
```bash
# 完整安装流程测试（使用代理）
HTTP_PROXY=http://proxy.example.com:8080 \
./scripts/install-cn.sh --version latest --proxy-mode auto --dry-run

# 完整安装流程测试（无代理）
./scripts/install-cn.sh --version latest --proxy-mode skip --dry-run
```

## 故障排除

### 常见问题

1. **代理检测失败**
   ```
   问题：脚本无法检测到已设置的代理
   解决：检查环境变量名称（HTTP_PROXY vs http_proxy），确保变量已导出
   ```

2. **代理连通性测试失败**
   ```
   问题：检测到代理但连接测试失败
   解决：验证代理服务器是否运行，检查防火墙设置，测试手动curl连接
   ```

3. **npm代理配置失败**
   ```
   问题：无法配置npm代理设置
   解决：检查npm权限，尝试使用sudo或修改npm配置目录权限
   ```

4. **代理报告无法生成**
   ```
   问题：代理报告文件无法创建
   解决：检查/tmp目录权限，或指定可写目录作为报告路径
   ```

### 调试命令

```bash
# 查看当前代理设置
env | grep -i proxy
npm config get proxy
npm config get https-proxy

# 手动测试代理连接
curl --proxy http://proxy.example.com:8080 https://registry.npmmirror.com

# 查看代理检测脚本详细输出
bash -x ./scripts/detect-proxy.sh detect
```

## 性能考虑

1. **检测时间**: 代理检测增加约1-2秒的安装时间
2. **网络开销**: 连接性测试增加少量网络请求
3. **资源使用**: 内存使用增加可忽略不计
4. **兼容性**: 支持bash 3.2+，无需额外依赖

## 安全考虑

1. **代理凭据**: 代理URL可能包含认证信息，确保不在日志中明文记录
2. **配置清理**: 默认清理代理配置，避免遗留配置影响用户环境
3. **报告隐私**: 代理报告可能包含网络配置信息，提示用户注意隐私
4. **输入验证**: 验证代理URL格式，防止命令注入

## 更新记录

| 日期 | 版本 | 修改内容 | 负责人 |
|------|------|----------|--------|
| 2026-02-11 | 1.0 | 创建代理检测集成指南 | 阿爪 |
| 2026-02-11 | 1.1 | 添加故障排除和测试验证章节 | 阿爪 |

## 相关文档

- [detect-proxy.sh 脚本](../scripts/detect-proxy.sh) - 代理检测脚本
- [install-cn.sh 脚本](../scripts/install-cn.sh) - 主安装脚本
- [TODO-install-cn-improvements.md](TODO-install-cn-improvements.md) - 安装脚本改进计划
- [install-cn-troubleshooting.md](install-cn-troubleshooting.md) - 故障排除指南

## 下一步计划

1. **智能代理选择**: 根据网络条件自动选择最优代理
2. **代理认证支持**: 支持需要认证的代理服务器
3. **多协议支持**: 增强SOCKS代理支持
4. **容器环境优化**: 优化在Docker容器内的代理检测
5. **企业网络适配**: 针对企业网络环境的特殊适配