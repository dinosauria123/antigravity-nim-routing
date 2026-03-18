#!/usr/bin/env bash
# llm_task.sh
# OllamaまたはNVIDIA NIMのOpenAI互換エンドポイントにタスクを投げるスクリプト
#
# 使い方:
#   bash llm_task.sh "<プロンプト>"
#   bash llm_task.sh "<モデル名>" "<プロンプト>"
#
# バックエンドの切り替え（環境変数）:
#   LLM_BACKEND=ollama  bash llm_task.sh "..."                     # ローカルOllama（デフォルト）
#   LLM_BACKEND=nim     bash llm_task.sh "..."                     # NVIDIA NIM
#   LLM_BACKEND=nim     bash llm_task.sh "qwen/qwen3.5-122b-a10b" "..."
#
# Thinkingモード制御（Qwen3.5はデフォルトでThinkingオン）:
#   NIM_THINKING=false  LLM_BACKEND=nim bash llm_task.sh "..."    # オフ（高速・省トークン）
#   NIM_THINKING=true   LLM_BACKEND=nim bash llm_task.sh "..."    # オン（複雑な推論向け）
#
# APIキーの設定（NIM使用時）:
#   export NVIDIA_API_KEY="nvapi-xxxxxxxxxxxx"
#   または .env ファイルに記述

set -euo pipefail

# ================================================================
# 設定
# ================================================================

# APIキー: 環境変数 NVIDIA_API_KEY が未設定なら .env から読む
# また LLM_BACKEND 等の変数も .env から読み込む
if [ -f "$(dirname "$0")/.env" ]; then
  # shellcheck disable=SC1091
  source "$(dirname "$0")/.env"
fi

# バックエンド: "ollama" or "nim"
BACKEND="${LLM_BACKEND:-ollama}"

# --- Ollama 設定 ---
OLLAMA_BASE_URL="${OLLAMA_HOST:-http://127.0.0.1:11434}"
OLLAMA_DEFAULT_MODEL="gemma3:1b"

# --- NVIDIA NIM 設定 ---
NIM_BASE_URL="https://integrate.api.nvidia.com"
NIM_DEFAULT_MODEL="qwen/qwen3.5-122b-a10b"
# Thinkingモード: デフォルトはオフ（コーディング補助は高速レスポンス優先）
NIM_THINKING="${NIM_THINKING:-false}"

# ================================================================
# 引数チェック
# ================================================================

if [ $# -lt 1 ]; then
  echo "使い方:" >&2
  echo "  bash llm_task.sh \"<プロンプト>\"" >&2
  echo "  bash llm_task.sh \"<モデル名>\" \"<プロンプト>\"" >&2
  echo "" >&2
  echo "環境変数:" >&2
  echo "  LLM_BACKEND=ollama|nim       (デフォルト: nim)" >&2
  echo "  NVIDIA_API_KEY=nvapi-xxxx    (NIM使用時に必須)" >&2
  echo "  NIM_THINKING=true|false      (デフォルト: false)" >&2
  exit 1
fi

if [ $# -eq 1 ]; then
  PROMPT="$1"
  if [ "$BACKEND" = "nim" ]; then
    MODEL="$NIM_DEFAULT_MODEL"
  else
    MODEL="$OLLAMA_DEFAULT_MODEL"
  fi
else
  MODEL="$1"
  PROMPT="$2"
fi

# ================================================================
# バックエンド別の前処理
# ================================================================

if [ "$BACKEND" = "nim" ]; then
  # --- NVIDIA NIM ---
  if [ -z "${NVIDIA_API_KEY:-}" ]; then
    echo "❌ NVIDIA_API_KEY が設定されていません" >&2
    echo "   export NVIDIA_API_KEY=\"nvapi-xxxxxxxxxxxx\"" >&2
    echo "   または llm_task.sh と同じディレクトリの .env に記述してください" >&2
    exit 1
  fi
  BASE_URL="$NIM_BASE_URL"
  AUTH_HEADER="Authorization: Bearer ${NVIDIA_API_KEY}"
  THINKING_LABEL=""
  if [ "$NIM_THINKING" = "true" ]; then
    THINKING_LABEL=" [Thinking ON]"
  fi
  echo "🌐 NVIDIA NIM: ${MODEL}${THINKING_LABEL}" >&2

else
  # --- Ollama ---
  if ! curl -sf "${OLLAMA_BASE_URL}/api/tags" > /dev/null 2>&1; then
    echo "❌ Ollamaに接続できません (${OLLAMA_BASE_URL})" >&2
    echo "   以下で起動してください: ollama serve" >&2
    exit 1
  fi

  # モデル存在確認
  MODEL_EXISTS=$(curl -sf "${OLLAMA_BASE_URL}/api/tags" \
    | grep -o "\"name\":\"${MODEL}[^\"]*\"" \
    | head -1 || true)

  if [ -z "$MODEL_EXISTS" ]; then
    echo "⚠️  モデル '${MODEL}' が見つかりません。利用可能なモデル:" >&2
    curl -sf "${OLLAMA_BASE_URL}/api/tags" \
      | grep -o '"name":"[^"]*"' \
      | sed 's/"name":"//;s/"//' >&2
    echo "" >&2
    echo "   ダウンロード: ollama pull ${MODEL}" >&2
    exit 1
  fi

  BASE_URL="$OLLAMA_BASE_URL"
  AUTH_HEADER="Authorization: Bearer ollama"
  echo "🖥️  Ollama: ${MODEL}" >&2
fi

# ================================================================
# プロンプトをJSON安全にエスケープ
# ================================================================

if command -v python3 &>/dev/null; then
  ESCAPED_PROMPT=$(python3 -c "import sys,json; print(json.dumps(sys.argv[1])[1:-1])" "$PROMPT")
else
  ESCAPED_PROMPT=$(printf '%s' "$PROMPT" \
    | sed 's/\\/\\\\/g' \
    | sed 's/"/\\"/g' \
    | sed ':a;N;$!ba;s/\n/\\n/g')
fi

# ================================================================
# Thinkingモード設定（NIM Qwen3.5 向け）
# ================================================================

EXTRA_PARAMS=""
if [ "$BACKEND" = "nim" ] && [ "$NIM_THINKING" = "false" ]; then
  EXTRA_PARAMS=', "chat_template_kwargs": { "enable_thinking": false }'
fi

# ================================================================
# OpenAI互換エンドポイントへリクエスト
# ================================================================

RESPONSE=$(curl -s --max-time 30 \
  "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "${AUTH_HEADER}" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [
      {
        \"role\": \"system\",
        \"content\": \"You are a helpful coding assistant. Be concise and practical.\"
      },
      {
        \"role\": \"user\",
        \"content\": \"${ESCAPED_PROMPT}\"
      }
    ],
    \"max_tokens\": 2048,
    \"stream\": false${EXTRA_PARAMS}
  }")  || true

# ================================================================
# レスポンスから本文を抽出
# ================================================================

if command -v python3 &>/dev/null; then
  echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['choices'][0]['message']['content'])
"
elif command -v jq &>/dev/null; then
  echo "$RESPONSE" | jq -r '.choices[0].message.content'
else
  echo "$RESPONSE" | grep -o '"content":"[^"]*"' | tail -1 | sed 's/"content":"//;s/"$//'
fi
