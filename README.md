# py-modern-template

モダンな Python AI/LLM 開発のためのプロジェクトテンプレート。

`uv` + `ruff` + `mypy` + `pytest` + `just` を中心とした 2026 年時点でのベストプラクティス構成。

---

## 特徴

- **uv** による高速な Python・依存管理（pyenv / pipenv / poetry を統合）
- **ruff** による Lint + Format（flake8 / black / isort を統合）
- **mypy** による厳密な型チェック
- **pytest** によるテスト + カバレッジ
- **just** によるタスクランナー（Makefile 代替）
- **Pydantic Settings** による環境変数管理
- **structlog** による構造化ログ
- **pre-commit** による自動品質チェック
- **3 種の CI/CD** 対応（GitHub Actions / GitLab CI / Jenkins）
- **Docker** マルチステージビルド + **devcontainer**
- **LLM 依存はオプショナル**（`uv sync --extra llm` で追加）

---

## クイックスタート

### 前提条件

- [uv](https://docs.astral.sh/uv/) >= 0.4
- [just](https://github.com/casey/just) （任意だが推奨）

### セットアップ

```bash
# 方法 1: bootstrap スクリプト（推奨）
bash scripts/bootstrap.sh

# 方法 2: just コマンド
just setup

# 方法 3: 手動
uv sync --all-extras
uv run pre-commit install
cp .env.example .env
```

### 動作確認

```bash
uv run py_modern_template hello --name Yuto
# => Hello, Yuto!
```

---

## 開発コマンド

| 用途 | コマンド |
|---|---|
| コマンド一覧 | `just` |
| Lint | `just lint` |
| Format | `just fmt` |
| 型チェック | `just typecheck` |
| テスト | `just test` |
| CI 相当（一括） | `just ci` |
| CLI 実行 | `just run hello --name Yuto` |
| 依存追加 | `just add requests` |
| Docker ビルド | `just docker-build` |

---

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | アーキテクチャ・設計思想 |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | 開発ガイド（日常の開発フロー） |
| [docs/USER_GUIDE.md](docs/USER_GUIDE.md) | ユーザーガイド（初心者向け） |
| [docs/TECH_STACK.md](docs/TECH_STACK.md) | 技術スタック詳細 |
| [docs/INFRA_SETUP.md](docs/INFRA_SETUP.md) | テスト用 CI/CD インフラ構築 |
| [docs/CI_CD.md](docs/CI_CD.md) | CI/CD パイプライン設定 |
| [docs/PRODUCTION_CI.md](docs/PRODUCTION_CI.md) | 本番 GitLab/Jenkins への接続・変更箇所 |
| [docs/DOCKER.md](docs/DOCKER.md) | Docker / devcontainer ガイド |
| [docs/MIGRATION.md](docs/MIGRATION.md) | 旧構成からの移行ガイド |
| [CHANGELOG.md](CHANGELOG.md) | 変更履歴 |

---

## ディレクトリ構成

```
py-modern-template/
├── .github/workflows/    CI/CD（GitHub Actions）
├── .devcontainer/        VSCode devcontainer
├── .vscode/              VSCode 設定
├── src/
│   └── py_modern_template/
│       ├── __init__.py   パッケージ定義
│       ├── cli.py        CLI エントリポイント
│       ├── config.py     Pydantic Settings
│       └── logging.py    構造化ログ
├── tests/                テスト
├── docs/                 ドキュメント
├── scripts/              ユーティリティスクリプト
├── .gitlab-ci.yml        GitLab CI 設定
├── Jenkinsfile           Jenkins Pipeline
├── Dockerfile            本番用コンテナ
├── docker-compose.yml    開発用
├── docker-compose.infra.yml  テスト用 CI/CD インフラ
├── justfile              タスクランナー
├── pyproject.toml        プロジェクト設定（全集約）
└── .pre-commit-config.yaml  コミット前チェック
```

---

## ライセンス

MIT
