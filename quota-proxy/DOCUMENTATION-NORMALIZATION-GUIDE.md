# 文档规范化指南

## 概述

本指南旨在帮助管理和规范化quota-proxy项目中的文档文件，解决当前存在的重复文件、命名不一致等问题。

## 当前问题分析

### 1. 重复文档文件
通过分析发现存在以下重复文档：
- `CHECK-DEPLOYMENT-STATUS.md` (2026-02-11 20:52) - 7021字节
- `CHECK_DEPLOYMENT_STATUS.md` (2026-02-11 19:05) - 6364字节

### 2. 命名规范不一致
- 使用连字符：`CHECK-DEPLOYMENT-STATUS.md`
- 使用下划线：`CHECK_DEPLOYMENT_STATUS.md`
- 混合使用：`VERIFY-ADMIN-KEYS-ENDPOINTS.md` vs `VERIFY_ADMIN_KEYS_ENDPOINT.md`

## 规范化规则

### 1. 文件名规范
- **主文档文件**：使用连字符分隔单词，全大写字母
  - 示例：`CHECK-DEPLOYMENT-STATUS.md`
  - 示例：`ADMIN-API-EXAMPLES.md`
  - 示例：`VALIDATION-TOOLS-INDEX.md`

- **脚本文件**：使用连字符分隔单词，全小写字母
  - 示例：`check-deployment-status.sh`
  - 示例：`verify-admin-keys-endpoints.sh`
  - 示例：`init-sqlite-db.sh`

### 2. 文档结构规范
所有文档应包含以下标准章节：
```
# 文档标题

## 概述
简要说明文档目的和范围

## 快速开始
提供最简单的使用示例

## 详细说明
按功能或主题组织详细内容

## 使用示例
提供具体的使用场景和命令

## 故障排除
常见问题和解决方案

## 相关文档
链接到其他相关文档
```

### 3. 版本控制
- 每次文档更新应在文件开头添加版本记录
- 使用ISO日期格式：`YYYY-MM-DD`
- 记录变更内容和作者

## 清理计划

### 第一阶段：识别重复文件
```bash
# 查找可能的重复文档
find quota-proxy -name "*.md" -type f | sort | while read file; do
  base=$(basename "$file" .md | tr '[:upper:]' '[:lower:]' | tr '-' '_')
  echo "$base:$file"
done | sort | uniq -c | grep -v '^ *1 '
```

### 第二阶段：评估和合并
对于每个重复文件对：
1. 比较创建时间和内容
2. 保留最新或最完整的版本
3. 删除旧版本或重命名为备份
4. 更新所有引用

### 第三阶段：规范化命名
1. 将下划线命名改为连字符命名
2. 确保脚本和文档命名一致
3. 更新所有相关引用

## 具体操作步骤

### 1. 检查CHECK_DEPLOYMENT_STATUS重复文件
```bash
# 比较两个文件
diff -u quota-proxy/CHECK_DEPLOYMENT_STATUS.md quota-proxy/CHECK-DEPLOYMENT-STATUS.md

# 查看文件信息
ls -la quota-proxy/CHECK*.md
stat quota-proxy/CHECK*.md
```

### 2. 决定保留哪个版本
基于以下因素：
- 文件大小（更大的通常更完整）
- 修改时间（更新的通常更准确）
- 内容质量（检查结构和完整性）

### 3. 执行清理
```bash
# 备份旧文件
cp quota-proxy/CHECK_DEPLOYMENT_STATUS.md quota-proxy/CHECK_DEPLOYMENT_STATUS.md.backup

# 删除重复文件
rm quota-proxy/CHECK_DEPLOYMENT_STATUS.md

# 更新可能存在的引用
grep -r "CHECK_DEPLOYMENT_STATUS" quota-proxy/ --include="*.md" --include="*.sh"
```

## 自动化脚本

### 文档规范化检查脚本
```bash
#!/bin/bash
# document-normalization-check.sh

echo "=== 文档规范化检查 ==="
echo

# 检查重复文件
echo "1. 检查重复文档文件："
find . -name "*.md" -type f | sort | while read file; do
  base=$(basename "$file" .md | tr '[:upper:]' '[:lower:]' | tr '-' '_')
  echo "$base:$file"
done | sort | uniq -c | grep -v '^ *1 ' | while read count info; do
  echo "  发现 $count 个重复文件："
  echo "$info" | sed 's/^/     /'
done

echo

# 检查命名规范
echo "2. 检查命名规范："
echo "   a) 文档文件应使用连字符和大写："
find . -name "*.md" -type f | grep -v node_modules | while read file; do
  filename=$(basename "$file")
  if [[ ! "$filename" =~ ^[A-Z]+(-[A-Z]+)*\.md$ ]]; then
    echo "    不规范: $file"
  fi
done

echo "   b) 脚本文件应使用连字符和小写："
find . -name "*.sh" -type f | grep -v node_modules | while read file; do
  filename=$(basename "$file")
  if [[ ! "$filename" =~ ^[a-z]+(-[a-z]+)*\.sh$ ]]; then
    echo "    不规范: $file"
  fi
done
```

### 文档规范化修复脚本
```bash
#!/bin/bash
# document-normalization-fix.sh

echo "=== 文档规范化修复 ==="
echo

# 修复CHECK_DEPLOYMENT_STATUS重复
if [[ -f "quota-proxy/CHECK_DEPLOYMENT_STATUS.md" && -f "quota-proxy/CHECK-DEPLOYMENT-STATUS.md" ]]; then
  echo "1. 处理CHECK_DEPLOYMENT_STATUS重复文件："
  echo "   - CHECK_DEPLOYMENT_STATUS.md: $(stat -c %y quota-proxy/CHECK_DEPLOYMENT_STATUS.md)"
  echo "   - CHECK-DEPLOYMENT-STATUS.md: $(stat -c %y quota-proxy/CHECK-DEPLOYMENT-STATUS.md)"
  
  # 比较文件大小，保留较大的
  size1=$(stat -c %s quota-proxy/CHECK_DEPLOYMENT_STATUS.md)
  size2=$(stat -c %s quota-proxy/CHECK-DEPLOYMENT-STATUS.md)
  
  if [[ $size2 -gt $size1 ]]; then
    echo "   - 保留CHECK-DEPLOYMENT-STATUS.md（大小: $size2 > $size1）"
    mv quota-proxy/CHECK_DEPLOYMENT_STATUS.md quota-proxy/CHECK_DEPLOYMENT_STATUS.md.backup
    echo "   - 已将旧文件备份为CHECK_DEPLOYMENT_STATUS.md.backup"
  else
    echo "   - 保留CHECK_DEPLOYMENT_STATUS.md（大小: $size1 >= $size2）"
    mv quota-proxy/CHECK-DEPLOYMENT-STATUS.md quota-proxy/CHECK-DEPLOYMENT-STATUS.md.backup
    echo "   - 已将新文件备份为CHECK-DEPLOYMENT-STATUS.md.backup"
  fi
fi

echo
echo "2. 检查并修复其他可能的重复..."
```

## 维护建议

### 1. 定期检查
建议每月运行一次文档规范化检查，确保文档质量。

### 2. 提交前检查
在提交新文档前，检查是否与现有文档重复或冲突。

### 3. 文档模板
为新文档创建标准模板，确保一致性。

### 4. 自动化集成
将文档检查集成到CI/CD流程中，自动检测问题。

## 相关文档

- [VALIDATION-TOOLS-INDEX.md](./VALIDATION-TOOLS-INDEX.md) - 验证工具索引
- [ADMIN-API-EXAMPLES.md](./ADMIN-API-EXAMPLES.md) - Admin API示例
- [CHECK-DEPLOYMENT-STATUS.md](./CHECK-DEPLOYMENT-STATUS.md) - 部署状态检查

---

**版本记录**
- 2026-02-11: 创建文档规范化指南，提供重复文件管理和命名规范
- 作者: 阿爪 (OpenClaw自动化助手)