# Docker / devcontainer ガイド

本番用 Docker イメージと、開発用 devcontainer の使い方を説明します。

---

## 1. 本番用 Docker イメージ

### ビルド

```bash
just docker-build
# または
docker build -t py-modern-template:latest .
```

### 実行

```bash
# CLI コマンドを実行
docker run --rm py-modern-template:latest hello --name Yuto

# 環境変数を渡す
docker run --rm --env-file .env py-modern-template:latest hello

# インタラクティブシェル
docker run --rm -it --entrypoint bash py-modern-template:latest
```

### docker-compose で実行

```bash
# .env ファイルを用意してから
cp .env.example .env

# 起動
docker compose up -d

# ログ確認
docker compose logs -f

# 停止
docker compose down
```

### イメージの仕組み（マルチステージビルド）

```dockerfile
# Stage 1: builder — 依存をインストール
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder
# pyproject.toml + uv.lock → 依存インストール → src/ コピー

# Stage 2: runtime — 最小限の実行環境
FROM python:3.12-slim-bookworm AS runtime
# .venv と src/ だけをコピー。uv やビルドツールは含まない
```

**ポイント:**
- `pyproject.toml` と `uv.lock` を先にコピーしてから依存をインストール
- コードが変わっても依存のレイヤキャッシュが効く
- 最終イメージにはビルドツールを含めない（サイズ削減 + セキュリティ）
- `app` ユーザーで実行（root で動かさない）

### イメージサイズの目安

| 構成 | サイズ |
|---|---|
| コア依存のみ | 約 150 MB |
| LLM extras 込み | 約 500 MB - 1 GB |

---

## 2. devcontainer（VSCode）

### devcontainer とは

VSCode の **Dev Containers** 拡張機能を使って、Docker コンテナ内で開発する仕組みです。

**メリット:**
- チーム全員が同じ開発環境を使える
- ローカル環境を汚さない
- Python / uv / just が最初からインストール済み

### 使い方

#### 前提条件

1. VSCode がインストール済み
2. Docker Desktop が起動している
3. VSCode 拡張機能 **Dev Containers** (`ms-vscode-remote.remote-containers`) がインストール済み

#### 起動手順

1. VSCode でこのプロジェクトを開く
2. 左下の `><` アイコンをクリック（またはコマンドパレットで `Dev Containers: Reopen in Container`）
3. 初回はイメージのビルドに数分かかる
4. コンテナ内で自動的に `uv sync --all-extras && uv run pre-commit install` が実行される
5. ターミナルを開いて開発開始

#### devcontainer の構成

```
.devcontainer/
├── Dockerfile          # ベースイメージ + uv + just
└── devcontainer.json   # VSCode 設定・拡張機能
```

**プリインストールされる VSCode 拡張機能:**

| 拡張機能 | 用途 |
|---|---|
| charliermarsh.ruff | ruff Lint / Format |
| ms-python.python | Python サポート |
| ms-python.mypy-type-checker | mypy 統合 |
| tamasfe.even-better-toml | TOML 構文ハイライト |
| redhat.vscode-yaml | YAML サポート |

**自動設定:**
- 保存時に ruff で自動フォーマット
- 保存時に import を自動整理
- Python インタープリタは `.venv/bin/python` を自動選択

---

## 3. テスト用 CI/CD インフラ

GitLab + Jenkins をローカルで動かすための Docker Compose:

```bash
# 起動
just infra-up
# → GitLab: http://localhost:8929
# → Jenkins: http://localhost:8080

# 停止
just infra-down

# 完全削除（データも消える）
just infra-clean
```

詳細は [INFRA_SETUP.md](INFRA_SETUP.md) を参照。
