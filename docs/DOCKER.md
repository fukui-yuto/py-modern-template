# Docker ガイド

本番用 Docker イメージの使い方を説明します。

---

## 1. 本番用 Docker イメージ

### ビルド

```bash
just docker-build
# または
docker build -t my-app:latest .
```

### 実行

```bash
# CLI コマンドを実行
docker run --rm my-app:latest hello --name Yuto

# 環境変数を渡す
docker run --rm --env-file .env my-app:latest hello

# インタラクティブシェル
docker run --rm -it --entrypoint bash my-app:latest
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

## 2. テスト用 CI/CD インフラ

GitLab + Jenkins を**テスト用として**ローカルで動かすための Docker Compose がテンプレートリポジトリに用意されています。

```bash
# 起動（テンプレートリポジトリのルートで実行）
docker compose -f docker-compose.infra.yml up -d
# → GitLab: http://localhost:8929
# → Jenkins: http://localhost:8080

# 停止
docker compose -f docker-compose.infra.yml down

# 完全削除（データも消える）
docker compose -f docker-compose.infra.yml down -v
```

> **本番の GitLab / Jenkins を使う場合** は [PRODUCTION_CI.md](PRODUCTION_CI.md) を参照してください。

詳細は [INFRA_SETUP.md](INFRA_SETUP.md) を参照。
