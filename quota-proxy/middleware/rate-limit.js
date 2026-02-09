// 简单的内存速率限制中间件
// 防止 Admin API 暴力破解攻击

const rateLimitStore = new Map();

/**
 * 简单的内存速率限制中间件
 * @param {Object} options 配置选项
 * @param {number} options.windowMs 时间窗口（毫秒），默认 15 分钟
 * @param {number} options.maxRequests 最大请求数，默认 100
 * @param {string} options.message 被限制时的错误消息
 * @param {boolean} options.skipSuccessfulRequests 是否跳过成功请求的计数（默认 false）
 * @returns {Function} Express 中间件
 */
function createRateLimit(options = {}) {
    const windowMs = options.windowMs || 15 * 60 * 1000; // 15 分钟
    const maxRequests = options.maxRequests || 100;
    const message = options.message || '请求过于频繁，请稍后再试';
    const skipSuccessfulRequests = options.skipSuccessfulRequests || false;

    return function rateLimit(req, res, next) {
        const clientIp = req.ip || req.connection.remoteAddress;
        const now = Date.now();
        
        // 清理过期记录
        for (const [ip, data] of rateLimitStore.entries()) {
            if (now - data.startTime > windowMs) {
                rateLimitStore.delete(ip);
            }
        }
        
        // 获取或创建客户端记录
        let clientData = rateLimitStore.get(clientIp);
        if (!clientData) {
            clientData = {
                startTime: now,
                count: 0,
                lastReset: now
            };
            rateLimitStore.set(clientIp, clientData);
        }
        
        // 检查是否超过时间窗口
        if (now - clientData.startTime > windowMs) {
            // 重置计数
            clientData.startTime = now;
            clientData.count = 0;
        }
        
        // 检查是否超过限制
        if (clientData.count >= maxRequests) {
            const resetTime = clientData.startTime + windowMs;
            const retryAfter = Math.ceil((resetTime - now) / 1000);
            
            res.setHeader('Retry-After', retryAfter);
            return res.status(429).json({
                error: 'Too Many Requests',
                message: message,
                retryAfter: retryAfter
            });
        }
        
        // 增加计数（如果配置了跳过成功请求，则在响应后计数）
        if (skipSuccessfulRequests) {
            const originalSend = res.send;
            res.send = function(...args) {
                if (res.statusCode < 400) {
                    clientData.count++;
                }
                return originalSend.apply(this, args);
            };
        } else {
            clientData.count++;
        }
        
        // 设置响应头
        res.setHeader('X-RateLimit-Limit', maxRequests);
        res.setHeader('X-RateLimit-Remaining', maxRequests - clientData.count);
        res.setHeader('X-RateLimit-Reset', Math.ceil((clientData.startTime + windowMs) / 1000));
        
        next();
    };
}

// Admin API 专用速率限制（更严格）
const adminRateLimit = createRateLimit({
    windowMs: 15 * 60 * 1000, // 15 分钟
    maxRequests: 30,          // 更严格的限制
    message: 'Admin API 请求过于频繁，请稍后再试',
    skipSuccessfulRequests: false
});

// 公开 API 速率限制（宽松）
const publicRateLimit = createRateLimit({
    windowMs: 15 * 60 * 1000, // 15 分钟
    maxRequests: 100,         // 标准限制
    message: '请求过于频繁，请稍后再试',
    skipSuccessfulRequests: false
});

module.exports = {
    createRateLimit,
    adminRateLimit,
    publicRateLimit,
    rateLimitStore
};
