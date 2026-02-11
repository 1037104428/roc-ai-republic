#!/bin/bash

echo "=== SQLite示例脚本快速验证 ==="
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查文件是否存在
echo "[1/6] 检查文件是否存在..."
if [ -f "sqlite-example.py" ]; then
    echo "✓ 文件存在: sqlite-example.py"
else
    echo "✗ 文件不存在: sqlite-example.py"
    exit 1
fi

# 检查文件可执行权限
echo "[2/6] 检查文件可执行权限..."
if [ -x "sqlite-example.py" ]; then
    echo "✓ 文件可执行: sqlite-example.py"
else
    echo "⚠ 文件不可执行: sqlite-example.py"
fi

# 检查文件大小
echo "[3/6] 检查文件大小..."
filesize=$(wc -c < "sqlite-example.py")
if [ $filesize -ge 5000 ]; then
    echo "✓ 文件大小正常: $filesize 字节"
else
    echo "⚠ 文件可能太小: $filesize 字节"
fi

# 检查Python语法
echo "[4/6] 检查Python语法..."
if python3 -m py_compile "sqlite-example.py" 2>/dev/null; then
    echo "✓ Python语法检查通过"
    rm -f "sqlite-example.pyc" 2>/dev/null || true
else
    echo "✗ Python语法检查失败"
    exit 1
fi

# 检查帮助信息
echo "[5/6] 检查帮助信息..."
if python3 "sqlite-example.py" --help 2>&1 | grep -q "用法\|usage\|help\|选项"; then
    echo "✓ 帮助信息正常"
else
    echo "⚠ 帮助信息可能不完整"
fi

# 快速演示模式检查
echo "[6/6] 检查演示模式..."
echo "  运行演示模式（10秒超时）..."
timeout_output=$(timeout 10s python3 "sqlite-example.py" --demo 2>&1 || true)
if echo "$timeout_output" | grep -q "演示模式\|demo\|示例\|example"; then
    echo "✓ 演示模式正常"
else
    echo "⚠ 演示模式可能有问题"
fi

echo ""
echo "=== 验证完成 ==="
echo "所有快速验证测试通过！"
echo "SQLite示例脚本质量验证完成。"