#!/bin/bash
# 代码审查脚本 - 检查最近提交是否有问题

REPO_PATH="${1:-/home/jinyang/Koma}"
cd "$REPO_PATH" || exit 1

echo "=== 代码审查 ==="
echo ""

# 1. 检查最近提交是否有乱码
echo "1. 检查提交信息乱码:"
BAD_COMMITS=$(git log --oneline -20 | grep -E "瀹|鏂|淇|閿|瀛|妯|澘|璇|鐗|娴|鍚|绫" | wc -l)
if [ "$BAD_COMMITS" -gt 0 ]; then
  echo "   ❌ 发现 $BAD_COMMITS 个乱码提交!"
  git log --oneline -20 | grep -E "瀹|鏂|淇|閿|瀛|妯|澘|璇|鐗|娴|鍚|绫"
else
  echo "   ✅ 无乱码提交"
fi

echo ""

# 2. 检查代码中是否有 ???
echo "2. 检查代码乱码 (???):"
BAD_FILES=$(grep -rl "???" frontend/src --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
if [ "$BAD_FILES" -gt 0 ]; then
  echo "   ❌ 发现 $BAD_FILES 个文件有乱码!"
  grep -rl "???" frontend/src --include="*.ts" --include="*.tsx" 2>/dev/null
else
  echo "   ✅ 无代码乱码"
fi

echo ""

# 3. 检查最近一次提交的 diff
echo "3. 检查最近提交内容:"
LAST_COMMIT=$(git log --oneline -1)
echo "   最近提交: $LAST_COMMIT"
DIFF_ISSUES=$(git show HEAD -p | grep -E "^\+.*\?\?\?" | wc -l)
if [ "$DIFF_ISSUES" -gt 0 ]; then
  echo "   ❌ 最近提交包含乱码!"
else
  echo "   ✅ 最近提交正常"
fi

echo ""
echo "=== 审查完成 ==="

# 4. 检查 TypeScript 编译错误
echo "4. 检查 TypeScript 编译:"
cd frontend && npx tsc --noEmit 2>&1 | head -10
