# ユーザーガイド（初心者向け）

Python 開発やこのテンプレートが初めての方向けの、ゼロからの操作ガイドです。

---

## このテンプレートとは？

Python で新しいプロジェクトを始めるとき、毎回同じ作業が発生します:

- フォルダ構成を考える
- Lint / フォーマッターを設定する
- テストの仕組みを入れる
- CI/CD を設定する
- Docker を書く

**このテンプレートは、それらをすべて設定済みの状態で提供します。**
あなたはビジネスロジック（=やりたいこと）の実装に集中できます。

---

## 前提知識

| 用語 | 説明 |
|---|---|
| **uv** | Python のバージョン管理・パッケージ管理・仮想環境を 1 つで行うツール。pyenv + pipenv の代わり |
| **ruff** | コードの書き方チェック（Lint）と自動整形（Format）を行うツール。flake8 + black + isort の代わり |
| **mypy** | 型の間違いを見つけるツール。実行前にバグを発見できる |
| **pytest** | テストを実行するツール |
| **just** | コマンドを短く書けるようにするツール。Makefile の代わり |
| **pre-commit** | git commit 時に自動でチェックを走らせる仕組み |

---

## Step 0: ツールのインストール

### uv のインストール

```bash
# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Mac / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

インストール確認:

```bash
uv version
# => uv 0.x.x
```

### just のインストール（任意だが推奨）

```bash
# Windows (PowerShell)
winget install Casey.Just

# Mac
brew install just

# Linux
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
```

---

## Step 1: プロジェクトのセットアップ

```bash
# リポジトリを clone
git clone <このリポジトリのURL> my-project
cd my-project

# セットアップ（どちらか1つ実行）
bash scripts/bootstrap.sh    # 自動セットアップ（推奨）
# または
just setup                    # just がインストール済みの場合
```

**何が起きるか:**

1. Python 3.12 がインストールされる（なければ）
2. `.venv/` に仮想環境が作成される
3. 全依存パッケージがインストールされる
4. pre-commit フックが設定される
5. `.env` ファイルが作成される

---

## Step 2: 動作確認

```bash
uv run py_modern_template hello --name あなたの名前
```

出力例:

```
2026-04-29T12:00:00+09:00 [info     ] hello    app=py_modern_template name=あなたの名前
Hello, あなたの名前!
```

---

## Step 3: コードを書く

### ファイルの追加場所

```
src/py_modern_template/    ← ここにコードを書く
├── __init__.py            （触らない）
├── cli.py                 ← コマンドを追加するならここ
├── config.py              ← 環境変数を追加するならここ
├── logging.py             （触らない）
└── my_module.py           ← 新しいモジュールをここに作成
```

### 例: 新しいモジュールを追加

1. ファイルを作成:

```python
# src/py_modern_template/calculator.py
from __future__ import annotations


def add(a: int, b: int) -> int:
    """2つの数を足す。"""
    return a + b
```

2. テストを作成:

```python
# tests/test_calculator.py
from __future__ import annotations

from py_modern_template.calculator import add


def test_add() -> None:
    assert add(1, 2) == 3
    assert add(-1, 1) == 0
```

3. テストを実行:

```bash
just test
# または
uv run pytest tests/test_calculator.py
```

---

## Step 4: 品質チェック

### コマンド一覧

```bash
just            # 使えるコマンドの一覧を表示

just fmt        # コードを自動整形（保存し忘れても大丈夫）
just lint       # コードの書き方をチェック
just typecheck  # 型の間違いをチェック
just test       # テストを実行
just ci         # 上の3つを全部まとめて実行
```

### 各コマンドの詳細

#### `just fmt` — 自動整形

実行前:

```python
import os
import sys
from pathlib import Path
x=1
y =  2
```

実行後（自動修正される）:

```python
import os
import sys
from pathlib import Path

x = 1
y = 2
```

#### `just lint` — Lint チェック

問題があるとエラーが表示される:

```
src/py_modern_template/example.py:5:1: F841 Local variable `x` is assigned to but never used
Found 1 error.
```

#### `just typecheck` — 型チェック

型の間違いを検出:

```
src/py_modern_template/example.py:10: error: Argument 1 to "add" has incompatible type "str"; expected "int"
```

#### `just test` — テスト

```
tests/test_smoke.py::test_hello_default PASSED
tests/test_smoke.py::test_hello_with_name PASSED
tests/test_smoke.py::test_version PASSED

---------- coverage: 85% ----------
```

---

## Step 5: コミット

```bash
git add .
git commit -m "feat: add calculator module"
```

**コミット時に pre-commit が自動実行されます:**

```
ruff.....................................................................Passed
ruff-format..............................................................Passed
trailing whitespace......................................................Passed
fix end of files.........................................................Passed
check yaml...............................................................Passed
```

全部 `Passed` になればコミット成功。`Failed` があれば自動修正されるので、再度 `git add . && git commit` してください。

---

## Step 6: Push

```bash
git push origin main
```

Push すると CI（GitHub Actions / GitLab CI / Jenkins）が自動で品質チェックを実行します。

---

## よくある操作

### パッケージを追加したい

```bash
just add requests          # requests を追加
just add-dev httpx         # 開発用パッケージを追加
```

### 環境変数を使いたい

1. `.env` ファイルに書く:

```bash
MY_API_KEY=sk-xxxxx
```

2. `config.py` にフィールドを追加:

```python
class Settings(BaseSettings):
    my_api_key: str | None = Field(default=None)
```

3. コード内で使う:

```python
from py_modern_template.config import settings
print(settings.my_api_key)  # => "sk-xxxxx"
```

### ログを出したい

```python
from py_modern_template.logging import get_logger

log = get_logger()
log.info("処理開始", user="Yuto", count=42)
# => 2026-04-29T12:00:00+09:00 [info] 処理開始    user=Yuto count=42
```

### CLI コマンドを追加したい

`cli.py` に追加:

```python
@app.command()
def greet(name: str = typer.Argument("world")) -> None:
    """挨拶する。"""
    typer.echo(f"こんにちは、{name}さん！")
```

実行:

```bash
uv run py_modern_template greet Yuto
# => こんにちは、Yutoさん！
```

---

## トラブルシューティング

### `uv: command not found`

uv がインストールされていません。Step 0 を参照してください。

### `just: command not found`

just がインストールされていません。`uv run` を直接使えば just なしでも開発できます:

```bash
uv run ruff check .     # = just lint
uv run ruff format .    # = just fmt
uv run mypy src tests   # = just typecheck
uv run pytest           # = just test
```

### `ModuleNotFoundError: No module named 'py_modern_template'`

依存がインストールされていません:

```bash
uv sync --all-extras
```

### pre-commit でエラーが出てコミットできない

```bash
# まず自動修正を試す
just fmt

# 修正されたファイルを再度 add
git add .
git commit -m "fix: format code"
```

### mypy で `Cannot find implementation or library stub` エラー

外部ライブラリの型スタブがない場合、`pyproject.toml` に例外を追加:

```toml
[[tool.mypy.overrides]]
module = ["外部ライブラリ名.*"]
ignore_missing_imports = true
```
