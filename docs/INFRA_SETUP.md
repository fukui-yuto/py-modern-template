# テスト用 CI/CD インフラ セットアップガイド

Jenkins と GitLab をローカルの Docker Compose で立ち上げ、テンプレートの CI パイプラインを検証するための手順書。

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

## 2. GitLab の初期設定

### 2.1 ログイン

- URL: http://localhost:8929
- ユーザー: `root`
- パスワード: `P@ssw0rd1234`

### 2.2 アクセストークンの作成

1. 右上のアバター → **Edit profile** → **Access Tokens**
2. 以下で作成:
   - Token name: `local-test`
   - Scopes: `api`, `read_repository`, `write_repository`
   - Expiration: 任意
3. 生成されたトークンを控える（以降 `GITLAB_TOKEN` と呼ぶ）

### 2.3 テスト用リポジトリの作成

**GUI で作成:**

1. **New project** → **Create blank project**
2. Project name: `my-test-app`
3. Visibility: `Internal` または `Public`
4. Initialize with README: チェックなし
5. **Create project**

**または CLI で作成:**

```bash
curl -s --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  -X POST "http://localhost:8929/api/v4/projects" \
  --form "name=my-test-app" \
  --form "visibility=internal" | python -m json.tool
```

### 2.4 テンプレートから生成したコードを push

```bash
cd my-test-app
git init
git remote add origin http://localhost:8929/root/my-test-app.git
git add -A
git commit -m "init: project from template"
git push -u origin main
# ユーザー: root / パスワード: GITLAB_TOKEN を入力
```

### 2.5 GitLab Runner の登録

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
  --description "local-docker-runner"
```

> **注意:** `--url` はコンテナ間通信なので `http://gitlab:80`（サービス名）を指定する。

登録後、GitLab の Runner 一覧にグリーンのアイコンで表示されれば成功。

### 2.6 パイプラインの実行確認

push 済みのリポジトリに `.gitlab-ci.yml` が含まれていれば、**CI/CD → Pipelines** にパイプラインが表示される。
表示されない場合は、リポジトリの **Settings → CI/CD → Runners** で Runner が有効か確認。

---

## 3. Jenkins の初期設定

### 3.1 初回パスワードの取得

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 3.2 ログインとセットアップ

1. URL: http://localhost:8080
2. 初回パスワードを入力
3. **Install suggested plugins** を選択（数分かかる）
4. 管理者ユーザーを作成:
   - ユーザー名: `admin`
   - パスワード: 任意
5. Jenkins URL: `http://localhost:8080/` のまま **Save and Finish**

### 3.3 追加プラグインのインストール

**Manage Jenkins** → **Plugins** → **Available plugins** から以下を検索してインストール:

| プラグイン | 用途 |
|---|---|
| **Git** | Git リポジトリ連携（通常は初期インストール済み） |
| **Pipeline** | Jenkinsfile によるパイプライン（通常は初期インストール済み） |
| **Docker Pipeline** | Docker agent でのビルド |
| **GitLab** | GitLab webhook 連携（任意） |

インストール後、Jenkins を再起動。

### 3.4 Pipeline ジョブの作成

1. **New Item** → 名前: `my-test-app` → **Pipeline** → OK
2. Pipeline セクション:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `http://gitlab:80/root/my-test-app.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. **Save** → **Build Now**

> **注意:** Jenkins からの GitLab 接続は `http://gitlab:80`（Docker ネットワーク内のホスト名）を使う。

### 3.5 ビルド結果の確認

**Build Now** をクリック → **Console Output** で各ステージの出力を確認。
`Jenkinsfile` が正しければ Install → Lint → TypeCheck → Test の順に実行される。

---

## 4. hosts ファイルの設定（任意）

ブラウザから `gitlab.local` でアクセスしたい場合:

```
# Windows: C:\Windows\System32\drivers\etc\hosts
# Mac/Linux: /etc/hosts
127.0.0.1  gitlab.local
```

---

## 5. 停止・削除

```bash
# 停止（データは保持）
docker compose -f docker-compose.infra.yml down

# 停止 + ボリューム削除（完全リセット）
docker compose -f docker-compose.infra.yml down -v
```

---

## 6. トラブルシューティング

### GitLab が起動しない / 502 が出る

- メモリ不足の可能性が高い。Docker Desktop の設定で **8GB 以上** を割り当てる
- 初回起動は 3〜5 分かかるので待つ: `docker compose -f docker-compose.infra.yml logs -f gitlab`

### GitLab Runner がジョブを取得しない

- Runner が登録されているか確認: `docker exec gitlab-runner gitlab-runner list`
- Runner のタグが `.gitlab-ci.yml` と一致しているか確認（タグなしで登録推奨）
- `--docker-network-mode` が正しいか確認（コンテナ間通信に必要）

### Jenkins が GitLab に接続できない

- Repository URL に `http://gitlab:80/...` を使っているか確認（`localhost` ではない）
- `docker network inspect py-modern-template_ci-net` でネットワークを確認

### ポートが競合する

`docker-compose.infra.yml` のポートマッピングを変更:

```yaml
ports:
  - "9090:8080"   # Jenkins を 9090 に変更
  - "8930:80"     # GitLab を 8930 に変更
```

---

## 7. 構成図

```
┌─────────────────────────────────────────────────┐
│                 Docker Network: ci-net          │
│                                                 │
│  ┌──────────┐   ┌───────────────┐  ┌─────────┐ │
│  │  GitLab   │   │ GitLab Runner │  │ Jenkins │ │
│  │  :80      │◄──│ (Docker exec) │  │  :8080  │ │
│  │           │   └───────────────┘  │         │ │
│  │           │◄─────────────────────│ (SCM)   │ │
│  └──────────┘                       └─────────┘ │
│       ▲                                  ▲      │
└───────│──────────────────────────────────│──────┘
        │ :8929                            │ :8080
   ┌────┴──────────────────────────────────┴────┐
   │              Host Machine                   │
   │         http://localhost:8929  (GitLab)     │
   │         http://localhost:8080  (Jenkins)    │
   └────────────────────────────────────────────┘
```
