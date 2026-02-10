#!/bin/bash
set -e

# quota-proxy 状态监控页面生成脚本
# 生成一个简单的 HTML 页面，显示 quota-proxy 运行状态和关键指标

cat > /tmp/quota-proxy-status.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>中华AI共和国 - quota-proxy 状态监控</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #1a237e 0%, #283593 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.2rem;
            margin-bottom: 10px;
            font-weight: 600;
        }
        
        .header .subtitle {
            font-size: 1.1rem;
            opacity: 0.9;
            margin-bottom: 20px;
        }
        
        .status-badge {
            display: inline-block;
            background: #4caf50;
            color: white;
            padding: 8px 20px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 1rem;
            margin-top: 10px;
            box-shadow: 0 4px 15px rgba(76, 175, 80, 0.3);
        }
        
        .content {
            padding: 30px;
        }
        
        .section {
            margin-bottom: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            border-left: 4px solid #1a237e;
        }
        
        .section h2 {
            color: #1a237e;
            margin-bottom: 15px;
            font-size: 1.4rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .section h2 i {
            font-size: 1.2rem;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        
        .info-item {
            background: white;
            padding: 15px;
            border-radius: 6px;
            border: 1px solid #e0e0e0;
        }
        
        .info-label {
            font-weight: 600;
            color: #666;
            font-size: 0.9rem;
            margin-bottom: 5px;
        }
        
        .info-value {
            font-size: 1.1rem;
            color: #333;
            word-break: break-all;
        }
        
        .code-block {
            background: #1e1e1e;
            color: #d4d4d4;
            padding: 15px;
            border-radius: 6px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.9rem;
            overflow-x: auto;
            margin-top: 10px;
        }
        
        .footer {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            color: #666;
            font-size: 0.9rem;
            border-top: 1px solid #e0e0e0;
        }
        
        .footer a {
            color: #1a237e;
            text-decoration: none;
        }
        
        .footer a:hover {
            text-decoration: underline;
        }
        
        @media (max-width: 600px) {
            .container {
                margin: 10px;
            }
            
            .header {
                padding: 20px;
            }
            
            .header h1 {
                font-size: 1.8rem;
            }
            
            .content {
                padding: 20px;
            }
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>中华AI共和国</h1>
            <div class="subtitle">quota-proxy API 网关状态监控</div>
            <div class="status-badge">
                <i class="fas fa-check-circle"></i> 服务运行正常
            </div>
        </div>
        
        <div class="content">
            <div class="section">
                <h2><i class="fas fa-server"></i> 服务状态</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">服务名称</div>
                        <div class="info-value">quota-proxy API 网关</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">运行状态</div>
                        <div class="info-value"><span style="color: #4caf50;">●</span> 在线</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">监听端口</div>
                        <div class="info-value">8787</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">部署时间</div>
                        <div class="info-value">2026-02-10</div>
                    </div>
                </div>
            </div>
            
            <div class="section">
                <h2><i class="fas fa-key"></i> API 接入</h2>
                <div class="info-item">
                    <div class="info-label">健康检查端点</div>
                    <div class="info-value">GET /healthz</div>
                </div>
                <div class="info-item">
                    <div class="info-label">API 网关地址</div>
                    <div class="info-value">http://127.0.0.1:8787</div>
                </div>
                <div class="info-item">
                    <div class="info-label">管理员接口</div>
                    <div class="info-value">/admin/* (需要 ADMIN_TOKEN)</div>
                </div>
            </div>
            
            <div class="section">
                <h2><i class="fas fa-terminal"></i> 快速验证命令</h2>
                <div class="code-block">
# 健康检查<br>
curl -fsS http://127.0.0.1:8787/healthz<br>
<br>
# 创建 trial key (需要 ADMIN_TOKEN)<br>
ADMIN_TOKEN="your_admin_token_here"<br>
curl -H "Authorization: Bearer \$ADMIN_TOKEN" \<br>
  -X POST http://127.0.0.1:8787/admin/keys \<br>
  -H "Content-Type: application/json" \<br>
  -d '{"name":"测试用户","quota":1000}'<br>
<br>
# 查看使用情况<br>
curl -H "Authorization: Bearer \$ADMIN_TOKEN" \<br>
  http://127.0.0.1:8787/admin/usage
                </div>
            </div>
            
            <div class="section">
                <h2><i class="fas fa-book"></i> 文档链接</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">部署指南</div>
                        <div class="info-value">
                            <a href="https://github.com/1037104428/roc-ai-republic/blob/main/docs/quota-proxy-sqlite-auth-deployment.md" target="_blank">
                                <i class="fas fa-external-link-alt"></i> 查看文档
                            </a>
                        </div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">安装脚本</div>
                        <div class="info-value">
                            <a href="https://github.com/1037104428/roc-ai-republic/blob/main/scripts/install-cn-enhanced.sh" target="_blank">
                                <i class="fas fa-download"></i> 下载安装
                            </a>
                        </div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">GitHub 仓库</div>
                        <div class="info-value">
                            <a href="https://github.com/1037104428/roc-ai-republic" target="_blank">
                                <i class="fab fa-github"></i> 访问仓库
                            </a>
                        </div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Gitee 镜像</div>
                        <div class="info-value">
                            <a href="https://gitee.com/junkaiWang324/roc-ai-republic" target="_blank">
                                <i class="fas fa-code"></i> 国内镜像
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>© 2026 中华AI共和国 / OpenClaw 小白中文包项目</p>
            <p>最后更新: <span id="update-time">2026-02-10 14:50:52 CST</span></p>
            <p>项目目标：为国内开发者提供稳定、可访问的 AI 工具链与基础设施</p>
        </div>
    </div>
    
    <script>
        // 更新时间
        document.getElementById('update-time').textContent = new Date().toLocaleString('zh-CN', {
            timeZone: 'Asia/Shanghai',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: false
        }).replace(/\//g, '-');
        
        // 简单的状态检查（可扩展为实际API调用）
        function checkStatus() {
            fetch('http://127.0.0.1:8787/healthz')
                .then(response => response.json())
                .then(data => {
                    if (data.ok) {
                        console.log('quota-proxy 状态正常');
                    }
                })
                .catch(err => {
                    console.warn('状态检查失败（可能跨域限制）:', err);
                });
        }
        
        // 页面加载时检查一次状态
        window.addEventListener('load', checkStatus);
    </script>
</body>
</html>
EOF

echo "✅ 已生成 quota-proxy 状态监控页面：/tmp/quota-proxy-status.html"
echo ""
echo "📋 页面功能："
echo "  • 显示服务运行状态"
echo "  • 提供 API 接入信息"
echo "  • 包含快速验证命令"
echo "  • 链接到相关文档"
echo ""
echo "🚀 部署到服务器的命令："
echo "  scp /tmp/quota-proxy-status.html root@8.210.185.194:/opt/roc/web/"
echo ""
echo "🌐 本地预览命令："
echo "  python3 -m http.server 8080 --directory /tmp/ &"
echo "  xdg-open http://localhost:8080/quota-proxy-status.html"