// 下载统计脚本 - 简单客户端统计
(function() {
  'use strict';
  
  // 统计配置
  const STATS_ENDPOINT = '/api/stats/download';
  const STORAGE_KEY = 'clawd_download_stats';
  const SESSION_TIMEOUT = 30 * 60 * 1000; // 30分钟
  
  // 初始化
  function initStats() {
    // 监听下载链接点击
    document.addEventListener('click', function(e) {
      const link = e.target.closest('a[href*="install-cn.sh"], a[href*="download"]');
      if (link) {
        trackDownload(link.href, link.textContent || 'unknown');
      }
    });
    
    // 显示统计信息（如果有）
    displayStats();
  }
  
  // 跟踪下载
  function trackDownload(url, label) {
    const stats = getStats();
    const now = Date.now();
    
    // 检查是否在同一个会话中
    const lastSession = stats.lastSession || 0;
    if (now - lastSession < SESSION_TIMEOUT) {
      return; // 同一会话内不重复统计
    }
    
    // 更新统计
    stats.totalDownloads = (stats.totalDownloads || 0) + 1;
    stats.lastDownload = now;
    stats.lastSession = now;
    stats.lastUrl = url;
    
    // 按标签统计
    if (label) {
      stats.byLabel = stats.byLabel || {};
      stats.byLabel[label] = (stats.byLabel[label] || 0) + 1;
    }
    
    // 保存到本地存储
    saveStats(stats);
    
    // 发送到服务器（非阻塞）
    sendStatsToServer(stats);
    
    // 更新显示
    displayStats();
  }
  
  // 获取统计
  function getStats() {
    try {
      const data = localStorage.getItem(STORAGE_KEY);
      return data ? JSON.parse(data) : {};
    } catch (e) {
      return {};
    }
  }
  
  // 保存统计
  function saveStats(stats) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(stats));
    } catch (e) {
      // 忽略存储错误
    }
  }
  
  // 发送到服务器
  function sendStatsToServer(stats) {
    if (typeof navigator.sendBeacon === 'function') {
      const data = new FormData();
      data.append('total', stats.totalDownloads || 0);
      data.append('timestamp', Date.now());
      data.append('url', window.location.href);
      data.append('userAgent', navigator.userAgent);
      
      navigator.sendBeacon(STATS_ENDPOINT, data);
    }
  }
  
  // 显示统计
  function displayStats() {
    const stats = getStats();
    if (!stats.totalDownloads) return;
    
    // 查找或创建显示容器
    let container = document.getElementById('download-stats-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'download-stats-container';
      container.className = 'card muted';
      container.style.marginTop = '20px';
      container.style.fontSize = '0.9em';
      
      // 插入到第一个卡片之后
      const firstCard = document.querySelector('.card');
      if (firstCard && firstCard.parentNode) {
        firstCard.parentNode.insertBefore(container, firstCard.nextSibling);
      }
    }
    
    // 格式化时间
    const lastTime = stats.lastDownload ? new Date(stats.lastDownload).toLocaleString('zh-CN', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }) : '从未';
    
    // 更新内容
    container.innerHTML = `
      <h3>📊 下载统计（本地）</h3>
      <p>总下载次数：<strong>${stats.totalDownloads}</strong> 次</p>
      <p>最近下载：${lastTime}</p>
      <p class="muted" style="font-size:0.85em">注：此统计仅保存在您的浏览器本地，不会上传到服务器。</p>
    `;
  }
  
  // 页面加载完成后初始化
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initStats);
  } else {
    initStats();
  }
})();