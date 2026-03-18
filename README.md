# Antigravity NIM Routing

Antigravityの処理の一部をLLM (NVIDIA NIM) に代行させるスクリプトです。

## 機能

- **NVIDIA NIM (クラウドLLM)** へのリクエスト
- **Thinkingモード** の制御 (Qwen 3.5 など)
- **JSONエスケープ処理** の自動化

## セットアップ

1. リポジトリをダウンロードまたは `git clone` します。
2. `.env.example` をコピーして `.env` ファイルを作成します。
3. NVIDIA NIM を使用する場合は、`.env` に `NVIDIA_API_KEY` を設定してください。

```bash
cp .env.example .env
# .env を編集して API キーを入力
```

## 使い方

### Linux / macOS (`llm_task.sh`)

```bash
# デフォルトモデルで実行
bash llm_task.sh "こんにちは。自己紹介してください。"

# モデルを指定して実行
bash llm_task.sh "qwen/qwen3.5-122b-a10b" "複雑な数学の問題を解いてください。"

# バックエンドを切り替えて実行 (NIMを使用)
LLM_BACKEND=nim bash llm_task.sh "Hello"
```

### Windows (`llm_task.bat`)

Windows環境では `llm_task.bat` を使用できます。

## ライセンス

[MIT License](LICENSE)
