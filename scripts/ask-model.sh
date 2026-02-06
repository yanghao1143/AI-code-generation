#!/bin/bash
# 快速咨询其他模型
# 用法: ask-model.sh <model> "问题"
# model: gemini | gpt | kimi

MODEL="$1"
QUESTION="$2"
BASE_URL="https://claude.chiddns.com/v1"
API_KEY="sk-MgjQOD5s4xdnBfueHBgAiCxrtvgfN0xU1J24SyRIl1JUMUu2"

case "$MODEL" in
  gemini)
    MODEL_ID="gemini-3-pro-preview"
    ;;
  gpt)
    MODEL_ID="gpt-5-codex"
    ;;
  kimi)
    MODEL_ID="kimi-k2.5"
    ;;
  *)
    echo "Unknown model: $MODEL"
    exit 1
    ;;
esac

curl -s "$BASE_URL/chat/completions" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL_ID\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$QUESTION\"}],
    \"max_tokens\": 1000
  }" | jq -r '.choices[0].message.content // .error.message'
