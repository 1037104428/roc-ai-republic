# install-cn.sh 快速验证

本文档提供 `install-cn.sh` 安装脚本的快速验证方法，帮助你在部署前确认脚本功能正常。

## 1. 语法检查

```bash
# 检查脚本语法
bash -n scripts/install-cn.sh
```

## 2. 帮助信息检查

```bash
# 查看帮助信息
./scripts/install-cn.sh --help
```

## 3. 干运行测试

```bash
# 测试最新版本安装（不实际执行）
./scripts/install-cn.sh --dry-run --version latest

# 测试特定版本安装
./scripts/install-cn.sh --dry-run --version 0.3.12

# 测试强制使用国内源
./scripts/install-cn.sh --dry-run --force-cn
```

## 4. 网络连通性测试

```bash
# 测试网络连通性（可选）
./scripts/install-cn.sh --dry-run --network-test
```

## 5. 在线脚本验证

```bash
# 验证官网在线脚本（不执行）
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --dry-run --help
```

## 6. 完整验证脚本

使用仓库自带的验证脚本：

```bash
./scripts/verify-install-cn.sh --dry-run
```

## 验证结果说明

- ✅ 语法检查通过：脚本无语法错误
- ✅ 帮助信息正常：参数说明清晰
- ✅ 干运行成功：安装命令逻辑正确
- ✅ 网络测试通过：源站可达

## 故障排查

如果验证失败：

1. **脚本权限问题**：
   ```bash
   chmod +x scripts/install-cn.sh
   ```

2. **依赖缺失**：
   - 确保已安装 `bash`、`curl`、`npm`、`node`

3. **网络问题**：
   ```bash
   # 测试国内源连通性
   curl -fsS https://registry.npmmirror.com/openclaw
   
   # 测试官方源连通性  
   curl -fsS https://registry.npmjs.org/openclaw
   ```

## 相关链接

- [安装脚本源码](scripts/install-cn.sh)
- [完整安装指南](docs/README.md#安装)
- [官网安装页面](https://clawdrepublic.cn/install-cn.html)
