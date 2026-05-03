# Python AI/LLM 開発テンプレートリポジトリ仕様書

このドキュメントは、Claude Code に渡してテンプレートリポジトリを生成するための**初期仕様書**です。

> **注意:** このドキュメントは初期設計時の仕様であり、実装中に多くの改善が加えられています。
> 実際のテンプレートファイルとの間に差異がある場合は、**テンプレートファイル（`template/` 配下）が正**です。
> 最新の設定は `copier.yml` および各テンプレートファイルを参照してください。

---

## 1. プロジェクト概要

### 目的
インフラ仮想化エンジニアが Python 開発（AI/LLM を含む）に取り組むための、2026年時点でのモダンな Python プロジェクトテンプレートを構築する。社内既存の `pyenv + pipenv + cookiecutter + GitLab CI → Jenkins` 構成を、`uv` 中心のモダンスタックに置き換える。

### 用途
- 一般的な Python アプリケーション全般
- RAG + Agent システム開発(LangChain, ChromaDB, Streamlit など — オプション)
- インフラ・仮想化関連のスクリプト・ツール開発

### リポジトリ名(推奨)
`python-ai-template` または `py-modern-template`

---

## 2. 技術スタック

| レイヤー | 採用ツール | バージョン目安 | 役割 |
|---|---|---|---|
| Python ランタイム管理 | **uv** | 最新 | Python 本体・仮想環境・依存管理を統合 |
| パッケージ管理 | **uv** | 最新 | `pyproject.toml` + `uv.lock` |
| Lint / Format | **ruff** | 最新 | flake8 / black / isort を統合 |
| 型チェック | **mypy** | 1.x 系 | 静的型検査(ty は将来的に検討) |
| テスト | **pytest** | 8.x 系 | + pytest-cov, pytest-asyncio, pytest-recording |
| タスクランナー | **just** | 最新 | Makefile 代替 |
| プロジェクトテンプレート展開 | **copier** | 最新 | cookiecutter 代替(再適用可能) |
| プリコミット | **pre-commit** | 最新 | ruff を組み込み |
| バリデーション | **Pydantic** | v2 | LLM 構造化出力にも利用 |
| CI/CD | **GitLab CI** / **Jenkins** | - | 両対応の設定を用意 |
| コンテナ | **Docker** | - | マルチステージビルドで本番イメージを最小化 |
| LLM 関連(オプション) | LangChain / LangSmith / ChromaDB | - | extras で切替 |

### 重要な設計方針
- **Python 3.12 を標準**(3.11 / 3.13 もサポート)
- **すべて `pyproject.toml` に集約**(setup.py / setup.cfg / requirements.txt は作らない)
- **`src/` レイアウト採用**(import 事故防止)
- **LLM 関連依存はオプショナル**(`uv sync --extra llm` で導入)

---

## 3. ディレクトリ構成

```
python-ai-template/
├── .gitlab-ci.yml                  # GitLab CI 設定
├── Jenkinsfile                     # Jenkins Pipeline 設定
├── src/
│   └── {{ project_slug }}/
│       ├── __init__.py
│       ├── config.py               # Pydantic Settings
│       ├── logging.py              # 構造化ログ設定
│       └── cli.py                  # エントリポイント
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_smoke.py
├── docs/
│   ├── ARCHITECTURE.md
│   └── DEVELOPMENT.md
├── scripts/
│   └── bootstrap.sh                # 初回セットアップ
├── .pre-commit-config.yaml
├── .gitignore
├── .python-version                 # uv が読む(3.12)
├── .env.example
├── Dockerfile
├── justfile
├── pyproject.toml
├── uv.lock
├── copier.yml                      # テンプレート化する場合
├── LICENSE
├── README.md
└── CHANGELOG.md
```

---

## 4. 各ファイルの詳細仕様

### 4.1 `pyproject.toml`

```toml
[project]
name = "{{ project_slug }}"
version = "0.1.0"
description = "{{ project_description }}"
readme = "README.md"
requires-python = ">=3.11"
license = { text = "MIT" }
authors = [{ name = "{{ author_name }}" }]
dependencies = [
    "pydantic>=2.7",
    "pydantic-settings>=2.3",
    "structlog>=24.1",
    "typer>=0.12",
]

[project.optional-dependencies]
llm = [
    "langchain>=0.3",
    "langchain-google-genai>=2.0",
    "chromadb>=0.5",
    "streamlit>=1.38",
    "langsmith>=0.1",
]
dev = [
    "ruff>=0.6",
    "mypy>=1.11",
    "pytest>=8.3",
    "pytest-cov>=5.0",
    "pytest-asyncio>=0.24",
    "pytest-recording>=0.13",
    "pre-commit>=3.8",
    "types-requests",
]

[project.scripts]
{{ project_slug }} = "{{ project_slug }}.cli:app"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/{{ project_slug }}"]

[tool.ruff]
line-length = 100
target-version = "py312"
src = ["src", "tests"]

[tool.ruff.lint]
select = [
    "E", "W",   # pycodestyle
    "F",        # pyflakes
    "I",        # isort
    "B",        # bugbear
    "UP",       # pyupgrade
    "N",        # pep8-naming
    "SIM",      # simplify
    "RUF",      # ruff-specific
]
ignore = ["E501"]  # line-length は formatter に任せる

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
no_implicit_optional = true
plugins = ["pydantic.mypy"]

[[tool.mypy.overrides]]
module = ["langchain.*", "chromadb.*"]
ignore_missing_imports = true

[tool.pytest.ini_options]
minversion = "8.0"
testpaths = ["tests"]
addopts = "-ra --cov=src --cov-report=term-missing --cov-report=xml"
asyncio_mode = "auto"

[tool.coverage.run]
branch = true
source = ["src"]

[tool.coverage.report]
exclude_lines = ["pragma: no cover", "if TYPE_CHECKING:", "raise NotImplementedError"]
```

### 4.2 `justfile`

```just
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

# 依存追加(dev: optional-dependencies の dev グループに追加)
add-dev package:
    uv add --optional dev {{ package }}

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
    docker build -t {{ project_slug }}:latest .

# CLI 実行
run *ARGS:
    uv run {{ project_slug }} {{ ARGS }}
```

### 4.3 `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.11.8
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: [--maxkb=1000]
      - id: check-merge-conflict
      - id: detect-private-key

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.15.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic>=2.7, types-requests]
        args: [--config-file=pyproject.toml]
        files: ^src/
```

### 4.4 `.gitlab-ci.yml`

```yaml
stages:
  - lint
  - test
  - build

variables:
  UV_CACHE_DIR: .uv-cache
  PYTHON_VERSION: "3.12"

.uv-base:
  image: ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-bookworm-slim
  before_script:
    - uv sync --all-extras --frozen
  cache:
    key: uv-${PYTHON_VERSION}
    paths:
      - .uv-cache/
      - .venv/

lint:ruff:
  extends: .uv-base
  stage: lint
  script:
    - uv run ruff check .
    - uv run ruff format --check .

lint:mypy:
  extends: .uv-base
  stage: lint
  script:
    - uv run mypy src tests

test:pytest:
  extends: .uv-base
  stage: test
  script:
    - uv run pytest --junitxml=report.xml
  artifacts:
    reports:
      junit: report.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
```

### 4.5 `Dockerfile`

```dockerfile
# ============ builder ============
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/app/.venv

WORKDIR /app

# 依存だけ先にインストール(レイヤキャッシュ最適化)
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

# プロジェクト本体
COPY README.md ./
COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# ============ runtime ============
FROM python:3.12-slim-bookworm AS runtime

RUN groupadd -r app && useradd -r -g app app

WORKDIR /app

COPY --from=builder --chown=app:app /app/.venv /app/.venv
COPY --from=builder --chown=app:app /app/src /app/src

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER app

ENTRYPOINT ["python", "-m", "{{ project_slug }}.cli"]
```

### 4.6 `src/{{ project_slug }}/config.py`

```python
"""アプリケーション設定。環境変数 / .env ファイルから読み込む。"""
from __future__ import annotations

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """アプリケーション全体の設定。"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = Field(default="{{ project_slug }}")
    log_level: str = Field(default="INFO")
    debug: bool = Field(default=False)

    # LLM 関連(extras=llm のときだけ使う)
    google_api_key: str | None = Field(default=None)
    langsmith_api_key: str | None = Field(default=None)
    langsmith_project: str = Field(default="{{ project_slug }}")


settings = Settings()
```

### 4.7 `src/{{ project_slug }}/logging.py`

```python
"""structlog による構造化ログ設定。"""
from __future__ import annotations

import logging
import sys

import structlog


def configure_logging(level: str = "INFO", *, json_output: bool = False) -> None:
    """structlog を初期化する。"""
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=level.upper(),
    )

    processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]

    if json_output:
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(
            getattr(logging, level.upper())
        ),
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    return structlog.get_logger(name)
```

### 4.8 `src/{{ project_slug }}/cli.py`

```python
"""CLI エントリポイント(Typer)。"""
from __future__ import annotations

import typer

from .config import settings
from .logging import configure_logging, get_logger

app = typer.Typer(help="{{ project_description }}")


@app.callback()
def main(
    debug: bool = typer.Option(False, "--debug", help="デバッグモード"),
) -> None:
    configure_logging(level="DEBUG" if debug else settings.log_level)


@app.command()
def hello(name: str = "world") -> None:
    """動作確認用コマンド。"""
    log = get_logger()
    log.info("hello", name=name, app=settings.app_name)
    typer.echo(f"Hello, {name}!")


if __name__ == "__main__":
    app()
```

### 4.9 `tests/conftest.py`

```python
from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def _isolate_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """テスト中は外部環境変数の影響を受けないようにする。"""
    for key in ["GOOGLE_API_KEY", "LANGSMITH_API_KEY"]:
        monkeypatch.delenv(key, raising=False)
```

### 4.10 `tests/test_smoke.py`

```python
from __future__ import annotations

from typer.testing import CliRunner

from {{ project_slug }}.cli import app

runner = CliRunner()


def test_hello() -> None:
    result = runner.invoke(app, ["hello", "--name", "Yuto"])
    assert result.exit_code == 0
    assert "Hello, Yuto!" in result.stdout
```

### 4.11 `.env.example`

```bash
# 動作環境
LOG_LEVEL=INFO
DEBUG=false

# LLM(extras=llm のとき)
GOOGLE_API_KEY=
LANGSMITH_API_KEY=
LANGSMITH_PROJECT=my-project
```

### 4.12 `.gitignore`

```gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python

# venv / uv
.venv/
.uv-cache/

# テスト・型・lint
.pytest_cache/
.mypy_cache/
.ruff_cache/
htmlcov/
.coverage
coverage.xml

# ビルド
dist/
build/
*.egg-info/

# 環境変数
.env
.env.local

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# LLM/データ
chroma_db/
*.sqlite
data/raw/
```

### 4.13 `.python-version`

```
3.12
```

### 4.14 `copier.yml`(テンプレート化する場合)

```yaml
_min_copier_version: "9.0"
_subdirectory: template

project_name:
  type: str
  help: "プロジェクト名(人間向け表記)"
  default: My App

project_slug:
  type: str
  help: "パッケージ名(snake_case、自動生成)"
  default: "{{ project_name | lower | replace(' ', '_') | replace('-', '_') }}"

project_description:
  type: str
  help: "プロジェクトの1行説明"
  default: A modern Python application.

author_name:
  type: str
  help: "作成者名"
  default: Yuto Fukui

python_version:
  type: str
  help: "Python バージョン"
  choices:
    - "3.11"
    - "3.12"
    - "3.13"
  default: "3.12"

include_llm_extras:
  type: bool
  default: true
  help: "LLM 関連依存(LangChain / ChromaDB / Streamlit)を含めるか"

ci_platform:
  type: str
  help: "CI/CD プラットフォーム"
  choices:
    GitLab CI: gitlab
    GitLab CI + Jenkins: gitlab_and_jenkins
    Jenkins: jenkins
    なし: none
  default: gitlab

include_docker:
  type: bool
  help: "Docker (Dockerfile) を含めるか"
  default: true

license:
  type: str
  help: "ライセンス"
  choices:
    MIT: MIT
    Apache License 2.0: Apache-2.0
    Proprietary(ライセンスファイルなし): proprietary
  default: MIT
```

### 4.15 `README.md`(テンプレート用)

```markdown
# {{ project_name }}

{{ project_description }}

## 前提

- [uv](https://docs.astral.sh/uv/) >= 0.4
- [just](https://github.com/casey/just) (任意)
- Python {{ python_version }}

## クイックスタート

```bash
# 依存インストール
just setup
# または
uv sync --all-extras
uv run pre-commit install

# 動作確認
uv run {{ project_slug }} hello --name Yuto
```

## 開発コマンド

| 用途 | コマンド |
|---|---|
| Lint | `just lint` |
| Format | `just fmt` |
| 型チェック | `just typecheck` |
| テスト | `just test` |
| CI 相当 | `just ci` |

## ディレクトリ

- `src/{{ project_slug }}/` — アプリケーションコード
- `tests/` — テスト
- `docs/` — ドキュメント

## ライセンス

MIT
```

---

## 5. Claude Code への指示事項

このセクションは Claude Code が実装時に従うべき方針です。

### 5.1 必ず守ること
1. **すべてのファイルを上記仕様通りに作成する**
2. **`uv` を必ず使う**(pip / pipenv / poetry を使わない)
3. **`src/` レイアウトを守る**
4. **`pyproject.toml` に全設定を集約**(setup.py / setup.cfg / requirements.txt は作らない)
5. **依存バージョンは下限指定(`>=`)で固定しない**(uv.lock で固定する)
6. **テンプレート変数(`{{ project_slug }}` など)は copier 形式を使う**
7. **生成後に `uv sync --all-extras` が成功することを確認**
8. **生成後に `uv run pytest` が成功することを確認**
9. **生成後に `uv run ruff check .` がエラー 0 件で通ることを確認**
10. **生成後に `uv run mypy src tests` がエラー 0 件で通ることを確認**

### 5.2 推奨ワークフロー
1. リポジトリのスケルトンを作成
2. `pyproject.toml` を最初に書く
3. `uv sync --all-extras` でロックファイル生成
4. `src/` 配下のコードを書く
5. `tests/` を書く
6. CI / Docker を整備
7. `pre-commit` を導入
8. README / docs を整備
9. 最終的に `just ci` がローカルで通ることを確認

### 5.3 オプション機能(ユーザーに確認すべき項目)
- LangChain / ChromaDB / Streamlit を含めるか
- CI は GitLab CI / Jenkins / 両方 / なし
- ライセンスは MIT / Apache-2.0 / Proprietary
- Docker (Dockerfile) を含めるか
- `copier.yml` を含めて完全テンプレート化するか、それとも単なる雛形リポジトリにするか

### 5.4 動作確認スクリプト

最後に以下を実行して全体が動くことを確認してください。

```bash
# 1. 依存インストール
uv sync --all-extras

# 2. pre-commit セットアップ
uv run pre-commit install

# 3. Lint / Format チェック
uv run ruff check .
uv run ruff format --check .

# 4. 型チェック
uv run mypy src tests

# 5. テスト
uv run pytest

# 6. CLI 動作確認
uv run {{ project_slug }} hello --name test

# 7. Docker ビルド(任意)
docker build -t {{ project_slug }}:test .
```

---

## 6. 移行時の注意事項(社内既存資産との関係)

| 既存ツール | 置換先 | 移行方法 |
|---|---|---|
| pyenv | uv | `uv python install 3.12` で代替 |
| pipenv | uv | `Pipfile` を `pyproject.toml` に変換、`Pipfile.lock` は破棄して `uv lock` で再生成 |
| cookiecutter | copier | テンプレート構文が似ているため移植容易。生成後の `copier update` が新たに使える |
| flake8 / black / isort | ruff | `.flake8` / `pyproject.toml [tool.black]` / `.isort.cfg` を `pyproject.toml [tool.ruff]` に統合 |
| Makefile | justfile | 構文がほぼ同じ。タブ依存がなくなる |
| Jenkins 単体 | GitLab CI + Jenkins 連携 | Jenkinsfile のステージを `.gitlab-ci.yml` の job に変換。Self-hosted Runner で同等の実行環境を構築可能 |

---

## 7. 参考リンク

- uv: https://docs.astral.sh/uv/
- ruff: https://docs.astral.sh/ruff/
- copier: https://copier.readthedocs.io/
- just: https://github.com/casey/just
- Pydantic v2: https://docs.pydantic.dev/
- structlog: https://www.structlog.org/

---

以上の仕様に基づき、`python-ai-template` リポジトリを生成してください。
