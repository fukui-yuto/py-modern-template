# デフォルトでヘルプ表示
default:
    @just --list

# 初回セットアップ
setup:
    uv sync --all-extras
    uv run pre-commit install

# 依存追加(例: just add requests)
add package:
    uv add {{ package }}

# 依存追加(dev)
add-dev package:
    uv add --dev {{ package }}

# Lint
lint:
    uv run ruff check .
    uv run ruff format --check .

# Format
fmt:
    uv run ruff format .
    uv run ruff check --fix .

# 型チェック
typecheck:
    uv run mypy src tests

# テスト
test:
    uv run pytest

# CI と同じチェックをローカルで
ci: lint typecheck test

# クリーンアップ
clean:
    rm -rf .venv .ruff_cache .mypy_cache .pytest_cache htmlcov dist build
    find . -type d -name __pycache__ -exec rm -rf {} +

# Docker ビルド
docker-build:
    docker build -t py-modern-template:latest .

# CLI 実行
run *ARGS:
    uv run py_modern_template {{ ARGS }}

# インフラ起動 (GitLab + Jenkins)
infra-up:
    docker compose -f docker-compose.infra.yml up -d

# インフラ停止
infra-down:
    docker compose -f docker-compose.infra.yml down

# インフラ完全削除
infra-clean:
    docker compose -f docker-compose.infra.yml down -v
