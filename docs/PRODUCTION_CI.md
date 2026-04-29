# 本番 CI/CD 環境への接続ガイド

テスト用の Docker Compose 環境(docker-compose.infra.yml)ではなく、
本番(社内)の GitLab / Jenkins を使用する場合の変更箇所をまとめたガイドです。

---

## 変更箇所の全体マップ

```
変更が必要なファイル
├── .gitlab-ci.yml           ← GitLab 本番で使う場合
├── Jenkinsfile              ← Jenkins 本番で使う場合
├── scripts/create-jenkins-job.sh  ← Jenkins ジョブ作成スクリプト
├── pyproject.toml           ← パッケージレジストリ設定(任意)
└── (新規作成の場合のみ)
    └── .env                 ← CI 用の環境変数
```

---

## 1. GitLab 本番環境を使う場合

### 1.1 変更不要なファイル

`.gitlab-ci.yml` は**そのまま使えます**。
ファイル内に URL やサーバー固有の設定は含まれていません。

### 1.2 GitLab 側で必要な設定

| 設定項目 | 場所 | 内容 |
|---|---|---|
| Runner の確認 | Settings → CI/CD → Runners | Runner が利用可能か確認する(下記参照) |
| CI/CD 変数 | Settings → CI/CD → Variables | 必要に応じて環境変数を設定 |

### 1.3 GitLab Runner の確認

> **社内で既に GitLab CI/CD が稼働している場合、Runner は管理者(インフラチーム)が設定済みのはずです。**
> あなたが Runner をインストール・登録する必要は通常ありません。

#### まず Runner が使えるか確認する

```
GitLab Web UI → プロジェクト → Settings → CI/CD → Runners(展開)
```

- **緑の丸が表示されている** → Runner が利用可能。**追加作業は不要**。そのまま使える
- **Shared Runners が有効** と表示されている → 同様に追加作業は不要
- **何も表示されない** → 管理者に「Shared Runner を有効にしてほしい」と依頼する

#### Runner が存在しない場合のみ: 新規インストール

管理者に依頼できない等、自分で Runner を用意する必要がある場合のみ実施してください。

```bash
# 1. Runner をインストール(Linux の場合)
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt install gitlab-runner

# 2. Runner を登録
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.yourcompany.com" \                    # ← 本番 GitLab の URL に変更
  --token "<Runner登録トークン>" \                              # ← 本番 GitLab から取得
  --executor "docker" \
  --docker-image "ghcr.io/astral-sh/uv:python3.12-bookworm-slim"
```

**テスト環境との違い:**

| 項目 | テスト環境 | 本番環境 |
|---|---|---|
| `--url` | `http://gitlab:80` | `https://gitlab.yourcompany.com` |
| `--token` | テスト用トークン | 本番 GitLab の登録トークン |
| `--docker-network-mode` | `py-modern-template_ci-net` | **不要**(削除する) |

### 1.4 リポジトリの push 先を変更

```bash
# テスト環境の場合
git remote add origin http://localhost:8929/root/my-app.git

# 本番環境の場合 ← ここを変更
git remote add origin https://gitlab.yourcompany.com/your-group/my-app.git
```

### 1.5 CI/CD 変数の設定(必要な場合)

GitLab Web UI → プロジェクト → **Settings** → **CI/CD** → **Variables** で設定:

| 変数名 | 用途 | 例 |
|---|---|---|
| `GOOGLE_API_KEY` | LLM API キー | `AIza...` |
| `LANGSMITH_API_KEY` | LangSmith | `ls-...` |
| `PYPI_TOKEN` | パッケージ公開用 | `pypi-...` |

> **注意:** Masked / Protected オプションを有効にして、ログにシークレットが出力されないようにする。

---

## 2. Jenkins 本番環境を使う場合

### 2.1 Jenkinsfile の変更箇所

`Jenkinsfile` は**ほぼそのまま使えます**が、本番環境に合わせて以下を確認・変更してください。

```groovy
pipeline {
    agent {
        docker {
            image 'ghcr.io/astral-sh/uv:python3.12-bookworm-slim'
            // ↓ 本番 Jenkins が Docker Hub にアクセスできない場合、社内レジストリに変更
            // image 'registry.yourcompany.com/tools/uv:python3.12'
            args '--user root'
        }
    }
    // ... 以降は変更不要 ...
}
```

**確認ポイント:**

| 項目 | テスト環境 | 本番環境で確認すること |
|---|---|---|
| Docker イメージ | `ghcr.io/astral-sh/uv:...` | 社内プロキシ/ミラー経由でアクセスできるか |
| Docker ソケット | 自動マウント | Jenkins Agent に Docker が使えるか |
| タイムアウト | 15 分 | 必要に応じて調整 |

### 2.2 Jenkins ジョブ作成スクリプトの変更箇所

`scripts/create-jenkins-job.sh` を本番で使う場合、**環境変数を変更**します。

```bash
# テスト環境
export JENKINS_URL=http://localhost:8080
export JENKINS_USER=admin
export JENKINS_TOKEN=<テスト用トークン>
bash scripts/create-jenkins-job.sh my-app http://gitlab:80/root/my-app.git

# 本番環境 ← ここを変更
export JENKINS_URL=https://jenkins.yourcompany.com          # ← 本番 Jenkins の URL
export JENKINS_USER=your-username                            # ← あなたのユーザー名
export JENKINS_TOKEN=<本番APIトークン>                        # ← 本番 Jenkins の API トークン
bash scripts/create-jenkins-job.sh my-app https://gitlab.yourcompany.com/your-group/my-app.git
#                                                            ↑ 本番 GitLab のリポジトリ URL
```

**変更が必要な値(3 箇所):**

| 環境変数 | テスト環境 | 本番環境 |
|---|---|---|
| `JENKINS_URL` | `http://localhost:8080` | `https://jenkins.yourcompany.com` |
| `JENKINS_USER` | `admin` | あなたのユーザー名 |
| `JENKINS_TOKEN` | テスト用トークン | 本番 API トークン |

**加えて、コマンド引数:**

| 引数 | テスト環境 | 本番環境 |
|---|---|---|
| リポジトリ URL | `http://gitlab:80/root/my-app.git` | `https://gitlab.yourcompany.com/your-group/my-app.git` |

### 2.3 Jenkins の GUI でジョブを作成する場合

スクリプトを使わず GUI で作成する場合の変更箇所:

1. **New Item** → Pipeline → OK
2. Pipeline セクション:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://gitlab.yourcompany.com/your-group/my-app.git`  ← **本番 URL**
   - Credentials: ← **本番 GitLab の認証情報を追加**
   - Branch: `*/main`
   - Script Path: `Jenkinsfile` ← 変更不要
3. Save → Build Now

### 2.4 Jenkins Credentials の設定

本番 GitLab にアクセスするための認証情報を Jenkins に登録:

1. **Manage Jenkins** → **Credentials** → **(global)** → **Add Credentials**
2. Kind: **Username with password** または **SSH Username with private key**
3. Username: GitLab ユーザー名
4. Password: GitLab アクセストークン(API スコープ付き)
5. ID: `gitlab-credentials`(任意)
6. Save

Jenkinsfile で Credentials を使う場合:

```groovy
// Jenkinsfile に追記(必要な場合のみ)
pipeline {
    agent { /* ... */ }
    environment {
        GIT_CREDENTIALS = credentials('gitlab-credentials')
    }
    // ...
}
```

---

## 3. 本番 Jenkins + 本番 GitLab を連携する場合

### Webhook の設定(push 時に自動ビルド)

テスト環境では手動で **Build Now** しましたが、本番では push 時に自動ビルドさせます。

**GitLab 側:**

1. プロジェクト → **Settings** → **Webhooks**
2. URL: `https://jenkins.yourcompany.com/project/my-app`
3. Secret Token: Jenkins 側で設定した値
4. Trigger: Push events, Merge request events
5. **Add webhook**

**Jenkins 側:**

1. ジョブ → **Configure** → **Build Triggers**
2. **Build when a change is pushed to GitLab** にチェック
3. GitLab webhook URL が表示されるのでコピー

### Multibranch Pipeline(推奨)

新リポジトリの Jenkinsfile を自動検出させる場合:

1. **New Item** → **Multibranch Pipeline** → OK
2. Branch Sources → **Git**
3. Repository URL: `https://gitlab.yourcompany.com/your-group/my-app.git`
4. Credentials: 上記で設定した Credentials
5. Save → **Scan Multibranch Pipeline Now**

Jenkinsfile があるブランチが自動的にジョブとして登録されます。

---

## 4. 変更箇所サマリー

### GitLab を使う場合

| ファイル | 変更内容 | 必須/任意 |
|---|---|---|
| `.gitlab-ci.yml` | **変更不要** | - |
| `git remote` | URL を本番 GitLab に変更 | 必須 |
| GitLab Runner | 本番 GitLab に Runner を登録 | 必須 |
| CI/CD Variables | シークレットを設定 | 任意 |

### Jenkins を使う場合

| ファイル/設定 | 変更内容 | 必須/任意 |
|---|---|---|
| `Jenkinsfile` | **ほぼ変更不要**(Docker イメージ URL のみ確認) | 確認のみ |
| `scripts/create-jenkins-job.sh` | 環境変数 3 つ + リポジトリ URL を変更 | スクリプト使用時のみ |
| Jenkins Credentials | GitLab 認証情報を登録 | 必須 |
| Jenkins Job | Repository URL を本番 GitLab に変更 | 必須 |
| Webhook | GitLab → Jenkins の連携設定 | 任意(自動ビルド時) |

---

## 5. チェックリスト

### GitLab 本番移行

- [ ] 本番 GitLab にリポジトリを作成した
- [ ] `git remote` を本番 URL に設定した
- [ ] GitLab Runner が登録・稼働している
- [ ] `git push` 後にパイプラインが実行される
- [ ] CI/CD Variables にシークレットを設定した(必要な場合)

### Jenkins 本番移行

- [ ] 本番 Jenkins にアクセスできる
- [ ] Docker Pipeline プラグインがインストールされている
- [ ] GitLab Credentials を Jenkins に登録した
- [ ] Pipeline ジョブを作成し、Repository URL を本番 GitLab に設定した
- [ ] `Jenkinsfile` の Docker イメージが本番 Jenkins からアクセス可能か確認した
- [ ] **Build Now** で全ステージが成功する
- [ ] Webhook を設定した(自動ビルドの場合)
