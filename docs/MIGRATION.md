# 移行ガイド

社内既存の `pyenv + pipenv + cookiecutter + GitLab CI → Jenkins` 構成からの移行手順です。

---

## 移行マップ

```
旧構成                              新構成
──────────────────────────────────────────────────
pyenv                          ──→  uv
pipenv (Pipfile / Pipfile.lock)──→  uv (pyproject.toml / uv.lock)
flake8 (.flake8)               ──→  ruff [tool.ruff] in pyproject.toml
black (pyproject.toml)         ──→  ruff [tool.ruff.format]
isort (.isort.cfg)             ──→  ruff [tool.ruff.lint] select = ["I"]
cookiecutter                   ──→  copier（またはこのテンプレートを直接利用）
Makefile                       ──→  justfile
Jenkins (Jenkinsfile)          ──→  Jenkinsfile（uv ベースに更新）
requirements.txt               ──→  pyproject.toml [project.dependencies]
setup.py / setup.cfg           ──→  pyproject.toml [build-system]
```

---

## 1. pyenv → uv

### Before

```bash
pyenv install 3.12.0
pyenv local 3.12.0
```

### After

```bash
uv python install 3.12
# .python-version ファイルで自動的に使用される
```

### 移行手順

1. `.python-version` はそのまま使える（uv も読む）
2. `~/.pyenv` は削除しなくてもよい（共存可能）
3. 新プロジェクトでは uv のみを使う

---

## 2. pipenv → uv

### Before

```bash
pipenv install requests
pipenv install --dev pytest
pipenv run pytest
pipenv lock
```

### After

```bash
uv add requests
uv add --dev pytest
uv run pytest
uv lock
```

### Pipfile → pyproject.toml の変換

**Before (Pipfile):**

```toml
[[source]]
url = "https://pypi.org/simple"

[packages]
requests = "*"
pydantic = ">=2.0"

[dev-packages]
pytest = "*"
black = "*"

[requires]
python_version = "3.12"
```

**After (pyproject.toml):**

```toml
[project]
requires-python = ">=3.12"
dependencies = [
    "requests",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev = [
    "pytest",
    "ruff",        # black の代わり
]
```

### 移行手順

1. `Pipfile` の `[packages]` → `pyproject.toml` の `[project.dependencies]`
2. `Pipfile` の `[dev-packages]` → `pyproject.toml` の `[project.optional-dependencies] dev`
3. `Pipfile.lock` を削除
4. `uv lock` で `uv.lock` を生成
5. `uv sync --all-extras` で動作確認

---

## 3. flake8 + black + isort → ruff

### Before

```
.flake8
pyproject.toml [tool.black]
.isort.cfg
```

3 つのツール、3 つの設定ファイル。

### After

```toml
# pyproject.toml に全集約
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "UP", "N", "SIM", "RUF"]

[tool.ruff.format]
quote-style = "double"
```

1 つのツール、1 つのファイル。

### 移行手順

1. `.flake8` のルールを `[tool.ruff.lint]` に変換
2. `[tool.black]` を `[tool.ruff.format]` に変換
3. `.isort.cfg` を削除（`select = ["I"]` で isort が有効）
4. flake8 / black / isort をアンインストール
5. ruff をインストール: `uv add --dev ruff`
6. `uv run ruff check .` で確認

---

## 4. Makefile → justfile

### Before (Makefile)

```makefile
.PHONY: lint test

lint:
	flake8 .
	black --check .

test:
	pytest
```

### After (justfile)

```just
lint:
    uv run ruff check .
    uv run ruff format --check .

test:
    uv run pytest
```

**違い:**
- タブが必須 → スペースでも OK
- `.PHONY` 不要
- 変数構文がシンプル

### 移行手順

1. `Makefile` の各ターゲットを `justfile` にコピー
2. コマンドを新ツール名に変更
3. `make xxx` → `just xxx` に変更

---

## 5. cookiecutter → copier（またはこのテンプレートを直接利用）

### 直接利用する場合（推奨）

```bash
git clone <このリポジトリ> my-new-project
cd my-new-project
rm -rf .git
git init

# プロジェクト名をリネーム
# src/py_modern_template/ → src/my_project/
# pyproject.toml の name / scripts を変更
# 各ファイル内の py_modern_template → my_project に置換
```

### copier を使う場合

テンプレートを copier 対応させた場合:

```bash
copier copy gh:owner/py-modern-template ./my-project
# 対話式で質問に答える
```

---

## 6. Jenkins の更新

### Before (Jenkinsfile)

```groovy
pipeline {
    agent any
    stages {
        stage('Install') {
            steps {
                sh 'pipenv install --dev'
            }
        }
        stage('Lint') {
            steps {
                sh 'pipenv run flake8 .'
                sh 'pipenv run black --check .'
            }
        }
        stage('Test') {
            steps {
                sh 'pipenv run pytest'
            }
        }
    }
}
```

### After (Jenkinsfile)

```groovy
pipeline {
    agent {
        docker {
            image 'ghcr.io/astral-sh/uv:python3.12-bookworm-slim'
        }
    }
    stages {
        stage('Install') {
            steps { sh 'uv sync --all-extras --dev --frozen' }
        }
        stage('Lint') {
            parallel {
                stage('ruff check') { steps { sh 'uv run ruff check .' } }
                stage('ruff format') { steps { sh 'uv run ruff format --check .' } }
            }
        }
        stage('Type Check') {
            steps { sh 'uv run mypy src tests' }
        }
        stage('Test') {
            steps { sh 'uv run pytest --junitxml=report.xml' }
            post { always { junit 'report.xml' } }
        }
    }
}
```

**変更点:**
- Docker agent で uv 公式イメージを使用（Jenkins に Python 不要）
- `pipenv` → `uv`
- `flake8` + `black` → `ruff`
- `mypy` を追加
- Lint を `parallel` で並列実行

---

## 7. requirements.txt / setup.py の廃止

### Before

```
requirements.txt
requirements-dev.txt
setup.py
setup.cfg
```

### After

```
pyproject.toml    ← すべてここに統合
uv.lock           ← requirements.txt の代わり（自動生成）
```

### 移行手順

1. `requirements.txt` の内容 → `[project.dependencies]`
2. `requirements-dev.txt` の内容 → `[project.optional-dependencies] dev`
3. `setup.py` / `setup.cfg` → `[project]` + `[build-system]`
4. 旧ファイルを削除
5. `uv lock` → `uv sync` で確認

---

## チェックリスト

移行時に確認すべき項目:

- [ ] `pyproject.toml` にすべての依存と設定を記述した
- [ ] `uv sync --all-extras` が成功する
- [ ] `uv run ruff check .` がエラー 0 件で通る
- [ ] `uv run ruff format --check .` が差分 0 件で通る
- [ ] `uv run mypy src tests` がエラー 0 件で通る
- [ ] `uv run pytest` が全テストパスする
- [ ] `uv run py_modern_template hello` が動作する
- [ ] `just ci` がローカルで通る
- [ ] 旧ファイル（Pipfile, .flake8, setup.py 等）を削除した
- [ ] CI/CD パイプラインを新 Jenkinsfile / ci.yml に更新した
- [ ] README を更新した
