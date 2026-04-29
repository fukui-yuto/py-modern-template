# CI/CD パイプラインガイド

3 つの CI/CD プラットフォーム（GitHub Actions / GitLab CI / Jenkins）の設定と使い方を説明します。

---

## パイプライン概要

どのプラットフォームでも同じステップを実行します:

```
Install ──→ Lint ──→ TypeCheck ──→ Test
              │
              ├── ruff check（コード品質）
              └── ruff format（フォーマット確認）
```

---

## 1. GitHub Actions

### 設定ファイル

- `.github/workflows/ci.yml` — PR / push 時の CI
- `.github/workflows/release.yml` — タグ push 時のリリース

### トリガー

| イベント | 対象ブランチ | 実行内容 |
|---|---|---|
| `push` | `main` | CI（Lint + TypeCheck + Test） |
| `pull_request` | `main` | CI（Lint + TypeCheck + Test） |
| `push` (tag `v*`) | — | リリース（CI + ビルド + GitHub Release 作成） |

### マトリックスビルド

Python 3.11 / 3.12 / 3.13 の 3 バージョンで並列テスト:

```yaml
strategy:
  matrix:
    python-version: ["3.11", "3.12", "3.13"]
```

### 使い方

1. GitHub にリポジトリを作成して push するだけ
2. **Actions** タブで実行結果を確認

### リリース

```bash
git tag v0.1.0
git push origin v0.1.0
# → release.yml が起動 → GitHub Release が自動作成される
```

---

## 2. GitLab CI

### 設定ファイル

`.gitlab-ci.yml`

### ステージ

```
lint ──→ test ──→ build
 │
 ├── lint:ruff（ruff check + format）
 └── lint:mypy（型チェック）
```

### キャッシュ

uv のキャッシュと `.venv/` をジョブ間で共有:

```yaml
cache:
  key: uv-${PYTHON_VERSION}
  paths:
    - .uv-cache/
    - .venv/
```

### アーティファクト

- `report.xml` — JUnit テストレポート（GitLab のテスト結果タブに表示）
- `coverage.xml` — カバレッジレポート（マージリクエストにカバレッジ表示）

### 使い方

1. GitLab にリポジトリを作成
2. Runner が登録されていることを確認
3. push すると自動で CI が実行される

---

## 3. Jenkins

### 設定ファイル

`Jenkinsfile`

### パイプライン構成

```
Install ──→ Lint（並列）──→ TypeCheck ──→ Test
              │
              ├── ruff check
              └── ruff format
```

Lint ステージは `parallel` で 2 つのジョブを同時実行（高速化）。

### Docker Agent

```groovy
agent {
    docker {
        image 'ghcr.io/astral-sh/uv:python3.12-bookworm-slim'
    }
}
```

Jenkins 側に Docker がインストールされていれば、ビルドエージェントとして uv 公式イメージを使用。

### ジョブの作成方法

#### 方法 A: GUI で作成

1. **New Item** → Pipeline → OK
2. Pipeline Definition: **Pipeline script from SCM**
3. SCM: Git / Repository URL を設定
4. Script Path: `Jenkinsfile`
5. Save → Build Now

#### 方法 B: スクリプトで作成

```bash
export JENKINS_URL=http://localhost:8080
export JENKINS_USER=admin
export JENKINS_TOKEN=<APIトークン>

bash scripts/create-jenkins-job.sh my-app http://gitlab:80/root/my-app.git
```

### Jenkins API トークンの取得

1. Jenkins → 右上ユーザー名 → **Configure**
2. **API Token** → **Add new Token**
3. Generate → トークンを控える

---

## ローカルで CI と同じチェックを実行

```bash
just ci
```

これは以下と同等:

```bash
uv run ruff check .
uv run ruff format --check .
uv run mypy src tests
uv run pytest
```

**CI で失敗する前にローカルで確認する習慣をつけましょう。**

---

## テスト用 CI/CD インフラ

GitLab / Jenkins がない環境でも、Docker Compose でローカルに構築できます。
詳細は [INFRA_SETUP.md](INFRA_SETUP.md) を参照してください。

```bash
# 起動
just infra-up

# 停止
just infra-down
```
