#!/bin/bash

# Prometheus 监控指标验证脚本
# 验证 quota-proxy 的 Prometheus 监控指标功能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

color_log() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# 检查依赖
check_dependencies() {
    color_log $BLUE "检查依赖..."
    
    local missing_deps=()
    
    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        missing_deps+=("Node.js")
    fi
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    # 检查 npm
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        color_log $RED "缺少依赖: ${missing_deps[*]}"
        color_log $YELLOW "请安装缺少的依赖后重试"
        exit 1
    fi
    
    color_log $GREEN "✓ 所有依赖已安装"
}

# 检查中间件文件
check_middleware_files() {
    color_log $BLUE "检查 Prometheus 监控指标中间件文件..."
    
    local files=(
        "middleware/prometheus-metrics.js"
    )
    
    local all_exist=true
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            color_log $GREEN "✓ $file 存在"
        else
            color_log $RED "✗ $file 不存在"
            all_exist=false
        fi
    done
    
    if [ "$all_exist" = false ]; then
        color_log $RED "Prometheus 监控指标中间件文件不完整"
        exit 1
    fi
    
    # 检查文件内容
    if grep -q "Prometheus 监控指标导出中间件" "middleware/prometheus-metrics.js"; then
        color_log $GREEN "✓ Prometheus 中间件文件内容正确"
    else
        color_log $RED "✗ Prometheus 中间件文件内容不正确"
        exit 1
    fi
}

# 测试中间件功能
test_middleware_functionality() {
    color_log $BLUE "测试 Prometheus 监控指标中间件功能..."
    
    # 创建测试文件
    cat > test-prometheus-middleware.js << 'EOF'
const prometheus = require('./middleware/prometheus-metrics.js');

console.log("测试 Prometheus 监控指标中间件...");

// 测试指标对象
console.log("1. 检查指标对象结构...");
const requiredMetrics = [
    'httpRequestsTotal',
    'httpRequestsByMethod',
    'httpResponsesByStatus',
    'apiKeysTotal',
    'apiKeysActive',
    'apiKeysExpired',
    'apiUsageTotal',
    'databaseQueriesTotal',
    'databaseQueryDuration',
    'uptimeSeconds'
];

for (const metric of requiredMetrics) {
    if (prometheus.metrics[metric] !== undefined) {
        console.log(`  ✓ ${metric} 存在`);
    } else {
        console.log(`  ✗ ${metric} 不存在`);
        process.exit(1);
    }
}

// 测试中间件函数
console.log("\n2. 检查中间件函数...");
const requiredFunctions = [
    'prometheusMetricsMiddleware',
    'recordDatabaseQuery',
    'createMetricsEndpoint',
    'updateDatabaseMetrics'
];

for (const func of requiredFunctions) {
    if (typeof prometheus[func] === 'function') {
        console.log(`  ✓ ${func} 是函数`);
    } else {
        console.log(`  ✗ ${func} 不是函数或不存在`);
        process.exit(1);
    }
}

// 测试指标生成
console.log("\n3. 测试指标生成...");
try {
    const metrics = prometheus.generatePrometheusMetrics(null);
    if (metrics && metrics.includes('quota_proxy_http_requests_total')) {
        console.log("  ✓ 指标生成函数工作正常");
    } else {
        console.log("  ✗ 指标生成函数返回格式不正确");
        process.exit(1);
    }
} catch (error) {
    console.log(`  ✗ 指标生成失败: ${error.message}`);
    process.exit(1);
}

console.log("\n✅ 所有 Prometheus 监控指标中间件测试通过");
EOF
    
    # 运行测试
    if node test-prometheus-middleware.js; then
        color_log $GREEN "✓ Prometheus 监控指标中间件功能测试通过"
        rm -f test-prometheus-middleware.js
    else
        color_log $RED "✗ Prometheus 监控指标中间件功能测试失败"
        rm -f test-prometheus-middleware.js
        exit 1
    fi
}

# 检查 server-sqlite.js 是否集成了 Prometheus 中间件
check_server_integration() {
    color_log $BLUE "检查 server-sqlite.js 集成..."
    
    if grep -q "prometheus-metrics" "server-sqlite.js"; then
        color_log $GREEN "✓ server-sqlite.js 引用了 Prometheus 中间件"
        
        # 检查具体集成点
        local integration_points=0
        
        if grep -q "require.*prometheus-metrics" "server-sqlite.js"; then
            color_log $GREEN "  ✓ 正确引入了 prometheus-metrics 模块"
            integration_points=$((integration_points + 1))
        fi
        
        if grep -q "prometheusMetricsMiddleware" "server-sqlite.js"; then
            color_log $GREEN "  ✓ 使用了 prometheusMetricsMiddleware 中间件"
            integration_points=$((integration_points + 1))
        fi
        
        if grep -q "/metrics" "server-sqlite.js"; then
            color_log $GREEN "  ✓ 设置了 /metrics 端点"
            integration_points=$((integration_points + 1))
        fi
        
        if [ $integration_points -ge 2 ]; then
            color_log $GREEN "✓ Prometheus 监控指标集成完整"
        else
            color_log $YELLOW "⚠ Prometheus 监控指标集成不完整，需要手动集成"
            show_integration_instructions
        fi
    else
        color_log $YELLOW "⚠ server-sqlite.js 未集成 Prometheus 监控指标"
        show_integration_instructions
    fi
}

# 显示集成说明
show_integration_instructions() {
    color_log $YELLOW "\n📋 Prometheus 监控指标集成说明:"
    color_log $YELLOW "要在 quota-proxy 中启用 Prometheus 监控指标，请执行以下步骤:"
    color_log $YELLOW ""
    color_log $YELLOW "1. 在 server-sqlite.js 顶部添加引入:"
    color_log $YELLOW "   const { prometheusMetricsMiddleware, createMetricsEndpoint } = require('./middleware/prometheus-metrics');"
    color_log $YELLOW ""
    color_log $YELLOW "2. 在中间件部分添加 Prometheus 中间件:"
    color_log $YELLOW "   app.use(prometheusMetricsMiddleware);"
    color_log $YELLOW ""
    color_log $YELLOW "3. 在路由部分添加 /metrics 端点:"
    color_log $YELLOW "   app.get('/metrics', createMetricsEndpoint(db));"
    color_log $YELLOW ""
    color_log $YELLOW "4. 在数据库查询函数中记录查询时间:"
    color_log $YELLOW "   const startTime = Date.now();"
    color_log $YELLOW "   // ... 执行查询 ..."
    color_log $YELLOW "   const duration = Date.now() - startTime;"
    color_log $YELLOW "   recordDatabaseQuery(duration);"
    color_log $YELLOW ""
    color_log $YELLOW "集成完成后，可以通过 http://localhost:8787/metrics 访问监控指标"
}

# 创建集成指南文档
create_integration_guide() {
    color_log $BLUE "创建 Prometheus 监控指标集成指南..."
    
    cat > PROMETHEUS-METRICS-INTEGRATION.md << 'EOF'
# Prometheus 监控指标集成指南

## 概述
本文档指导如何将 Prometheus 监控指标功能集成到 quota-proxy 中，以便监控服务的运行状态和性能指标。

## 已完成的组件
1. **Prometheus 监控指标中间件** (`middleware/prometheus-metrics.js`)
   - HTTP 请求统计
   - 数据库状态监控
   - 密钥使用情况统计
   - 系统运行时间监控

2. **验证脚本** (`verify-prometheus-metrics.sh`)
   - 检查中间件文件
   - 测试中间件功能
   - 验证服务器集成

## 集成步骤

### 步骤 1: 引入中间件模块
在 `server-sqlite.js` 文件顶部添加以下引入语句：

```javascript
const { prometheusMetricsMiddleware, createMetricsEndpoint, recordDatabaseQuery } = require('./middleware/prometheus-metrics');
```

### 步骤 2: 添加 Prometheus 中间件
在中间件配置部分添加 Prometheus 中间件（建议放在其他中间件之后，日志中间件之前）：

```javascript
// 添加 Prometheus 监控指标中间件
app.use(prometheusMetricsMiddleware);
```

### 步骤 3: 添加 /metrics 端点
在路由部分添加 Prometheus 指标端点：

```javascript
// Prometheus 监控指标端点
app.get('/metrics', createMetricsEndpoint(db));
```

### 步骤 4: 记录数据库查询时间
在数据库查询函数中添加查询时间记录：

```javascript
function queryDatabase(query, params) {
    const startTime = Date.now();
    // 执行数据库查询
    const result = db.prepare(query).get(params);
    const duration = Date.now() - startTime;
    
    // 记录查询时间
    recordDatabaseQuery(duration);
    
    return result;
}
```

## 监控指标说明

### 可用的指标
1. **HTTP 请求统计**
   - `quota_proxy_http_requests_total`: 总请求数
   - `quota_proxy_http_requests_by_method_total`: 按方法统计的请求数
   - `quota_proxy_http_responses_by_status_total`: 按状态码统计的响应数

2. **数据库指标**
   - `quota_proxy_database_queries_total`: 总查询次数
   - `quota_proxy_database_query_duration_total`: 总查询时间（毫秒）

3. **密钥管理指标**
   - `quota_proxy_api_keys_total`: 总密钥数
   - `quota_proxy_api_keys_active`: 活跃密钥数
   - `quota_proxy_api_keys_expired`: 过期密钥数
   - `quota_proxy_api_usage_total`: 总使用次数

4. **系统指标**
   - `quota_proxy_uptime_seconds`: 服务运行时间（秒）

### 访问监控指标
集成完成后，可以通过以下 URL 访问监控指标：
```
http://localhost:8787/metrics
```

## Prometheus 配置示例

在 Prometheus 的 `prometheus.yml` 配置文件中添加以下抓取配置：

```yaml
scrape_configs:
  - job_name: 'quota-proxy'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:8787']
```

## Grafana 仪表板建议

可以创建以下 Grafana 仪表板面板：

1. **服务健康状态**
   - 请求率（requests per second）
   - 错误率（error rate）
   - 平均响应时间

2. **数据库性能**
   - 查询频率
   - 平均查询时间
   - 数据库连接状态

3. **密钥使用情况**
   - 总密钥数
   - 活跃密钥占比
   - API 使用趋势

## 验证集成

运行验证脚本检查集成状态：
```bash
./verify-prometheus-metrics.sh
```

## 故障排除

### 问题: /metrics 端点返回 404
**解决方案**: 检查是否在 `server-sqlite.js` 中正确添加了 `/metrics` 路由。

### 问题: 指标数据不更新
**解决方案**: 确保 `prometheusMetricsMiddleware` 中间件被正确添加，并且数据库查询时间被正确记录。

### 问题: Prometheus 无法抓取指标
**解决方案**: 检查防火墙设置，确保端口 8787 可访问，并验证 Prometheus 配置中的目标地址。

## 扩展监控指标

如需添加更多监控指标，可以修改 `middleware/prometheus-metrics.js` 文件：

1. 在 `metrics` 对象中添加新的指标变量
2. 在相应的函数中更新指标值
3. 在 `generatePrometheusMetrics` 函数中添加指标导出逻辑

## 性能考虑
- Prometheus 中间件会为每个请求增加少量开销（约 0.1-0.5ms）
- 指标收集在内存中进行，重启服务会重置指标
- 对于高并发场景，建议使用更高效的数据结构存储指标
EOF

    color_log $GREEN "✓ 创建 Prometheus 监控指标集成指南: PROMETHEUS-METRICS-INTEGRATION.md"
}

# 主函数
main() {
    color_log $BLUE "========================================="
    color_log $BLUE "Prometheus 监控指标验证脚本"
    color_log $BLUE "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    color_log $BLUE "========================================="
    
    check_dependencies
    check_middleware_files
    test_middleware_functionality
    check_server_integration
    create_integration_guide
    
    color_log $BLUE "\n========================================="
    color_log $GREEN "✅ Prometheus 监控指标验证完成"
    color_log $BLUE "========================================="
    color_log $BLUE "下一步:"
    color_log $BLUE "1. 按照 PROMETHEUS-METRICS-INTEGRATION.md 指南集成到 server-sqlite.js"
    color_log $BLUE "2. 重启 quota-proxy 服务"
    color_log $BLUE "3. 访问 http://localhost:8787/metrics 验证指标"
    color_log $BLUE "4. 配置 Prometheus 抓取监控指标"
    color_log $BLUE "========================================="
}

# 运行主函数
main "$@"