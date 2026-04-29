# 技術スタック

このプロジェクトで採用しているツール・ライブラリの詳細と、選定理由を説明します。

---

## 一覧

| レイヤー | 採用ツール | 置換対象（旧） | 選定理由 |
|---|---|---|---|
| Python 管理 | **uv** | pyenv + pipenv | 1 ツールで Python 本体・仮想環境・依存を統合。10-100 倍高速 |
| Lint / Format | **ruff** | flake8 + black + isort | 1 ツールに統合。Rust 製で超高速 |
| 型チェック | **mypy** | （なし） | 最も成熟した型チェッカー。Pydantic プラグイン対応 |
| テスト | **pytest** | unittest | デファクトスタンダード。プラグインエコシステムが豊富 |
| タスクランナー | **just** | Makefile | タブ依存なし。クロスプラットフォーム対応 |
| 設定管理 | **Pydantic Settings** | python-dotenv + dataclass | 型安全な環境変数読み込み。バリデーション付き |
| ログ | **structlog** | logging | 構造化ログ。JSON 出力対応。コンテキスト変数対応 |
| CLI | **Typer** | argparse / click | 型ヒントからコマンドを自動生成。Click ベース |
| プリコミット | **pre-commit** | （手動チェック） | コミット前に自動で品質チェック |
| コンテナ | **Docker** | （なし） | マルチステージビルドで本番イメージを最小化 |
| CI/CD | **GitHub Actions / GitLab CI / Jenkins** | Jenkins のみ | 3 プラットフォーム対応で移行容易 |

---

## 各ツールの詳細

### uv

**公式:** https://docs.astral.sh/uv/

Python エコシステムの統合ツール。Rust 製で高速。

```bash
# Python のインストール（pyenv の代わり）
uv python install 3.12

# プロジェクトの依存インストール（pipenv install の代わり）
uv sync

# パッケージ追加（pipenv install xxx の代わり）
uv add requests

# コマンド実行（pipenv run の代わり）
uv run pytest

# ロックファイル生成（pipenv lock の代わり）
uv lock
```

**従来との比較:**

| 操作 | 旧 (pyenv + pipenv) | 新 (uv) |
|---|---|---|
| Python インストール | `pyenv install 3.12` | `uv python install 3.12` |
| 仮想環境作成 | `pipenv --python 3.12` | `uv sync` で自動作成 |
| 依存追加 | `pipenv install requests` | `uv add requests` |
| 開発依存追加 | `pipenv install --dev pytest` | `uv add --dev pytest` |
| スクリプト実行 | `pipenv run python main.py` | `uv run python main.py` |
| 設定ファイル | `Pipfile` + `Pipfile.lock` | `pyproject.toml` + `uv.lock` |

---

### ruff

**公式:** https://docs.astral.sh/ruff/

Lint + フォーマットを 1 ツールで提供。Rust 製で 10-100 倍高速。

```bash
# Lint チェック
uv run ruff check .

# Lint 自動修正
uv run ruff check --fix .

# フォーマット
uv run ruff format .

# フォーマットチェック（修正なし）
uv run ruff format --check .
```

**有効にしているルール（pyproject.toml）:**

| ルール | 元ツール | 内容 |
|---|---|---|
| `E`, `W` | pycodestyle | コーディングスタイル |
| `F` | pyflakes | 未使用変数、未定義変数等 |
| `I` | isort | import 順序 |
| `B` | flake8-bugbear | よくあるバグパターン |
| `UP` | pyupgrade | 古い書き方の検出 |
| `N` | pep8-naming | 命名規則 |
| `SIM` | flake8-simplify | 簡略化可能なコード |
| `RUF` | ruff 独自 | ruff 固有のルール |

---

### mypy

**公式:** https://mypy.readthedocs.io/

静的型チェッカー。`--strict` モードで厳密にチェック。

```bash
uv run mypy src tests
```

`pyproject.toml` で有効にしている設定:

```toml
[tool.mypy]
strict = true                 # 厳密モード
disallow_untyped_defs = true  # 型なし関数を禁止
plugins = ["pydantic.mypy"]   # Pydantic 対応
```

---

### pytest

**公式:** https://docs.pytest.org/

使用しているプラグイン:

| プラグイン | 用途 |
|---|---|
| **pytest-cov** | カバレッジ計測 |
| **pytest-asyncio** | async テストのサポート |
| **pytest-recording** | HTTP リクエストの記録・再生（VCR） |

---

### Pydantic Settings

**公式:** https://docs.pydantic.dev/

環境変数を型安全に読み込む:

```python
class Settings(BaseSettings):
    log_level: str = "INFO"           # LOG_LEVEL 環境変数
    debug: bool = False               # DEBUG 環境変数
    max_retries: int = 3              # MAX_RETRIES 環境変数
    api_key: str | None = None        # API_KEY 環境変数
```

特徴:
- 環境変数名は自動的に大文字 → snake_case 変換
- 型バリデーション付き（`"abc"` を `int` に入れるとエラー）
- `.env` ファイル対応
- デフォルト値サポート

---

### structlog

**公式:** https://www.structlog.org/

構造化ログライブラリ:

```python
log = get_logger()

# 開発中（人間が読みやすい出力）
log.info("user logged in", user_id=42, ip="192.168.1.1")
# => 2026-04-29T12:00:00+09:00 [info] user logged in  user_id=42 ip=192.168.1.1

# 本番（JSON 出力に切替可能）
# => {"event": "user logged in", "user_id": 42, "ip": "192.168.1.1", "timestamp": "..."}
```

---

### Typer

**公式:** https://typer.tiangolo.com/

型ヒントから CLI を自動生成:

```python
@app.command()
def hello(name: str = "world") -> None:
    """挨拶する。"""
    typer.echo(f"Hello, {name}!")
```

```bash
$ uv run py_modern_template hello --help
Usage: py_modern_template hello [OPTIONS]

  挨拶する。

Options:
  --name TEXT  [default: world]
  --help       Show this message and exit.
```

---

## バージョン方針

- 依存バージョンは **下限指定** (`>=`) で記述
- **`uv.lock`** で実際のバージョンを固定
- ロックファイルは Git にコミットする

```toml
# pyproject.toml — 互換性のある最低バージョンを指定
dependencies = [
    "pydantic>=2.7",      # 2.7 以上ならOK
    "structlog>=24.1",    # 24.1 以上ならOK
]

# uv.lock — 実際にインストールされるバージョンを固定
# （自動生成。手動編集しない）
```
