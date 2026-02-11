# 5分钟体验OpenClaw - 极小白入门教程

## 🎯 目标
5分钟内，让你体验OpenClaw的基本功能，无需复杂配置。

## 📦 准备工作
1. **安装Node.js**（如果还没有）：
   ```bash
   # 检查是否已安装
   node --version
   # 如果未安装，访问 https://nodejs.org/ 下载LTS版本
   ```

2. **安装OpenClaw**：
   ```bash
   npm install -g openclaw
   ```

## 🚀 5分钟体验步骤

### 第1分钟：启动OpenClaw
```bash
# 启动OpenClaw网关
openclaw gateway start

# 检查状态
openclaw gateway status
```

### 第2分钟：连接WhatsApp（可选但推荐）
1. 打开手机WhatsApp
2. 扫描二维码（运行以下命令获取）：
   ```bash
   openclaw whatsapp qr
   ```
3. 连接成功后，就可以在WhatsApp里和OpenClaw聊天了！

### 第3分钟：体验基础功能
在WhatsApp或终端里试试这些命令：

**1. 文件操作**
```
帮我创建一个测试文件 test.txt，内容写"Hello OpenClaw"
```

**2. 系统信息**
```
查看当前系统状态
```

**3. 天气查询**
```
上海现在的天气怎么样？
```

### 第4分钟：安装一个实用技能
```bash
# 安装天气技能
clawhub install weather

# 安装完成后，试试：
# "北京明天的天气"
```

### 第5分钟：探索更多
**已解锁的功能：**
- ✅ 文件管理（创建、读取、编辑）
- ✅ 系统监控
- ✅ 天气查询
- ✅ WhatsApp聊天
- ✅ 技能扩展

**接下来可以尝试：**
- 安装更多技能：`clawhub search`
- 配置定时任务：`cron add`
- 连接更多消息平台（Telegram、Discord等）

## 🆘 常见问题

**Q: 启动时遇到权限问题？**
```bash
# 尝试用sudo
sudo openclaw gateway start
```

**Q: WhatsApp二维码不显示？**
```bash
# 检查服务状态
openclaw gateway status
# 如果服务未运行，重启
openclaw gateway restart
```

**Q: 想卸载重装？**
```bash
# 停止服务
openclaw gateway stop
# 卸载
npm uninstall -g openclaw
# 重新安装
npm install -g openclaw
```

## 📚 下一步学习
1. **官方文档**：`https://docs.openclaw.ai`
2. **技能市场**：`https://clawhub.com`
3. **社区交流**：Discord `https://discord.com/invite/clawd`

## 🎉 恭喜！
你已经完成了OpenClaw的5分钟体验！现在你可以：
- 继续探索更多功能
- 加入社区交流
- 创建自己的技能
- 参与开源贡献

有任何问题，欢迎在社区提问！