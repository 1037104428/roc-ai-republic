#!/usr/bin/env bash
set -euo pipefail

echo "全面更新 TRIAL_KEY 格式从 trial_ 到 sk-..."

# 更新所有相关文件
find docs/ web/ -type f \( -name "*.md" -o -name "*.html" \) -exec grep -l "trial_" {} \; | while read file; do
  echo "处理: $file"
  
  # 保存原始文件
  cp "$file" "${file}.bak"
  
  # 替换各种 trial_ 模式
  # 1. trial_xxx -> sk-xxx
  sed -i 's/trial_xxx/sk-xxx/g' "$file"
  
  # 2. trial_... -> sk-...
  sed -i 's/trial_\.\.\./sk-.../g' "$file"
  
  # 3. trial_abc123def456 -> sk-abc123def456
  sed -i 's/trial_\([a-z0-9]\{12,\}\)/sk-\1/g' "$file"
  
  # 4. trial_abcd...wxyz -> sk-abcd...wxyz
  sed -i 's/trial_\([a-z]\{4\}\)\.\.\.\([a-z]\{4\}\)/sk-\1...\2/g' "$file"
  
  # 5. trial_<hex> -> sk-<hex>
  sed -i 's/trial_<hex>/sk-<hex>/g' "$file"
  
  # 6. trial_ 开头 -> sk- 开头
  sed -i 's/形如 `trial_/形如 `sk-/g' "$file"
  sed -i 's/格式为 `trial_/格式为 `sk-/g' "$file"
  
  # 7. trial_前缀 -> sk-前缀
  sed -i 's/trial_前缀/sk-前缀/g' "$file"
  
  # 检查是否还有 trial_ 模式
  if grep -q "trial_" "$file"; then
    echo "  警告: $file 中仍有 trial_ 模式"
    grep -n "trial_" "$file" | head -5
  fi
  
  # 删除备份文件
  rm -f "${file}.bak"
done

echo "更新完成。验证更改..."
echo "剩余的 trial_ 模式:"
grep -r "trial_" docs/ web/ --include="*.md" --include="*.html" 2>/dev/null | grep -v "trial_key\|TRIAL_KEY" | head -20 || true

echo "检查 sk- 模式:"
grep -r "sk-" docs/ web/ --include="*.md" --include="*.html" 2>/dev/null | head -10 || true