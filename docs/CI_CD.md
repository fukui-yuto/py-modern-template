# CI/CD パイプラインガイド

CI/CD プラットフォーム（GitLab CI / Jenkins）の設定と使い方を説明します。

---

## パイプライン構成パターン

copier の `ci_platform` 選択肢に応じて、パイプライン構成が変わります:

| 選択肢 | GitLab CI の役割 | Jenkins の役割 |
|---|---|---|
| `gitlab` | Lint + Test + Build | (なし) |
| `gitlab_and_jenkins` | Lint + Test + Docker Build + Registry Push | Image Pull + Deploy |
| `jenkins` | (なし) | Lint + Test (フル CI) |

### GitLab CI + Jenkins 連携時のフロー

```
git push
  → GitLab CI
    ├── lint:ruff (ruff check + format)
    ├── lint:mypy (型チェック)
    ├── test:pytest (テスト)
    └── build:docker (Docker Build → Registry Push)
                          ↓
                    GitLab Container Registry
                          ↓
                  Jenkins (Deploy Pipeline)
                    ├── Pull Image
                    ├── Deploy (コンテナ起動)
                    └── Smoke Test
```

---

## 1. GitLab CI

### 設定ファイル

`.gitlab-ci.yml`

### ステージ

```
lint ──→ test ──→ build
 │                  │
 ├── lint:ruff      └── build:docker (Docker イメージ)
 └── lint:mypy          または build:package (Python パッケージ)
```

### Docker イメージのビルド (Docker 選択時)

`include_docker: Yes` の場合、`build` ステージで Docker イメージをビルドし、GitLab Container Registry に push します:

```yaml
build:docker:
  stage: build
  image: docker:27
  services:
    - docker:27-dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
    - docker push $CI_REGISTRY_IMAGE:latest
  only:
    - main
    - tags
```

**GitLab CI の変数 (自動提供):**

| 変数 | 内容 | 例 |
|---|---|---|
| `$CI_REGISTRY` | レジストリ URL | `registry.gitlab.com` |
| `$CI_REGISTRY_IMAGE` | イメージパス | `registry.gitlab.com/group/project` |
| `$CI_REGISTRY_USER` | レジストリユーザー | `gitlab-ci-token` |
| `$CI_REGISTRY_PASSWORD` | レジストリパスワード | (自動) |
| `$CI_COMMIT_SHORT_SHA` | コミットハッシュ(短縮) | `a1b2c3d4` |

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

## 2. Jenkins

`ci_platform` の選択により、Jenkins の役割が異なります。

### パターン A: `gitlab_and_jenkins` — デプロイパイプライン

GitLab CI がビルドした Docker イメージを使ってデプロイします。

```
Pull Image ──→ Deploy ──→ Smoke Test
```

**Jenkins 側で必要な設定:**

| 設定 | 内容 |
|---|---|
| GitLab Registry Credentials | Jenkins → Credentials に GitLab のアクセストークンを登録 |
| 環境変数 `REGISTRY_URL` | GitLab Container Registry の URL |
| 環境変数 `IMAGE_NAME` | イメージ名 (GitLab のプロジェクトパス) |
| `.env` ファイル | デプロイ先に配置 |

### パターン B: `jenkins` — フル CI パイプライン

Jenkins 単体で lint/test を実行します (GitLab CI は使わない):

```
Install ──→ Lint（並列）──→ TypeCheck ──→ Test
              │
              ├── ruff check
              └── ruff format
```

Lint ステージは `parallel` で 2 つのジョブを同時実行（高速化）。

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

## 用語: `--frozen` フラグとは

CI 設定ファイル（`.gitlab-ci.yml`、`jenkins` モードの `Jenkinsfile`）では `uv sync --frozen` を使用しています。
`gitlab_and_jenkins` モードの `Jenkinsfile` はデプロイ専用のため `uv` は使用しません。

```bash
# ローカル（開発中）
uv sync --all-extras          # uv.lock が古ければ自動更新する

# CI（自動テスト）
uv sync --all-extras --frozen  # uv.lock を更新しない。古ければエラーにする
```

**なぜ CI では `--frozen` を使うのか？**

- CI 環境で勝手にバージョンが変わると、テスト結果が不安定になる
- `uv.lock` の更新は開発者がローカルで意図的に行うべき
- `--frozen` を付けることで「lock ファイルと実際の依存が一致していなければ失敗」として検出できる

---

## テスト用 CI/CD インフラ

GitLab / Jenkins がない環境でも、Docker Compose でローカルに構築できます。
詳細は [INFRA_SETUP.md](INFRA_SETUP.md) を参照してください。

```bash
# 起動（テンプレートリポジトリのルートで実行）
docker compose -f docker-compose.infra.yml up -d

# 停止
docker compose -f docker-compose.infra.yml down
```
