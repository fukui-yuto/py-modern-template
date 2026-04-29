# アーキテクチャ

このドキュメントでは、このテンプレートの設計思想とアーキテクチャを説明します。

---

## 設計原則

### 1. 単一設定ファイル

すべてのツール設定を `pyproject.toml` に集約しています。

```
pyproject.toml に統合されているもの:
├── プロジェクトメタデータ  [project]
├── ビルド設定             [build-system]
├── ruff (Lint/Format)     [tool.ruff]
├── mypy (型チェック)       [tool.mypy]
├── pytest (テスト)         [tool.pytest.ini_options]
└── coverage               [tool.coverage]
```

**なぜ？** 設定ファイルが散らばると管理が煩雑になるため。`pyproject.toml` が Python プロジェクトの標準設定ファイルとして PEP 621 で定義されています。

### 2. src レイアウト

```
my_project/                        <-- copier で生成されたプロジェクト
├── src/
│   └── my_project/            <-- パッケージコード
├── tests/                      <-- テストコード
└── pyproject.toml
```

**なぜ src/ を使うのか？**

- テスト時にインストール済みパッケージを使うことが保証される
- プロジェクトルートのパッケージを誤って import するバグを防ぐ
- パッケージングツールとの互換性が高い

### 3. オプショナル依存

```toml
[project.optional-dependencies]
llm = ["langchain>=0.3", "chromadb>=0.5", ...]   # LLM 開発用
dev = ["ruff>=0.6", "pytest>=8.3", ...]           # 開発ツール
```

- 本番では `uv sync`（コア依存のみ）
- 開発では `uv sync --all-extras`（全依存）
- LLM 開発では `uv sync --extra llm`

**なぜ？** 不要な依存を入れない = イメージサイズ削減 + セキュリティリスク低減。

---

## レイヤー構成

```
┌──────────────────────────────────┐
│          CLI Layer               │
│   cli.py (Typer)                 │
│   コマンドライン引数の処理        │
├──────────────────────────────────┤
│       Configuration Layer        │
│   config.py (Pydantic Settings)  │
│   環境変数 / .env の読み込み      │
├──────────────────────────────────┤
│        Logging Layer             │
│   logging.py (structlog)         │
│   構造化ログ出力                  │
├──────────────────────────────────┤
│     Business Logic Layer         │
│   (ここにアプリケーション         │
│    ロジックを追加していく)         │
└──────────────────────────────────┘
```

### 各レイヤーの責務

| レイヤー | ファイル | 責務 |
|---|---|---|
| CLI | `cli.py` | ユーザー入力の受付、コマンドの定義 |
| Configuration | `config.py` | 環境変数の読み込みとバリデーション |
| Logging | `logging.py` | ログの初期化と取得 |
| Business Logic | （追加する） | アプリケーション固有のロジック |

---

## 依存関係の方向

```
cli.py ──→ config.py
  │
  └──→ logging.py
  │
  └──→ (business logic modules)
```

- **config.py** と **logging.py** は互いに依存しない
- **cli.py** が両方を初期化する
- ビジネスロジックモジュールは config / logging を利用する

---

## CI/CD アーキテクチャ

GitLab CI + Jenkins の連携に対応:

```
┌──────────────────────────────────────────────────────┐
│                   Git Repository                     │
│                                                      │
│  git push                                            │
│       │                                              │
│       ▼                                              │
│  ┌──────────────────────────┐                        │
│  │ GitLab CI                │                        │
│  │  Lint → Test → Build     │                        │
│  │              ↓           │                        │
│  │     Docker Image Push    │                        │
│  └──────────┬───────────────┘                        │
│             │                                        │
│             ▼                                        │
│  ┌──────────────────────┐                            │
│  │ Container Registry    │                           │
│  └──────────┬────────────┘                           │
│             │                                        │
│             ▼                                        │
│  ┌──────────────────────────┐                        │
│  │ Jenkins (Deploy)          │                       │
│  │  Pull → Deploy → Smoke   │                       │
│  └──────────────────────────┘                        │
└──────────────────────────────────────────────────────┘
```

**GitLab CI (CI):**

1. **Lint** — `uv run ruff check .` + `uv run ruff format --check .`
2. **TypeCheck** — `uv run mypy src tests`
3. **Test** — `uv run pytest`
4. **Build** — `docker build` + Registry Push

**Jenkins (CD):**

1. **Pull** — Registry からイメージを取得
2. **Deploy** — コンテナとして起動
3. **Smoke Test** — 動作確認

---

## Docker アーキテクチャ

### マルチステージビルド

```
┌─────────────────────────────┐
│  Stage 1: builder           │
│  uv:python3.12 ベース       │
│                             │
│  1. pyproject.toml + lock   │─── レイヤキャッシュ
│  2. uv sync (依存のみ)      │    （依存が変わらなければ
│  3. COPY src/               │     再ビルド不要）
│  4. uv sync (プロジェクト)   │
└──────────┬──────────────────┘
           │ .venv + src/ のみコピー
           ▼
┌─────────────────────────────┐
│  Stage 2: runtime           │
│  python:3.12-slim ベース    │
│                             │
│  - 最小限のランタイムのみ    │
│  - root 以外のユーザーで実行 │
│  - ビルドツール不要          │
└─────────────────────────────┘
```

**メリット:**
- 最終イメージにビルドツール（uv, gcc 等）が含まれない
- イメージサイズが小さい（通常 100-200MB 程度）
- セキュリティ面で安全（攻撃対象面が小さい）
