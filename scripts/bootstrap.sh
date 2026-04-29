#!/usr/bin/env bash
# =============================================================================
# 初回セットアップスクリプト
# 使い方: bash scripts/bootstrap.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---- uv の存在確認 ----
if ! command -v uv &> /dev/null; then
    error "uv がインストールされていません"
    info  "インストール: https://docs.astral.sh/uv/getting-started/installation/"
    info  "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    info  "  または: pip install uv"
    exit 1
fi
info "uv $(uv version) を検出"

# ---- Python の確認・インストール ----
PYTHON_VERSION=$(cat .python-version 2>/dev/null || echo "3.12")
info "Python ${PYTHON_VERSION} を確認中..."
uv python install "${PYTHON_VERSION}" 2>/dev/null || true

# ---- 依存インストール ----
info "依存パッケージをインストール中..."
uv sync --all-extras

# ---- pre-commit セットアップ ----
info "pre-commit フックをインストール中..."
uv run pre-commit install

# ---- .env ファイルの作成 ----
if [ ! -f .env ]; then
    info ".env.example から .env を作成中..."
    cp .env.example .env
else
    warn ".env は既に存在するためスキップ"
fi

# ---- 動作確認 ----
info "動作確認: ruff check..."
uv run ruff check . && info "  ruff check: OK" || warn "  ruff check: 問題あり"

info "動作確認: ruff format..."
uv run ruff format --check . && info "  ruff format: OK" || warn "  ruff format: 問題あり"

info "動作確認: mypy..."
uv run mypy src tests && info "  mypy: OK" || warn "  mypy: 問題あり"

info "動作確認: pytest..."
uv run pytest && info "  pytest: OK" || warn "  pytest: 問題あり"

echo ""
info "=================================================="
info "  セットアップ完了!"
info "=================================================="
info ""
info "  次のコマンドで動作確認できます:"
info "    uv run py_modern_template hello --name Yuto"
info ""
info "  開発コマンド一覧:"
info "    just          # コマンド一覧を表示"
info "    just lint      # Lint チェック"
info "    just fmt       # 自動フォーマット"
info "    just typecheck # 型チェック"
info "    just test      # テスト実行"
info "    just ci        # CI と同じチェックを一括実行"
info ""
