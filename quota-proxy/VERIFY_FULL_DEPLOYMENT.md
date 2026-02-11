# VERIFY_FULL_DEPLOYMENT.md - 完整部署流程验证指南

## 概述

`verify-full-deployment.sh` 脚本提供 quota-proxy 完整部署流程的验证功能。该脚本通过一系列检查步骤，确保部署环境、依赖、配置和服务都处于正常工作状态。

## 快速开始

### 前提条件

- Bash 4.0+
- curl
- Docker 和 docker-compose
- jq (JSON 处理工具)

### 基本使用

1. **授予执行权限**:
   ```bash
   chmod +x verify-full-deployment.sh
   ```

2. **运行验证**:
   ```bash
   ./verify-full-deployment.sh
   ```

3. **查看验证结果**:
   脚本将显示详细的验证结果，包括成功、警告和错误信息。

### 示例输出

```
[INFO] 开始验证quota-proxy完整部署流程
[INFO] 配置:
[INFO]   - 端口: 8787
[INFO]   - 健康端点: http://127.0.0.1:8787/healthz
[INFO]   - 状态端点: http://127.0.0.1:8787/status
[INFO]   - 模型端点: http://127.0.0.1:8787/v1/models
[INFO]   - 干运行: false
[INFO]   - 安静模式: false
[INFO]   - 详细模式: false

[INFO] 步骤1: 环境依赖检查
[INFO] 命令 'curl' 可用
[INFO] 命令 'docker' 可用
[INFO] 命令 'docker-compose' 可用
[INFO] 命令 'jq' 可用

[INFO] 步骤2: Docker环境检查
[SUCCESS] Docker守护进程正在运行

...更多验证步骤...

[INFO] 验证总结:
[INFO]   - 成功: 10
[INFO]   - 警告: 2
[INFO]   - 错误: 0
[WARNING] 验证通过，但有 2 个警告
```

## 功能特性

### 验证步骤

脚本执行以下10个验证步骤:

1. **环境依赖检查**: 检查必需的命令行工具
2. **Docker环境检查**: 验证Docker守护进程状态
3. **配置文件检查**: 检查关键配置文件是否存在
4. **服务端口检查**: 验证服务端口是否被占用
5. **健康端点检查**: 测试健康检查端点可达性
6. **状态端点检查**: 验证状态端点返回有效JSON
7. **模型端点检查**: 验证模型列表端点返回有效JSON
8. **Docker容器检查**: 检查quota-proxy容器运行状态
9. **试用密钥流程验证**: (可选)验证试用密钥功能
10. **管理API验证**: (可选)验证管理API功能

### 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--port PORT` | 指定quota-proxy端口 | `8787` |
| `--health-endpoint URL` | 指定健康检查端点 | `http://127.0.0.1:8787/healthz` |
| `--status-endpoint URL` | 指定状态检查端点 | `http://127.0.0.1:8787/status` |
| `--models-endpoint URL` | 指定模型列表端点 | `http://127.0.0.1:8787/v1/models` |
| `--dry-run` | 干运行模式，只显示将要执行的命令 | `false` |
| `--quiet` | 安静模式，减少输出 | `false` |
| `--verbose` | 详细模式，显示更多信息 | `false` |
| `--help` | 显示帮助信息 | - |

### 环境变量

| 变量 | 描述 | 默认值 |
|------|------|--------|
| `PORT` | 指定quota-proxy端口 | `8787` |
| `HEALTH_ENDPOINT` | 指定健康检查端点 | `http://127.0.0.1:8787/healthz` |
| `STATUS_ENDPOINT` | 指定状态检查端点 | `http://127.0.0.1:8787/status` |
| `MODELS_ENDPOINT` | 指定模型列表端点 | `http://127.0.0.1:8787/v1/models` |

## 使用示例

### 示例1: 基本验证
```bash
./verify-full-deployment.sh
```

### 示例2: 自定义端口验证
```bash
./verify-full-deployment.sh --port 8888
```

### 示例3: 干运行模式
```bash
./verify-full-deployment.sh --dry-run
```

### 示例4: 安静模式
```bash
./verify-full-deployment.sh --quiet
```

### 示例5: 详细模式
```bash
./verify-full-deployment.sh --verbose
```

### 示例6: 自定义端点
```bash
./verify-full-deployment.sh \
  --port 9090 \
  --health-endpoint "http://localhost:9090/health" \
  --status-endpoint "http://localhost:9090/api/status" \
  --models-endpoint "http://localhost:9090/api/v1/models"
```

## CI/CD集成

### GitHub Actions 示例

```yaml
name: Verify Deployment
on: [push, pull_request]

jobs:
  verify-deployment:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Docker
        run: |
          sudo apt-get update
          sudo apt-get install -y docker.io docker-compose jq
          sudo systemctl start docker
          
      - name: Deploy quota-proxy
        run: |
          cd quota-proxy
          docker-compose up -d
          sleep 10
          
      - name: Run deployment verification
        run: |
          cd quota-proxy
          chmod +x verify-full-deployment.sh
          ./verify-full-deployment.sh --quiet
```

### Jenkins Pipeline 示例

```groovy
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Deploy') {
            steps {
                sh '''
                    cd quota-proxy
                    docker-compose up -d
                    sleep 10
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh '''
                    cd quota-proxy
                    chmod +x verify-full-deployment.sh
                    ./verify-full-deployment.sh --quiet
                '''
            }
        }
    }
    
    post {
        always {
            sh '''
                cd quota-proxy
                docker-compose down
            '''
        }
    }
}
```

## 故障排除

### 常见问题

#### 1. 命令未找到错误
**错误信息**: `[ERROR] 命令 'xxx' 未找到，请安装后重试`

**解决方案**:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl docker.io docker-compose jq

# CentOS/RHEL
sudo yum install -y curl docker docker-compose jq

# macOS
brew install curl docker docker-compose jq
```

#### 2. Docker守护进程未运行
**错误信息**: `[ERROR] Docker守护进程未运行`

**解决方案**:
```bash
# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证Docker状态
sudo systemctl status docker
```

#### 3. 端口未被占用
**警告信息**: `[WARNING] 端口 XXXX 未被占用`

**解决方案**:
- 确保quota-proxy服务正在运行
- 检查服务配置的端口号
- 重启quota-proxy服务

#### 4. HTTP端点不可达
**错误信息**: `[ERROR] 健康检查端点不可达: http://...`

**解决方案**:
- 检查服务是否正在运行
- 验证防火墙设置
- 检查网络连接
- 查看服务日志: `docker logs quota-proxy`

#### 5. JSON端点无效
**错误信息**: `[ERROR] 状态检查JSON端点无效: http://...`

**解决方案**:
- 验证端点URL是否正确
- 检查服务返回的JSON格式
- 查看服务日志获取更多信息

### 调试技巧

1. **启用详细模式**:
   ```bash
   ./verify-full-deployment.sh --verbose
   ```

2. **检查服务日志**:
   ```bash
   docker logs quota-proxy
   ```

3. **手动测试端点**:
   ```bash
   curl -v http://127.0.0.1:8787/healthz
   curl -v http://127.0.0.1:8787/status | jq .
   ```

4. **检查Docker容器**:
   ```bash
   docker ps
   docker inspect quota-proxy
   ```

## 相关文档

- [部署指南](./DEPLOYMENT.md) - quota-proxy部署说明
- [配置验证](./VERIFY_ENV_CONFIG.md) - 环境变量配置验证
- [部署状态检查](./CHECK_DEPLOYMENT_STATUS.md) - 快速部署状态验证
- [部署状态监控](./MONITOR_DEPLOYMENT.md) - 持续部署状态监控
- [SQLite持久化验证](./VERIFY_SQLITE_PERSISTENCE.md) - 数据库功能验证
- [试用密钥流程验证](./VERIFY_TRIAL_KEY_FLOW.md) - 试用密钥功能验证
- [管理API快速示例](./ADMIN_API_QUICK_EXAMPLE.md) - 管理API使用示例

## 版本历史

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持10个验证步骤
- 提供多种运行模式
- 支持环境变量配置
- 包含完整的文档和示例

## 贡献指南

欢迎提交问题和拉取请求来改进这个验证脚本。

### 开发要求
- 遵循现有的代码风格
- 添加相应的测试用例
- 更新文档和示例
- 确保向后兼容性

### 测试
```bash
# 运行所有测试
./verify-full-deployment.sh --dry-run
./verify-full-deployment.sh --quiet
./verify-full-deployment.sh --verbose

# 测试特定功能
PORT=8888 ./verify-full-deployment.sh
HEALTH_ENDPOINT="http://localhost:8888/health" ./verify-full-deployment.sh
```

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。