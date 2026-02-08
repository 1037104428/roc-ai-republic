# OpenClaw 小白中文包（免翻墙版）

目标：让国内用户 **不翻墙** 就能下载、安装、跑起来 OpenClaw，并且默认使用 **DeepSeek（带限额试用）**。

这不是“替代 OpenClaw 官方”，而是一套 **国内可达的分发/镜像/默认配置** + （可选）**限额 API 网关**。

## 你能得到什么（v0）
- 一键安装脚本（优先走 npm + 国内源/镜像；失败有降级路径）
- 默认 LLM：DeepSeek（OpenAI-compatible provider）
- 可选：限额试用网关（你拿到一个 trial key；网关后端用赞助者的 DeepSeek key，按人/按天限额）

## 重要边界
- 不做翻墙、入口交换、隐蔽通信、反检测/风控规避。
- 只做“正向可达”：国内网络可直接访问的镜像/源。

## 快速开始（开发中）
- 安装：`bash scripts/install-cn.sh`
  - 环境变量：
    - `NPM_REGISTRY`：优先使用的 npm 源（默认 `https://registry.npmmirror.com`）
    - `NPM_REGISTRY_FALLBACK`：回退 npm 源（默认 `https://registry.npmjs.org`）
  - 自检：脚本会执行 `openclaw --version`；你也可以手动跑：`openclaw status && openclaw models status`

更多见：
- `scripts/install-cn.sh`
- `docs/openclaw-cn-pack-deepseek-v0.md`
- `quota-proxy/`（限额网关）
