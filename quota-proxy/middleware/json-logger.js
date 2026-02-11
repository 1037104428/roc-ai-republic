/**
 * JSON 结构化日志中间件
 * 为 quota-proxy 提供结构化 JSON 日志输出
 */

/**
 * JSON 日志中间件
 * 将控制台日志转换为结构化 JSON 格式
 */
function jsonLogger(req, res, next) {
    const startTime = Date.now();
    
    // 重写 console.log 和 console.error 为 JSON 格式
    const originalLog = console.log;
    const originalError = console.error;
    
    console.log = function(...args) {
        const logEntry = {
            timestamp: new Date().toISOString(),
            level: 'INFO',
            message: args.map(arg => 
                typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
            ).join(' '),
            pid: process.pid,
            service: 'quota-proxy'
        };
        originalLog(JSON.stringify(logEntry));
    };
    
    console.error = function(...args) {
        const logEntry = {
            timestamp: new Date().toISOString(),
            level: 'ERROR',
            message: args.map(arg => 
                typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
            ).join(' '),
            pid: process.pid,
            service: 'quota-proxy'
        };
        originalError(JSON.stringify(logEntry));
    };
    
    // 恢复原始控制台方法
    res.on('finish', () => {
        console.log = originalLog;
        console.error = originalError;
        
        // 记录请求日志
        const duration = Date.now() - startTime;
        const logEntry = {
            timestamp: new Date().toISOString(),
            level: 'INFO',
            message: 'HTTP Request',
            method: req.method,
            url: req.url,
            statusCode: res.statusCode,
            duration: `${duration}ms`,
            userAgent: req.get('User-Agent') || 'unknown',
            ip: req.ip || req.connection.remoteAddress,
            pid: process.pid,
            service: 'quota-proxy'
        };
        originalLog(JSON.stringify(logEntry));
    });
    
    next();
}

/**
 * 创建 JSON 日志记录器
 * @param {Object} options 配置选项
 * @returns {Function} JSON 日志中间件
 */
function createJsonLogger(options = {}) {
    const defaultOptions = {
        serviceName: 'quota-proxy',
        includeRequestId: true,
        logLevel: 'info'
    };
    
    const config = { ...defaultOptions, ...options };
    
    return function(req, res, next) {
        const startTime = Date.now();
        const requestId = config.includeRequestId ? 
            `req-${Date.now()}-${Math.random().toString(36).substr(2, 9)}` : null;
        
        // 重写控制台方法
        const originalLog = console.log;
        const originalError = console.error;
        const originalWarn = console.warn;
        const originalInfo = console.info;
        
        // 创建日志函数
        const createLogFunction = (level, originalFn) => {
            return function(...args) {
                const logEntry = {
                    timestamp: new Date().toISOString(),
                    level: level.toUpperCase(),
                    message: args.map(arg => 
                        typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
                    ).join(' '),
                    pid: process.pid,
                    service: config.serviceName,
                    ...(requestId && { requestId })
                };
                originalFn(JSON.stringify(logEntry));
            };
        };
        
        console.log = createLogFunction('info', originalLog);
        console.error = createLogFunction('error', originalError);
        console.warn = createLogFunction('warn', originalWarn);
        console.info = createLogFunction('info', originalInfo);
        
        // 恢复原始控制台方法
        const cleanup = () => {
            console.log = originalLog;
            console.error = originalError;
            console.warn = originalWarn;
            console.info = originalInfo;
        };
        
        res.on('finish', () => {
            const duration = Date.now() - startTime;
            const logEntry = {
                timestamp: new Date().toISOString(),
                level: 'INFO',
                message: 'HTTP Request Completed',
                method: req.method,
                url: req.url,
                statusCode: res.statusCode,
                duration: `${duration}ms`,
                userAgent: req.get('User-Agent') || 'unknown',
                ip: req.ip || req.connection.remoteAddress,
                pid: process.pid,
                service: config.serviceName,
                ...(requestId && { requestId })
            };
            originalLog(JSON.stringify(logEntry));
            cleanup();
        });
        
        res.on('close', cleanup);
        
        next();
    };
}

module.exports = {
    jsonLogger,
    createJsonLogger
};