// ==UserScript==
// @name         Clawd国度品牌定制测试
// @namespace    https://clawdrepublic.cn/
// @version      1.0.0
// @description  为Clawd国度论坛添加品牌定制样式 - 测试版本
// @author       Clawd团队
// @match        https://clawdrepublic.cn/forum/*
// @grant        none
// @run-at       document-start
// @license      MIT
// ==/UserScript==

(function() {
    'use strict';
    
    // 等待页面加载完成
    function waitForPageLoad() {
        return new Promise(resolve => {
            if (document.readyState === 'complete') {
                resolve();
            } else {
                window.addEventListener('load', resolve);
            }
        });
    }
    
    // 添加自定义CSS
    function addBrandStyles() {
        const css = `
/* 
 * Clawd 国度论坛品牌定制CSS - 测试版本
 * 版本: 1.0.0-test
 * 加载方式: 用户脚本注入
 */

/* 颜色变量系统 */
:root {
  /* 主色调 */
  --clawd-color-primary: #4D698E;
  --clawd-color-primary-light: #6C8CB5;
  --clawd-color-primary-dark: #3A5270;
  
  /* 辅助色 */
  --clawd-color-secondary: #6C8CB5;
  --clawd-color-secondary-light: #8CA7D1;
  --clawd-color-secondary-dark: #56729C;
  
  /* 强调色 */
  --clawd-color-accent: #FF6B35;
  --clawd-color-accent-light: #FF8C5C;
  --clawd-color-accent-dark: #E55A2B;
  
  /* 中性色 */
  --clawd-color-text-primary: #1F2937;
  --clawd-color-text-secondary: #6B7280;
  --clawd-color-text-tertiary: #9CA3AF;
  
  --clawd-color-background: #FFFFFF;
  --clawd-color-background-alt: #F9FAFB;
  --clawd-color-background-hover: #F3F4F6;
  
  --clawd-color-border: #E5E7EB;
  --clawd-color-border-light: #F3F4F6;
  --clawd-color-border-dark: #D1D5DB;
  
  /* 功能色 */
  --clawd-color-success: #23A26D;
  --clawd-color-warning: #F59E0B;
  --clawd-color-error: #EF4444;
  --clawd-color-info: #0EA5E9;
  --clawd-color-purple: #8B5CF6;
  
  /* 设计令牌 */
  --clawd-shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  --clawd-shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  --clawd-shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
  
  --clawd-radius-sm: 0.25rem;
  --clawd-radius-md: 0.375rem;
  --clawd-radius-lg: 0.5rem;
  --clawd-radius-xl: 0.75rem;
  --clawd-radius-full: 9999px;
  
  --clawd-transition-fast: 150ms cubic-bezier(0.4, 0, 0.2, 1);
  --clawd-transition-normal: 250ms cubic-bezier(0.4, 0, 0.2, 1);
}

/* 全局链接增强 */
a {
  color: var(--clawd-color-primary);
  transition: color var(--clawd-transition-fast);
}

a:hover {
  color: var(--clawd-color-accent);
  text-decoration: underline;
}

/* 按钮增强 - 使用高特异性选择器 */
body .Button--primary {
  background-color: var(--clawd-color-primary) !important;
  border-color: var(--clawd-color-primary) !important;
  transition: all var(--clawd-transition-normal) !important;
}

body .Button--primary:hover,
body .Button--primary:focus {
  background-color: var(--clawd-color-primary-dark) !important;
  border-color: var(--clawd-color-primary-dark) !important;
  transform: translateY(-1px) !important;
  box-shadow: var(--clawd-shadow-md) !important;
}

/* 强调按钮 */
body .Button--accent {
  background-color: var(--clawd-color-accent) !important;
  border-color: var(--clawd-color-accent) !important;
  color: white !important;
}

body .Button--accent:hover,
body .Button--accent:focus {
  background-color: var(--clawd-color-accent-dark) !important;
  border-color: var(--clawd-color-accent-dark) !important;
}

/* 头部增强 */
body .Header {
  background: linear-gradient(135deg, var(--clawd-color-primary) 0%, var(--clawd-color-primary-dark) 100%) !important;
  box-shadow: var(--clawd-shadow-md) !important;
}

/* 导航链接 */
body .Header-nav .item-link {
  color: rgba(255, 255, 255, 0.9) !important;
  transition: all var(--clawd-transition-fast) !important;
  border-radius: var(--clawd-radius-md) !important;
  padding: 0.5rem 1rem !important;
}

body .Header-nav .item-link:hover {
  color: white !important;
  background-color: rgba(255, 255, 255, 0.1) !important;
  text-decoration: none !important;
}

/* 卡片效果 */
body .DiscussionListItem,
body .Post {
  border: 1px solid var(--clawd-color-border) !important;
  border-radius: var(--clawd-radius-lg) !important;
  transition: all var(--clawd-transition-normal) !important;
  background-color: var(--clawd-color-background) !important;
}

body .DiscussionListItem:hover,
body .Post:hover {
  border-color: var(--clawd-color-primary-light) !important;
  box-shadow: var(--clawd-shadow-md) !important;
  transform: translateY(-2px) !important;
}

/* 标签样式增强 */
body .TagLabel {
  border-radius: var(--clawd-radius-full) !important;
  font-weight: 600 !important;
  transition: all var(--clawd-transition-fast) !important;
}

body .TagLabel:hover {
  transform: translateY(-1px) !important;
  box-shadow: var(--clawd-shadow-sm) !important;
}

/* 特定标签颜色 */
body .TagLabel[data-slug="getting-started"] {
  background-color: var(--clawd-color-success) !important;
  color: white !important;
}

body .TagLabel[data-slug="trial-key"] {
  background-color: var(--clawd-color-purple) !important;
  color: white !important;
}

body .TagLabel[data-slug="help"] {
  background-color: var(--clawd-color-error) !important;
  color: white !important;
}

body .TagLabel[data-slug="clawd-onboarding"] {
  background-color: var(--clawd-color-info) !important;
  color: white !important;
}

/* 表单增强 */
body .FormControl {
  border: 1px solid var(--clawd-color-border) !important;
  border-radius: var(--clawd-radius-md) !important;
  transition: all var(--clawd-transition-fast) !important;
}

body .FormControl:focus {
  border-color: var(--clawd-color-primary) !important;
  box-shadow: 0 0 0 3px rgba(77, 105, 142, 0.1) !important;
  outline: none !important;
}

/* 页脚样式 */
body .App-footer {
  background-color: var(--clawd-color-background-alt) !important;
  border-top: 1px solid var(--clawd-color-border) !important;
  color: var(--clawd-color-text-secondary) !important;
}

/* 响应式设计 */
@media (max-width: 768px) {
  body .Header-nav .item-link {
    padding: 0.5rem !important;
    font-size: 0.9rem !important;
  }
  
  body .DiscussionListItem,
  body .Post {
    margin-left: 0.5rem !important;
    margin-right: 0.5rem !important;
  }
}

/* 品牌标识 */
body .Header-title::before {
  content: "🐾 " !important;
  font-size: 1.2em !important;
}

/* 调试信息 */
.clawd-brand-debug {
  position: fixed;
  bottom: 10px;
  right: 10px;
  background: var(--clawd-color-primary);
  color: white;
  padding: 5px 10px;
  border-radius: var(--clawd-radius-md);
  font-size: 12px;
  z-index: 9999;
  opacity: 0.9;
}
`;
        
        const style = document.createElement('style');
        style.type = 'text/css';
        style.id = 'clawd-brand-styles';
        style.textContent = css;
        document.head.appendChild(style);
        
        // 添加调试信息
        const debugDiv = document.createElement('div');
        debugDiv.className = 'clawd-brand-debug';
        debugDiv.textContent = '🐾 Clawd品牌CSS已加载 v1.0.0';
        document.body.appendChild(debugDiv);
        
        console.log('🎨 Clawd品牌定制CSS已成功加载');
        console.log('📊 加载样式数量: ' + css.split('{').length + ' 个规则');
    }
    
    // 主执行函数
    async function main() {
        try {
            await waitForPageLoad();
            addBrandStyles();
            
            // 监听页面变化（单页应用）
            const observer = new MutationObserver(() => {
                // 确保样式始终存在
                if (!document.getElementById('clawd-brand-styles')) {
                    addBrandStyles();
                }
            });
            
            observer.observe(document.head, { childList: true });
            
        } catch (error) {
            console.error('❌ Clawd品牌CSS加载失败:', error);
        }
    }
    
    // 启动
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', main);
    } else {
        main();
    }
    
})();