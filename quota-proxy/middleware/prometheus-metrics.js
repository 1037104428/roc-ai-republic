/**
 * Prometheus 监控指标导出中间件
 * 
 * 为 quota-proxy 提供 Prometheus 格式的监控指标导出功能
 * 支持 HTTP 请求统计、数据库状态、密钥使用情况等核心指标
 * 
 * 使用方式：
 * 1. 在 server-sqlite.js 中引入此中间件
 * 2. 添加 /metrics 端点用于 Prometheus 抓取
 * 3. 配置 Prometheus 抓取目标为 http://localhost:8787/metrics
 */

const metrics = {
  // HTTP 请求计数器
  httpRequestsTotal: 0,
  httpRequestsByMethod: {
    GET: 0,
    POST: 0,
    PUT: 0,
    DELETE: 0,
    OPTIONS: 0
  },
  httpRequestsByEndpoint: {},
  
  // 响应状态码计数器
  httpResponsesByStatus: {},
  
  // 数据库指标
  databaseQueriesTotal: 0,
  databaseQueryDuration: 0,
  databaseConnectionsActive: 0,
  databaseConnectionsTotal: 0,
  
  // 密钥使用指标
  apiKeysTotal: 0,
  apiKeysActive: 0,
  apiKeysExpired: 0,
  apiUsageTotal: 0,
  apiUsageByKey: {},
  
  // 系统指标
  uptimeSeconds: 0,
  memoryUsageBytes: 0,
  cpuUsagePercent: 0,
  
  // 初始化时间
  startTime: Date.now()
};

/**
 * Prometheus 指标中间件
 * 收集 HTTP 请求指标并暴露 /metrics 端点
 */
function prometheusMetricsMiddleware(req, res, next) {
  const startTime = Date.now();
  const originalEnd = res.end;
  
  // 记录请求开始
  const method = req.method;
  const endpoint = req.url.split('?')[0];
  
  // 更新请求计数器
  metrics.httpRequestsTotal++;
  metrics.httpRequestsByMethod[method] = (metrics.httpRequestsByMethod[method] || 0) + 1;
  metrics.httpRequestsByEndpoint[endpoint] = (metrics.httpRequestsByEndpoint[endpoint] || 0) + 1;
  
  // 拦截响应结束以记录状态码
  res.end = function(...args) {
    const statusCode = res.statusCode;
    metrics.httpResponsesByStatus[statusCode] = (metrics.httpResponsesByStatus[statusCode] || 0) + 1;
    
    // 记录响应时间
    const duration = Date.now() - startTime;
    
    // 调用原始 end 方法
    return originalEnd.apply(this, args);
  };
  
  next();
}

/**
 * 更新数据库指标
 */
function updateDatabaseMetrics(db) {
  if (!db) return;
  
  try {
    // 获取数据库统计信息
    const stats = db.prepare('SELECT COUNT(*) as total_keys FROM api_keys').get();
    metrics.apiKeysTotal = stats.total_keys || 0;
    
    const activeStats = db.prepare('SELECT COUNT(*) as active_keys FROM api_keys WHERE expires_at > ? OR expires_at IS NULL').get(Date.now());
    metrics.apiKeysActive = activeStats.active_keys || 0;
    
    const expiredStats = db.prepare('SELECT COUNT(*) as expired_keys FROM api_keys WHERE expires_at <= ? AND expires_at IS NOT NULL').get(Date.now());
    metrics.apiKeysExpired = expiredStats.expired_keys || 0;
    
    const usageStats = db.prepare('SELECT SUM(usage_count) as total_usage FROM api_keys').get();
    metrics.apiUsageTotal = usageStats.total_usage || 0;
    
    // 更新数据库连接指标（简化版本）
    metrics.databaseConnectionsActive = 1; // SQLite 是文件连接
    metrics.databaseConnectionsTotal = metrics.databaseQueriesTotal;
    
  } catch (error) {
    console.error('更新数据库指标失败:', error.message);
  }
}

/**
 * 记录数据库查询
 */
function recordDatabaseQuery(durationMs) {
  metrics.databaseQueriesTotal++;
  metrics.databaseQueryDuration += durationMs;
}

/**
 * 生成 Prometheus 格式的指标
 */
function generatePrometheusMetrics(db) {
  // 更新实时指标
  metrics.uptimeSeconds = Math.floor((Date.now() - metrics.startTime) / 1000);
  updateDatabaseMetrics(db);
  
  const lines = [];
  
  // HELP 和 TYPE 注释
  lines.push('# HELP quota_proxy_http_requests_total Total HTTP requests processed');
  lines.push('# TYPE quota_proxy_http_requests_total counter');
  lines.push(`quota_proxy_http_requests_total ${metrics.httpRequestsTotal}`);
  
  lines.push('# HELP quota_proxy_http_requests_by_method_total HTTP requests by method');
  lines.push('# TYPE quota_proxy_http_requests_by_method_total counter');
  for (const [method, count] of Object.entries(metrics.httpRequestsByMethod)) {
    lines.push(`quota_proxy_http_requests_by_method_total{method="${method}"} ${count}`);
  }
  
  lines.push('# HELP quota_proxy_http_responses_by_status_total HTTP responses by status code');
  lines.push('# TYPE quota_proxy_http_responses_by_status_total counter');
  for (const [status, count] of Object.entries(metrics.httpResponsesByStatus)) {
    lines.push(`quota_proxy_http_responses_by_status_total{status="${status}"} ${count}`);
  }
  
  lines.push('# HELP quota_proxy_api_keys_total Total number of API keys');
  lines.push('# TYPE quota_proxy_api_keys_total gauge');
  lines.push(`quota_proxy_api_keys_total ${metrics.apiKeysTotal}`);
  
  lines.push('# HELP quota_proxy_api_keys_active Active API keys count');
  lines.push('# TYPE quota_proxy_api_keys_active gauge');
  lines.push(`quota_proxy_api_keys_active ${metrics.apiKeysActive}`);
  
  lines.push('# HELP quota_proxy_api_keys_expired Expired API keys count');
  lines.push('# TYPE quota_proxy_api_keys_expired gauge');
  lines.push(`quota_proxy_api_keys_expired ${metrics.apiKeysExpired}`);
  
  lines.push('# HELP quota_proxy_api_usage_total Total API usage count');
  lines.push('# TYPE quota_proxy_api_usage_total counter');
  lines.push(`quota_proxy_api_usage_total ${metrics.apiUsageTotal}`);
  
  lines.push('# HELP quota_proxy_database_queries_total Total database queries');
  lines.push('# TYPE quota_proxy_database_queries_total counter');
  lines.push(`quota_proxy_database_queries_total ${metrics.databaseQueriesTotal}`);
  
  lines.push('# HELP quota_proxy_database_query_duration_total Total database query duration in milliseconds');
  lines.push('# TYPE quota_proxy_database_query_duration_total counter');
  lines.push(`quota_proxy_database_query_duration_total ${metrics.databaseQueryDuration}`);
  
  lines.push('# HELP quota_proxy_uptime_seconds Service uptime in seconds');
  lines.push('# TYPE quota_proxy_uptime_seconds gauge');
  lines.push(`quota_proxy_uptime_seconds ${metrics.uptimeSeconds}`);
  
  // 添加时间戳
  lines.push(`# Scrape timestamp: ${new Date().toISOString()}`);
  
  return lines.join('\n');
}

/**
 * 创建 /metrics 端点处理器
 */
function createMetricsEndpoint(db) {
  return function(req, res) {
    try {
      const metricsData = generatePrometheusMetrics(db);
      
      res.setHeader('Content-Type', 'text/plain; version=0.0.4');
      res.status(200).send(metricsData);
    } catch (error) {
      console.error('生成监控指标失败:', error);
      res.status(500).json({ error: '生成监控指标失败', details: error.message });
    }
  };
}

module.exports = {
  prometheusMetricsMiddleware,
  recordDatabaseQuery,
  createMetricsEndpoint,
  updateDatabaseMetrics,
  metrics
};