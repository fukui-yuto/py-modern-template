# py-modern-template

モダンな Python AI/LLM 開発のためのプロジェクトテンプレート。

`uv` + `ruff` + `mypy` + `pytest` + `just` を中心とした 2026 年時点でのベストプラクティス構成。
**copier** による対話式プロジェクト生成に対応しています。

---

## 特徴

- **copier** による対話式プロジェクト生成(不要なファイルは自動除外)
- **uv** による高速な Python・依存管理(pyenv / pipenv / poetry を統合)
- **ruff** による Lint + Format(flake8 / black / isort を統合)
- **mypy** による厳密な型チェック
- **pytest** によるテスト + カバレッジ
- **just** によるタスクランナー(Makefile 代替)
- **Pydantic Settings** による環境変数管理
- **structlog** による構造化ログ
- **CI/CD** 対応(GitLab CI / Jenkins)
- **Docker** マルチステージビルド
- **LLM 依存はオプショナル**(選択式)

---

## クイックスタート

### 前提条件

- [uv](https://docs.astral.sh/uv/) >= 0.4
- [copier](https://copier.readthedocs.io/) >= 9.0

```bash
# copier のインストール
uv tool install copier
```

### プロジェクト生成

```bash
copier copy gh:fukui-yuto/py-modern-template ./my-project
```

対話式で以下を聞かれます:

```
プロジェクト名: My RAG App
パッケージ名:   my_rag_app         (自動生成)
説明:           RAGを使った社内検索
Python:         3.12
LLM extras:     Yes / No
CI/CD:          GitLab CI / GitLab CI + Jenkins / Jenkins / なし
Docker:         Yes / No
ライセンス:      MIT / Apache-2.0 / Proprietary
```

回答に応じて**必要なファイルだけ**が生成されます。

### 生成後のセットアップ

```bash
cd my-project
bash scripts/bootstrap.sh   # 依存インストール + pre-commit + 動作確認
```

### 動作確認

```bash
uv run my_rag_app hello --name Yuto
# => Hello, Yuto!
```

---

## 生成されるファイル(選択により変わる)

```
my_project/
├── src/my_project/          アプリケーションコード
│   ├── __init__.py
│   ├── cli.py               CLI エントリポイント(Typer)
│   ├── config.py            設定管理(Pydantic Settings)
│   └── logging.py           構造化ログ(structlog)
├── tests/                   テスト(pytest)
├── scripts/bootstrap.sh     初回セットアップ
├── pyproject.toml           全設定集約
├── justfile                 タスクランナー
├── .pre-commit-config.yaml  コミット前チェック
├── .gitignore / .python-version / .env.example
│
├── .gitlab-ci.yml           (CI: gitlab 選択時)
├── Jenkinsfile              (CI: jenkins / gitlab+jenkins 選択時)
│
├── Dockerfile               (Docker: Yes 選択時)
│
├── LICENSE                  (Proprietary 以外)
├── CHANGELOG.md
└── README.md
```

---

## テンプレート更新の取り込み

copier の強みは、テンプレートが更新されたときに既存プロジェクトに差分適用できることです:

```bash
cd my-project
copier update
```

---

## ドキュメント

| ドキュメント | 内容 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | アーキテクチャ・設計思想 |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | 開発ガイド(日常の開発フロー) |
| [docs/USER_GUIDE.md](docs/USER_GUIDE.md) | ユーザーガイド(初心者向け) |
| [docs/TECH_STACK.md](docs/TECH_STACK.md) | 技術スタック詳細 |
| [docs/CI_CD.md](docs/CI_CD.md) | CI/CD パイプライン設定 |
| [docs/PRODUCTION_CI.md](docs/PRODUCTION_CI.md) | 本番 GitLab/Jenkins への接続 |
| [docs/DOCKER.md](docs/DOCKER.md) | Docker ガイド |
| [docs/INFRA_SETUP.md](docs/INFRA_SETUP.md) | テスト用 CI/CD インフラ構築 |
| [docs/MIGRATION.md](docs/MIGRATION.md) | 旧構成からの移行ガイド |
| [TEMPLATE_SPEC.md](TEMPLATE_SPEC.md) | テンプレート設計仕様書(参考資料) |

---

## リポジトリ構成

```
py-modern-template/               ← テンプレートリポジトリ
├── copier.yml                    対話式質問の定義
├── template/                     テンプレートファイル(Jinja2)
│   ├── src/{{ project_slug }}/
│   ├── tests/
│   ├── scripts/
│   └── ...
├── docs/                         ドキュメント
├── docker-compose.infra.yml      テンプレート検証用(生成対象外)
├── TEMPLATE_SPEC.md              設計仕様書(参考資料)
└── README.md                     このファイル
```

---

## ライセンス

MIT
