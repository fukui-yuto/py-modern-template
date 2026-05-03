# テスト用 CI/CD インフラ セットアップガイド

Jenkins と GitLab をローカルの Docker Compose で立ち上げ、テンプレートの CI パイプラインを検証するための手順書。

---

## アカウント情報

| サービス | URL | ユーザー名 | パスワード |
|---|---|---|---|
| GitLab | http://localhost:8929 | `root` | `P@ssw0rd1234` |
| Jenkins | http://localhost:8080 | `admin` | `admin` |

> **注意:** これらはローカルテスト専用の認証情報です。外部に公開するサーバーでは絶対に使用しないでください。

---

## 前提条件

- Docker Desktop がインストール済み
- Docker Compose v2 が使える (`docker compose version`)
- メモリ: 最低 **8GB** を Docker に割り当て（GitLab が重い）
- ポート `8080` (Jenkins)、`8929` (GitLab)、`2224` (GitLab SSH) が空いていること

---

## 1. 起動

```bash
docker compose -f docker-compose.infra.yml up -d
```

初回は GitLab の起動に **3〜5 分** かかる。ログで進捗を確認:

```bash
docker compose -f docker-compose.infra.yml logs -f gitlab
```

ヘルスチェックが通るまで待つ:

```bash
docker compose -f docker-compose.infra.yml ps
# gitlab の STATUS が "healthy" になるまで待機
```

---

## 2. 自動 E2E 検証

インフラが起動したら、以下のコマンドで**テンプレートの CI/CD パイプラインを自動検証**できます:

```bash
bash scripts/verify-ci.sh
```

このスクリプトは以下を自動で行います:

1. GitLab にテスト用プロジェクト（`gitlab_and_jenkins` モード）を作成
2. copier でプロジェクトを生成し、GitLab に push（ローカル用に `.gitlab-ci.yml` を自動パッチ）
3. GitLab Runner を登録（既存ランナーは自動削除）
4. GitLab CI パイプラインの完了を待機し、結果を確認（`build:docker` 含む全ステージ）
5. `deploy:jenkins-sync` が Jenkins ジョブを自動作成したことを確認
6. テスト用プロジェクト・Jenkins ジョブを自動クリーンアップ

最終出力が `ALL CHECKS PASSED` になれば、テンプレートの CI/CD は正常に動作しています。

> **補足:** 検証スクリプトはローカルの HTTP レジストリに対応するため、`build:docker` ステージの dind 設定を自動パッチします（`--insecure-registry` の追加、TLS の無効化）。テンプレート本体は本番環境（HTTPS レジストリ）向けの設定になっています。

---

## 3. CI/CD パイプラインの仕組み

### 3.1 CI モードの種類

テンプレート生成時に選択する `ci_platform` によって、パイプラインの構成が変わります:

| モード | GitLab CI | Jenkins | 説明 |
|---|---|---|---|
| `gitlab` | lint + test + build | なし | GitLab CI のみで完結 |
| `jenkins` | なし | lint + test | Jenkins のみで完結 |
| `gitlab_and_jenkins` | lint + test + build + **jenkins-sync** | deploy (Pull + Run) | GitLab CI がテスト＆ビルド＆ジョブ同期し、Jenkins がデプロイ |

### 3.2 ステージの実行順序

GitLab CI のステージは以下の順序で実行されます。**各ステージは前のステージが全て成功した場合のみ実行**されます:

```
lint (ruff, mypy) → test (pytest) → build (docker) → deploy (jenkins-sync)
```

`build:docker` が失敗すると `deploy:jenkins-sync` はスキップされます。

### 3.3 Jenkins ジョブの自動同期 (`gitlab_and_jenkins` モード)

`gitlab_and_jenkins` モードでは、GitLab CI パイプラインの `deploy:jenkins-sync` ステージが **main ブランチへの push 時に Jenkins ジョブを自動作成/更新** します。

- ジョブが存在しない → 新規作成
- ジョブが既に存在する → 設定を更新

この機能には以下の **GitLab CI/CD 変数** が必要です:

| 変数名 | 説明 | 例 |
|---|---|---|
| `JENKINS_URL` | Jenkins サーバーの URL | `http://jenkins:8080` |
| `JENKINS_USER` | Jenkins のユーザー名 | `admin` |
| `JENKINS_TOKEN` | Jenkins の API トークン | `admin` または API トークン |

**設定方法:**

GitLab プロジェクト → **Settings** → **CI/CD** → **Variables** → **Add variable** で上記 3 つを追加してください。

---

## 4. GitLab の初期設定（手動構築する場合）

> 自動検証スクリプト (`verify-ci.sh`) を使う場合はこのセクションは不要です。

### 4.1 ログイン

- URL: http://localhost:8929
- ユーザー: `root`
- パスワード: `P@ssw0rd1234`

### 4.2 アクセストークンの作成

1. 右上のアバター → **Edit profile** → **Access Tokens**
2. 以下で作成:
   - Token name: `local-test`
   - Scopes: `api`, `read_repository`, `write_repository`
   - Expiration: 任意
3. 生成されたトークンを控える（以降 `GITLAB_TOKEN` と呼ぶ）

### 4.3 テスト用リポジトリの作成

```bash
curl -s --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  -X POST "http://localhost:8929/api/v4/projects" \
  --form "name=my-test-app" \
  --form "visibility=internal" | python -m json.tool
```

### 4.4 テンプレートから生成したコードを push

```bash
cd my-test-app
git init
git remote add origin http://localhost:8929/root/my-test-app.git
git add -A
git commit -m "init: project from template"
git push -u origin main
# ユーザー: root / パスワード: GITLAB_TOKEN を入力
```

### 4.5 GitLab Runner の登録

1. GitLab Web UI → **Admin Area** (左下の歯車) → **CI/CD** → **Runners**
2. **New instance runner** → タグなしで作成 → 表示される **registration token** を控える
3. Runner コンテナ内で登録:

```bash
docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://gitlab:80" \
  --token "<上で取得したトークン>" \
  --executor "docker" \
  --docker-image "ghcr.io/astral-sh/uv:python3.12-bookworm-slim" \
  --docker-network-mode "py-modern-template_ci-net" \
  --docker-privileged \
  --description "local-docker-runner"
```

> **注意:**
> - `--url` はコンテナ間通信なので `http://gitlab:80`（サービス名）を指定する
> - `--docker-privileged` は Docker-in-Docker (dind) で必須
> - `--docker-volumes` に docker.sock を **指定しない**（dind と競合するため）

---

## 5. Jenkins の初期設定

### 5.1 ログイン

- URL: http://localhost:8080
- ユーザー: `admin`
- パスワード: `admin`

> **注意:** カスタムイメージ (`infra/jenkins/`) によりセットアップウィザードのスキップ、プラグインのインストール、管理者ユーザーの作成が自動で行われます。

### 5.2 プリインストール済みプラグイン

| プラグイン | 用途 |
|---|---|
| **Git** | Git リポジトリ連携 |
| **Pipeline** (workflow-aggregator) | Jenkinsfile によるパイプライン |
| **Docker Pipeline** | Docker agent でのビルド |
| **Docker Plugin** | Docker 連携 |
| **Workspace Cleanup** | ワークスペースの自動クリーンアップ |

### 5.3 Pipeline ジョブの手動作成（自動同期を使わない場合）

1. **New Item** → 名前: `my-test-app` → **Pipeline** → OK
2. Pipeline セクション:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `http://gitlab:80/root/my-test-app.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. **Save** → **Build Now**

> **注意:** Jenkins からの GitLab 接続は `http://gitlab:80`（Docker ネットワーク内のホスト名）を使う。

---

## 6. 本番環境への移行

ローカルテスト環境から本番環境の GitLab / Jenkins に移行する場合、以下の箇所を変更してください。

### 6.1 GitLab CI/CD 変数の変更

GitLab プロジェクトの **Settings → CI/CD → Variables** で以下を本番値に変更:

| 変数名 | ローカルテスト値 | 本番値の例 |
|---|---|---|
| `JENKINS_URL` | `http://jenkins:8080` | `https://jenkins.example.com` |
| `JENKINS_USER` | `admin` | 本番の Jenkins ユーザー名 |
| `JENKINS_TOKEN` | `admin` | Jenkins の API トークン（※ パスワードではなく API トークンを推奨） |

> **Jenkins API トークンの取得方法:**
> Jenkins → ユーザーアイコン → **Configure** → **API Token** → **Add new Token** → 生成されたトークンをコピー

### 6.2 `.gitlab-ci.yml` の変更

テンプレートが生成する `.gitlab-ci.yml` は本番環境向けの設定になっています。変更不要です。

- `build:docker` は TLS 有効な Docker-in-Docker (`DOCKER_TLS_CERTDIR: "/certs"`) を使用
- `$CI_REGISTRY`、`$CI_REGISTRY_USER`、`$CI_REGISTRY_PASSWORD` は GitLab が自動設定

### 6.3 `Jenkinsfile` の変更（`gitlab_and_jenkins` モード）

`Jenkinsfile` 内の以下の環境変数を本番に合わせて変更:

```groovy
environment {
    REGISTRY_URL  = "${env.REGISTRY_URL  ?: 'registry.gitlab.com'}"     // ← 本番の Registry URL
    REGISTRY_CRED = "${env.REGISTRY_CRED ?: 'gitlab-registry-credentials'}" // ← Jenkins に登録した認証情報 ID
    IMAGE_NAME    = "${env.IMAGE_NAME    ?: 'your_project'}"
}
```

> **Jenkins 認証情報の登録:**
> Jenkins → **Manage Jenkins** → **Credentials** → **Global** → **Add Credentials** で GitLab Registry のユーザー名/パスワード（またはトークン）を登録し、ID を `gitlab-registry-credentials` に設定。

### 6.4 GitLab Runner の本番登録

本番の GitLab Runner は以下のように登録します:

```bash
gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.example.com" \
  --token "<ランナー登録トークン>" \
  --executor "docker" \
  --docker-image "ghcr.io/astral-sh/uv:python3.12-bookworm-slim" \
  --docker-privileged \
  --description "production-runner"
```

> **注意:** 本番では `--docker-network-mode` は不要です（ローカル Docker ネットワーク用の設定）。

### 6.5 セキュリティに関する注意

- Jenkins の CSRF 保護は本番では**有効のまま**にしてください（ローカルテストでは自動無効化しています）
- Jenkins API トークンは GitLab CI/CD 変数に **masked** で保存してください
- GitLab Runner は本番では `--docker-privileged` を避け、kaniko 等の代替を検討してください
- Container Registry には HTTPS を使用してください（テンプレートのデフォルト設定で対応済み）

---

## 7. 停止・削除

```bash
# 停止（データは保持）
docker compose -f docker-compose.infra.yml down

# 停止 + ボリューム削除（完全リセット）
docker compose -f docker-compose.infra.yml down -v
```

---

## 8. トラブルシューティング

### GitLab が起動しない / 502 が出る

- メモリ不足の可能性が高い。Docker Desktop の設定で **8GB 以上** を割り当てる
- 初回起動は 3〜5 分かかるので待つ: `docker compose -f docker-compose.infra.yml logs -f gitlab`

### GitLab Runner がジョブを取得しない

- Runner が登録されているか確認: `docker exec gitlab-runner gitlab-runner list`
- Runner のタグが `.gitlab-ci.yml` と一致しているか確認（タグなしで登録推奨）
- `--docker-network-mode` が正しいか確認（コンテナ間通信に必要）
- 古いランナーが残っていないか確認（`docker exec gitlab-runner gitlab-runner unregister --all-runners` で全削除可能）

### Jenkins が GitLab に接続できない

- Repository URL に `http://gitlab:80/...` を使っているか確認（`localhost` ではない）
- `docker network inspect py-modern-template_ci-net` でネットワークを確認

### `deploy:jenkins-sync` が失敗する

- GitLab CI/CD 変数 (`JENKINS_URL`, `JENKINS_USER`, `JENKINS_TOKEN`) が設定されているか確認
- Jenkins が起動しているか確認
- Runner のコンテナから Jenkins にアクセスできるか確認（`network_mode` が `ci-net` であること）

### `deploy:jenkins-sync` がスキップされる

- `build:docker` が失敗していないか確認（deploy ステージは build 成功後にのみ実行）
- `only: - main` の条件を確認（main ブランチへの push でのみ実行）

### `build:docker` が失敗する

- **`Readme file does not exist: README.md`**: Dockerfile で `README.md` を COPY しているか確認
- **`device or resource busy` (docker.sock)**: Runner に `--docker-volumes "/var/run/docker.sock:..."` が設定されていないか確認（dind と競合する）
- **`dial tcp: lookup gitlab: no such host`**: Runner の `--docker-network-mode` が `py-modern-template_ci-net` になっているか確認
- **`https://gitlab:5050/v2/: http: server gave HTTP response to HTTPS client`**: ローカル HTTP レジストリには `--insecure-registry` が必要（verify-ci.sh が自動パッチ）

### ポートが競合する

`docker-compose.infra.yml` のポートマッピングを変更:

```yaml
ports:
  - "9090:8080"   # Jenkins を 9090 に変更
  - "8930:80"     # GitLab を 8930 に変更
```

---

## 9. 構成図

```
┌─────────────────────────────────────────────────────────┐
│                 Docker Network: ci-net                   │
│                                                         │
│  ┌──────────┐   ┌───────────────┐      ┌─────────┐    │
│  │  GitLab   │   │ GitLab Runner │      │ Jenkins │    │
│  │  :80      │◄──│ (Docker exec) │      │  :8080  │    │
│  │  Registry │   └───────┬───────┘      │         │    │
│  │  :5050    │           │              │         │    │
│  │           │     ┌─────▼──────┐       │         │    │
│  │           │     │  CI ジョブ   │──────►│ (API)   │    │
│  │           │     │ + dind     │       │         │    │
│  │           │     │ (ci-net)   │       │         │    │
│  │           │     └────────────┘       │         │    │
│  │           │◄─────────────────────────│ (SCM)   │    │
│  └──────────┘                           └─────────┘    │
│       ▲                                      ▲         │
└───────│──────────────────────────────────────│─────────┘
        │ :8929 / :5050                        │ :8080
   ┌────┴──────────────────────────────────────┴────┐
   │              Host Machine                       │
   │         http://localhost:8929  (GitLab)         │
   │         http://localhost:8080  (Jenkins)        │
   └────────────────────────────────────────────────┘

パイプラインの流れ (gitlab_and_jenkins モード):
  1. 開発者が GitLab に push
  2. GitLab CI が lint → test → build:docker (dind) を実行
  3. build:docker 成功後、deploy:jenkins-sync が Jenkins ジョブを自動作成/更新
  4. Jenkins ジョブが Docker イメージを pull → デプロイ → スモークテスト
```
