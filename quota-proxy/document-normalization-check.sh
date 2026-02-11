#!/bin/bash
# document-normalization-check.sh
# 文档规范化检查脚本

set -e

echo "=== 文档规范化检查 ==="
echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# 检查重复文件
echo "1. 检查重复文档文件："
echo "----------------------------------------"
find . -name "*.md" -type f | grep -v node_modules | sort | while read file; do
  base=$(basename "$file" .md | tr '[:upper:]' '[:lower:]' | tr '-' '_')
  echo "$base:$file"
done | sort | uniq -c | grep -v '^ *1 ' > /tmp/duplicate_check.txt

if [[ -s /tmp/duplicate_check.txt ]]; then
  echo "发现以下重复文件："
  cat /tmp/duplicate_check.txt | while read count info; do
    echo "  $count 个重复文件："
    echo "$info" | sed 's/:/\\n    /g' | sed 's/^/    /'
  done
else
  echo "  未发现重复文档文件 ✓"
fi
rm -f /tmp/duplicate_check.txt

echo
echo "2. 检查命名规范："
echo "----------------------------------------"

# 检查文档文件命名规范（应使用连字符和大写）
echo "   a) 文档文件命名规范检查（应使用连字符和大写字母）："
doc_issues=0
find . -name "*.md" -type f | grep -v node_modules | while read file; do
  filename=$(basename "$file")
  # 检查是否使用连字符和大写
  if [[ ! "$filename" =~ ^[A-Z]+(-[A-Z]+)*\.md$ ]]; then
    # 排除一些特殊文件
    if [[ ! "$filename" =~ ^README\.md$ ]] && [[ ! "$filename" =~ ^CHANGELOG\.md$ ]] && [[ ! "$filename" =~ ^LICENSE\.md$ ]]; then
      echo "    ✗ 不规范: $file"
      doc_issues=$((doc_issues + 1))
    fi
  fi
done
if [[ $doc_issues -eq 0 ]]; then
  echo "    所有文档文件命名规范 ✓"
fi

echo
# 检查脚本文件命名规范（应使用连字符和小写）
echo "   b) 脚本文件命名规范检查（应使用连字符和小写字母）："
script_issues=0
find . -name "*.sh" -type f | grep -v node_modules | while read file; do
  filename=$(basename "$file")
  # 检查是否使用连字符和小写
  if [[ ! "$filename" =~ ^[a-z]+(-[a-z]+)*\.sh$ ]]; then
    echo "    ✗ 不规范: $file"
    script_issues=$((script_issues + 1))
  fi
done
if [[ $script_issues -eq 0 ]]; then
  echo "    所有脚本文件命名规范 ✓"
fi

echo
echo "3. 检查文档结构完整性："
echo "----------------------------------------"
echo "   a) 检查标准章节结构："
structure_issues=0
find . -name "*.md" -type f | grep -v node_modules | head -5 | while read file; do
  echo "    检查: $file"
  
  # 检查是否有概述章节
  if ! grep -q "## 概述" "$file" 2>/dev/null; then
    echo "      ✗ 缺少'## 概述'章节"
    structure_issues=$((structure_issues + 1))
  fi
  
  # 检查是否有使用示例章节
  if ! grep -q "## 使用示例" "$file" 2>/dev/null; then
    echo "      ✗ 缺少'## 使用示例'章节"
    structure_issues=$((structure_issues + 1))
  fi
done

if [[ $structure_issues -eq 0 ]]; then
  echo "    文档结构基本完整 ✓"
fi

echo
echo "4. 检查具体重复文件详情："
echo "----------------------------------------"
# 检查已知的重复文件
if [[ -f "./CHECK_DEPLOYMENT_STATUS.md" && -f "./CHECK-DEPLOYMENT-STATUS.md" ]]; then
  echo "  发现CHECK_DEPLOYMENT_STATUS重复文件："
  echo "    - CHECK_DEPLOYMENT_STATUS.md"
  echo "      大小: $(stat -c %s ./CHECK_DEPLOYMENT_STATUS.md) 字节"
  echo "      修改时间: $(stat -c %y ./CHECK_DEPLOYMENT_STATUS.md)"
  echo "    - CHECK-DEPLOYMENT-STATUS.md"
  echo "      大小: $(stat -c %s ./CHECK-DEPLOYMENT-STATUS.md) 字节"
  echo "      修改时间: $(stat -c %y ./CHECK-DEPLOYMENT-STATUS.md)"
  
  # 比较内容差异
  diff_output=$(diff -u ./CHECK_DEPLOYMENT_STATUS.md ./CHECK-DEPLOYMENT-STATUS.md 2>/dev/null | head -20)
  if [[ -n "$diff_output" ]]; then
    echo "    内容差异（前20行）："
    echo "$diff_output" | sed 's/^/      /'
  else
    echo "    内容完全相同"
  fi
else
  echo "  未发现已知重复文件 ✓"
fi

echo
echo "=== 检查完成 ==="
echo "总结："
echo "  - 文档重复检查: $(if [[ -f "./CHECK_DEPLOYMENT_STATUS.md" && -f "./CHECK-DEPLOYMENT-STATUS.md" ]]; then echo "发现重复"; else echo "通过"; fi)"
echo "  - 文档命名规范问题: $doc_issues 个"
echo "  - 脚本命名规范问题: $script_issues 个"
echo "  - 文档结构问题: $structure_issues 个"
echo
echo "建议操作："
if [[ -f "./CHECK_DEPLOYMENT_STATUS.md" && -f "./CHECK-DEPLOYMENT-STATUS.md" ]]; then
  echo "  1. 运行文档规范化修复脚本处理重复文件"
  echo "  2. 参考DOCUMENTATION-NORMALIZATION-GUIDE.md进行规范化"
fi
if [[ $doc_issues -gt 0 || $script_issues -gt 0 ]]; then
  echo "  3. 修复命名不规范的文件"
fi
if [[ $structure_issues -gt 0 ]]; then
  echo "  4. 补充缺失的文档章节"
fi

exit 0