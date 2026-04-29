# 開発ガイド

日常の開発フローとルールをまとめたガイドです。

---

## 日常の開発フロー

### 1. ブランチを切る

```bash
git checkout -b feature/add-rag-pipeline
```

### 2. コードを書く

`src/py_modern_template/` 配下にモジュールを追加:

```bash
# 例: RAG パイプラインモジュールを追加
touch src/py_modern_template/rag.py
```

### 3. テストを書く

```bash
# 対応するテストファイルを作成
touch tests/test_rag.py
```

テストの書き方:

```python
from __future__ import annotations

def test_rag_pipeline() -> None:
    """RAG パイプラインの基本動作テスト。"""
    # Arrange
    query = "Python のテンプレートとは？"

    # Act
    result = search(query)

    # Assert
    assert result is not None
    assert len(result) > 0
```

### 4. ローカルで品質チェック

```bash
# フォーマット
just fmt

# CI と同じチェックを一括実行
just ci
```

### 5. コミット

```bash
git add .
git commit -m "feat: add RAG pipeline"
```

`git commit` すると pre-commit が自動実行:
- ruff check（Lint）
- ruff format（フォーマット）
- trailing-whitespace（末尾空白除去）
- end-of-file-fixer（最終行改行）
- check-yaml（YAML 構文チェック）
- mypy（型チェック）

### 6. Push & マージリクエスト

```bash
git push origin feature/add-rag-pipeline
```

CI が自動実行され、全チェックが通ればマージ可能。

---

## 依存パッケージの管理

### 追加

```bash
# 本番依存
just add requests
just add boto3

# 開発依存
just add-dev httpx
just add-dev factory-boy

# LLM 関連（pyproject.toml の [project.optional-dependencies] llm に手動追加）
```

### 削除

```bash
uv remove requests
```

### ロックファイルの更新

```bash
uv lock
```

> **重要:** `uv.lock` は必ず Git にコミットしてください。チーム全員が同じバージョンの依存を使うために必要です。

---

## テスト

### 基本コマンド

```bash
# 全テスト実行
just test

# 特定のテストファイル
uv run pytest tests/test_smoke.py

# 特定のテスト関数
uv run pytest tests/test_smoke.py::test_hello_with_name

# 詳細出力
uv run pytest -v

# 失敗したテストのみ再実行
uv run pytest --lf

# デバッグ出力を表示
uv run pytest -s
```

### カバレッジ

```bash
# テスト実行時にカバレッジが自動計測される（pyproject.toml で設定済み）
just test

# HTML レポートを生成
uv run pytest --cov-report=html
# → htmlcov/index.html をブラウザで開く
```

### テストの配置ルール

```
tests/
├── __init__.py
├── conftest.py          # 共有フィクスチャ
├── test_smoke.py        # スモークテスト（基本動作確認）
├── test_config.py       # config.py のテスト
├── test_rag.py          # rag.py のテスト
└── integration/         # 統合テスト（外部サービスが必要なもの）
    └── test_llm.py
```

---

## Lint & フォーマット

### 自動フォーマット

```bash
just fmt
```

これで以下が実行される:
1. `ruff format .` — コードフォーマット（black 互換）
2. `ruff check --fix .` — 自動修正可能な Lint エラーを修正

### Lint チェック（修正なし）

```bash
just lint
```

### VSCode での自動フォーマット

`.vscode/settings.json` で設定済み:
- **保存時に自動フォーマット**
- **保存時に import 自動整理**

---

## 型チェック

```bash
just typecheck
```

### 型アノテーションのルール

このプロジェクトでは `mypy --strict` を使用:

```python
# OK: 型アノテーションあり
def greet(name: str) -> str:
    return f"Hello, {name}!"

# NG: 型アノテーションなし（mypy がエラーを出す）
def greet(name):
    return f"Hello, {name}!"
```

### `from __future__ import annotations` について

全ファイルの先頭に書いてください:

```python
from __future__ import annotations
```

これにより `str | None` のような新しい型構文が Python 3.11 でも使えます。

---

## CLI コマンドの追加方法

`src/py_modern_template/cli.py` にコマンドを追加:

```python
@app.command()
def my_new_command(
    input_file: str = typer.Argument(..., help="入力ファイルパス"),
    verbose: bool = typer.Option(False, "--verbose", "-v", help="詳細出力"),
) -> None:
    """新しいコマンドの説明。"""
    log = get_logger()
    log.info("processing", file=input_file)
    # ... ロジック ...
```

実行:

```bash
uv run py_modern_template my-new-command input.txt --verbose
# または
just run my-new-command input.txt --verbose
```

---

## 環境変数の追加方法

### 1. `config.py` にフィールドを追加

```python
class Settings(BaseSettings):
    # ... 既存のフィールド ...
    my_api_key: str | None = Field(default=None)
    max_retries: int = Field(default=3)
```

### 2. `.env.example` に追記

```bash
MY_API_KEY=
MAX_RETRIES=3
```

### 3. コード内で使う

```python
from py_modern_template.config import settings

print(settings.my_api_key)
print(settings.max_retries)
```

Pydantic が自動的に環境変数 `MY_API_KEY` → `settings.my_api_key` に変換します。

---

## Git コミットメッセージ規約

[Conventional Commits](https://www.conventionalcommits.org/) を推奨:

```
feat: 新機能を追加
fix: バグ修正
docs: ドキュメントのみの変更
style: コードの意味に影響しない変更（空白、フォーマット等）
refactor: バグ修正でも新機能でもないコード変更
test: テストの追加・修正
chore: ビルドプロセスやツールの変更
ci: CI 設定の変更
```

例:

```bash
git commit -m "feat: add RAG pipeline with ChromaDB"
git commit -m "fix: handle empty query in search"
git commit -m "docs: update API reference"
```
