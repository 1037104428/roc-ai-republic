// IP 白名单中间件
// 用于保护 Admin API，只允许特定 IP 访问

/**
 * IP 白名单中间件
 * @param {Array<string>} allowedIps 允许的 IP 地址数组（支持 CIDR 表示法）
 * @param {Object} options 配置选项
 * @param {boolean} options.enabled 是否启用白名单（默认 true）
 * @param {string} options.message 被拒绝时的错误消息
 * @param {boolean} options.allowLocalhost 是否允许 localhost/127.0.0.1（默认 true）
 * @returns {Function} Express 中间件
 */
function createIpWhitelist(allowedIps = [], options = {}) {
    const enabled = options.enabled !== false;
    const message = options.message || 'IP 地址不在白名单中，访问被拒绝';
    const allowLocalhost = options.allowLocalhost !== false;
    
    // 默认白名单（如果启用 localhost）
    const defaultIps = allowLocalhost ? ['127.0.0.1', '::1', 'localhost'] : [];
    const allAllowedIps = [...defaultIps, ...allowedIps];
    
    // CIDR 匹配函数
    function isIpInCidr(ip, cidr) {
        if (!cidr.includes('/')) {
            return ip === cidr;
        }
        
        try {
            const [cidrIp, maskBits] = cidr.split('/');
            const mask = parseInt(maskBits, 10);
            
            // 将 IP 地址转换为数字
            function ipToInt(ip) {
                const parts = ip.split('.');
                return (parseInt(parts[0]) << 24) + 
                       (parseInt(parts[1]) << 16) + 
                       (parseInt(parts[2]) << 8) + 
                       parseInt(parts[3]);
            }
            
            // 检查是否是 IPv4
            if (ip.includes(':') || cidrIp.includes(':')) {
                // 简化处理：只支持精确匹配 IPv6
                return ip === cidrIp;
            }
            
            const ipInt = ipToInt(ip);
            const cidrInt = ipToInt(cidrIp);
            const maskInt = ~((1 << (32 - mask)) - 1);
            
            return (ipInt & maskInt) === (cidrInt & maskInt);
        } catch (error) {
            console.error('CIDR 匹配错误:', error);
            return false;
        }
    }
    
    return function ipWhitelist(req, res, next) {
        // 如果不启用，直接通过
        if (!enabled) {
            return next();
        }
        
        const clientIp = req.ip || req.connection.remoteAddress;
        
        // 清理 IP 地址（移除 IPv6 前缀和端口）
        let cleanIp = clientIp;
        if (cleanIp.startsWith('::ffff:')) {
            cleanIp = cleanIp.substring(7); // 移除 IPv6 映射的 IPv4 前缀
        }
        if (cleanIp.includes(':')) {
            cleanIp = cleanIp.split(':')[0]; // 移除端口号
        }
        
        // 检查是否在白名单中
        const isAllowed = allAllowedIps.some(allowedIp => {
            if (allowedIp.includes('/')) {
                return isIpInCidr(cleanIp, allowedIp);
            }
            return cleanIp === allowedIp;
        });
        
        if (isAllowed) {
            // 记录访问日志（可选）
            console.log(`[IP Whitelist] 允许访问: ${cleanIp} -> ${req.method} ${req.path}`);
            return next();
        } else {
            console.warn(`[IP Whitelist] 拒绝访问: ${cleanIp} -> ${req.method} ${req.path}`);
            return res.status(403).json({
                error: 'Forbidden',
                message: message,
                clientIp: cleanIp,
                timestamp: new Date().toISOString()
            });
        }
    };
}

// Admin API 专用白名单（从环境变量读取）
function createAdminIpWhitelist() {
    // 从环境变量读取白名单 IP，支持逗号分隔
    const envIps = process.env.ADMIN_IP_WHITELIST || '';
    const allowedIps = envIps.split(',').filter(ip => ip.trim()).map(ip => ip.trim());
    
    return createIpWhitelist(allowedIps, {
        enabled: allowedIps.length > 0, // 如果设置了白名单则启用
        message: 'Admin API 仅允许特定 IP 访问',
        allowLocalhost: true // 默认允许 localhost
    });
}

module.exports = {
    createIpWhitelist,
    createAdminIpWhitelist
};
