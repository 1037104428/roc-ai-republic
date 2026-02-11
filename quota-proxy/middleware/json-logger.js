// JSON格式日志中间件
// 提供结构化JSON日志输出和日志级别控制

/**
 * JSON格式日志中间件
 * @param {Object} options - 配置选项
 * @param {string} options.logLevel - 日志级别: debug, info, warn, error
 * @param {boolean} options.jsonFormat - 是否使用JSON格式输出
 * @param {string} options.serviceName - 服务名称
 * @returns {Function} Express中间件函数
 */
function createJsonLogger(options = {}) {
  const {
    logLevel = process.env.LOG_LEVEL || 'info',
    jsonFormat = process.env.JSON_LOGS === 'true' || false,
    serviceName = 'quota-proxy'
  } = options;

  // 日志级别映射
  const levelPriority = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3
  };

  const currentLevelPriority = levelPriority[logLevel.toLowerCase()] || levelPriority.info;

  /**
   * 检查是否应该记录该级别的日志
   * @param {string} level - 日志级别
   * @returns {boolean} 是否应该记录
   */
  function shouldLog(level) {
    const levelPrio = levelPriority[level.toLowerCase()];
    return levelPrio !== undefined && levelPrio >= currentLevelPriority;
  }

  /**
   * 创建结构化日志对象
   * @param {string} level - 日志级别
   * @param {string} message - 日志消息
   * @param {Object} meta - 元数据
   * @returns {Object} 结构化日志对象
   */
  function createLogObject(level, message, meta = {}) {
    const timestamp = new Date().toISOString();
    const logId = `log_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    return {
      timestamp,
      level: level.toUpperCase(),
      service: serviceName,
      message,
      logId,
      ...meta
    };
  }

  /**
   * 记录日志
   * @param {string} level - 日志级别
   * @param {string} message - 日志消息
   * @param {Object} meta - 元数据
   */
  function log(level, message, meta = {}) {
    if (!shouldLog(level)) return;

    const logObject = createLogObject(level, message, meta);
    
    if (jsonFormat) {
      console.log(JSON.stringify(logObject));
    } else {
      const { timestamp, level: logLevel, service, message: logMessage, ...rest } = logObject;
      const metaStr = Object.keys(rest).length > 0 ? ` ${JSON.stringify(rest)}` : '';
      console.log(`[${timestamp}] ${logLevel} [${service}] ${logMessage}${metaStr}`);
    }
  }

  // 创建日志方法
  const logger = {
    debug: (message, meta) => log('debug', message, meta),
    info: (message, meta) => log('info', message, meta),
    warn: (message, meta) => log('warn', message, meta),
    error: (message, meta) => log('error', message, meta),
    
    // HTTP请求日志
    http: (req, res, responseTime) => {
      if (!shouldLog('info')) return;
      
      const meta = {
        method: req.method,
        url: req.originalUrl || req.url,
        statusCode: res.statusCode,
        responseTime: `${responseTime}ms`,
        userAgent: req.get('user-agent'),
        ip: req.ip || req.connection.remoteAddress,
        contentLength: res.get('content-length') || 'unknown'
      };
      
      const message = `${req.method} ${req.originalUrl || req.url} ${res.statusCode}`;
      log('info', message, meta);
    },
    
    // 数据库操作日志
    db: (operation, query, duration, success = true) => {
      if (!shouldLog('debug')) return;
      
      const meta = {
        operation,
        query: typeof query === 'string' ? query : JSON.stringify(query),
        duration: `${duration}ms`,
        success
      };
      
      log('debug', `Database ${operation}`, meta);
    },
    
    // API密钥操作日志
    key: (operation, keyId, userId, success = true) => {
      if (!shouldLog('info')) return;
      
      const meta = {
        operation,
        keyId: keyId || 'unknown',
        userId: userId || 'unknown',
        success
      };
      
      log('info', `API Key ${operation}`, meta);
    }
  };

  // Express中间件
  return function jsonLoggerMiddleware(req, res, next) {
    const startTime = Date.now();
    
    // 记录请求开始
    logger.debug('Request started', {
      method: req.method,
      url: req.originalUrl || req.url,
      headers: {
        'user-agent': req.get('user-agent'),
        'content-type': req.get('content-type')
      }
    });
    
    // 拦截响应结束事件
    const originalEnd = res.end;
    res.end = function(chunk, encoding) {
      const responseTime = Date.now() - startTime;
      
      // 记录HTTP请求
      logger.http(req, res, responseTime);
      
      // 调用原始end方法
      originalEnd.call(this, chunk, encoding);
    };
    
    next();
  };
}

// 导出中间件创建函数
module.exports = createJsonLogger;

// 导出日志级别常量
module.exports.LEVELS = {
  DEBUG: 'debug',
  INFO: 'info',
  WARN: 'warn',
  ERROR: 'error'
};

// 导出默认配置
module.exports.defaultConfig = {
  logLevel: 'info',
  jsonFormat: false,
  serviceName: 'quota-proxy'
};

// 使用示例:
/*
// 基本使用
const createJsonLogger = require('./middleware/json-logger');
const jsonLogger = createJsonLogger({
  logLevel: 'debug',
  jsonFormat: true,
  serviceName: 'my-service'
});

app.use(jsonLogger);

// 直接使用日志方法
const logger = createJsonLogger();
logger.info('服务启动成功', { port: 3000 });
logger.error('数据库连接失败', { error: err.message });
logger.db('SELECT', 'SELECT * FROM users', 45, true);
logger.key('CREATE', 'key_123', 'user_456', true);
*/