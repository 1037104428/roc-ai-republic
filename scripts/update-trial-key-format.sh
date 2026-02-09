#!/usr/bin/env bash
set -euo pipefail

# 更新 TRIAL_KEY 格式从 trial_xxx 到 sk-xxx
echo "更新 TRIAL_KEY 格式..."

# 更新文档文件
files=(
  "docs/quota-proxy_TRIAL_KEY_发放与使用.md"
  "web/site/quota-proxy.html"
  "docs/quickstart.md"
  "docs/小白一条龙_从0到可用.md"
  "web/index.html"
)

for file in "${files[@]}"; do
  if [[ -f "$file" ]]; then
    echo "处理: $file"
    # 替换 trial_xxx 为 sk-xxx
    sed -i 's/trial_xxx/sk-xxx/g' "$file"
    # 替换 trial_... 为 sk-...
    sed -i 's/trial_\.\.\./sk-.../g' "$file"
    # 替换 trial_abcd...wxyz 为 sk-abcd...wxyz
    sed -i 's/trial_\([a-z]\{4\}\)\.\.\.\([a-z]\{4\}\)/sk-\1...\2/g' "$file"
  else
    echo "跳过不存在的文件: $file"
  fi
done

# 检查是否有其他 trial_ 模式需要更新
echo "检查其他 trial_ 模式..."
grep -r "trial_" docs/ web/ --include="*.md" --include="*.html" 2>/dev/null | grep -v "trial_key\|TRIAL_KEY" || true

echo "更新完成。请验证更改并提交。"