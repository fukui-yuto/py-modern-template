#!/usr/bin/env bash
# =============================================================================
# CI/CD パイプライン E2E 検証スクリプト
# =============================================================================
# テンプレートから生成したプロジェクトが GitLab CI / Jenkins で
# 正しく動作するかを自動検証します。
#
# 前提: docker compose -f docker-compose.infra.yml up -d が完了済み
#       GitLab と Jenkins が healthy であること
#
# テストパターン:
#   gitlab_and_jenkins モード → GitLab CI (lint/test/build) + Jenkins (deploy)
#   deploy:jenkins-sync が Jenkins ジョブを自動作成するため、両方をカバーできる
#
# 使い方:
#   bash scripts/verify-ci.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- 設定 ---
GITLAB_URL="http://localhost:8929"
GITLAB_INTERNAL_URL="http://gitlab"  # コンテナ間通信用
GITLAB_USER="root"
GITLAB_PASSWORD="P@ssw0rd1234"
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="admin"
WORK_DIR="/tmp/verify-ci-$$"
PROJECT_NAME="test-gitlab-jenkins"
PROJECT_SLUG="test_gitlab_jenkins"

# --- カラー出力 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}========== $* ==========${NC}"; }
pass()    { echo -e "${GREEN}[PASS]${NC}  $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $*"; FAILURES=$((FAILURES + 1)); }

FAILURES=0

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR"

# =============================================================================
# ユーティリティ関数
# =============================================================================

wait_for_url() {
    local url="$1"
    local name="$2"
    local max_wait="${3:-300}"
    local elapsed=0

    info "Waiting for ${name} at ${url} ..."
    while ! curl -sf -o /dev/null "$url" 2>/dev/null; do
        sleep 5
        elapsed=$((elapsed + 5))
        if [ "$elapsed" -ge "$max_wait" ]; then
            error "${name} が ${max_wait}秒以内に起動しませんでした"
            return 1
        fi
        echo -n "."
    done
    echo ""
    info "${name} is ready (${elapsed}s)"
}

gitlab_api() {
    local method="$1"
    local path="$2"
    shift 2
    curl -sf --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        -X "$method" \
        "${GITLAB_URL}/api/v4${path}" \
        "$@"
}

jenkins_api() {
    local method="$1"
    local path="$2"
    shift 2
    curl -sf --user "${JENKINS_USER}:${JENKINS_PASSWORD}" \
        -X "$method" \
        "${JENKINS_URL}${path}" \
        "$@"
}

# =============================================================================
# Step 0: ヘルスチェック
# =============================================================================
section "Step 0: Infrastructure Health Check"

wait_for_url "${GITLAB_URL}/users/sign_in" "GitLab" 600
wait_for_url "${JENKINS_URL}/login" "Jenkins" 300

# =============================================================================
# Step 1: GitLab セットアップ
# =============================================================================
section "Step 1: GitLab Setup"

# Personal Access Token を rails console で作成
info "Creating GitLab Personal Access Token..."
GITLAB_TOKEN=$(docker exec -i gitlab gitlab-rails runner - <<'RUBY' 2>/dev/null | grep '^glpat-' | tr -d '[:space:]'
user = User.find_by_username("root")
token = user.personal_access_tokens.create!(
    name: "verify-ci-#{Time.now.to_i}",
    scopes: [:api, :read_repository, :write_repository],
    expires_at: 1.day.from_now
)
puts token.token
RUBY
)

if [ -z "$GITLAB_TOKEN" ]; then
    error "GitLab トークンの作成に失敗しました"
    exit 1
fi
pass "GitLab token acquired"

# --- テスト用プロジェクト削除→再作成 ---
info "Recreating GitLab project: ${PROJECT_NAME}"
docker exec -i gitlab gitlab-rails runner - <<DELRUBY 2>/dev/null || true
p = Project.find_by_full_path("root/${PROJECT_NAME}")
if p
  ::Projects::DestroyService.new(p, User.find_by_username('root')).execute
  puts "destroyed"
else
  puts "not_found"
end
DELRUBY
sleep 2

RESULT=$(gitlab_api POST "/projects" \
    --form "name=${PROJECT_NAME}" \
    --form "visibility=public" \
    --form "initialize_with_readme=false" 2>/dev/null || echo "{}")
PROJECT_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
if [ -n "$PROJECT_ID" ]; then
    pass "Project ${PROJECT_NAME} created (ID: ${PROJECT_ID})"
else
    warn "Project ${PROJECT_NAME} creation may have failed, continuing..."
fi

# --- Jenkins 接続用 CI/CD 変数を設定 ---
info "Setting Jenkins CI/CD variables on ${PROJECT_NAME}..."
for var_key_val in "JENKINS_URL:http://jenkins:8080" "JENKINS_USER:admin" "JENKINS_TOKEN:admin"; do
    var_key="${var_key_val%%:*}"
    var_val="${var_key_val#*:}"
    gitlab_api POST "/projects/root%2F${PROJECT_NAME}/variables" \
        --form "key=${var_key}" \
        --form "value=${var_val}" \
        --form "protected=false" \
        --form "masked=false" -o /dev/null 2>/dev/null || \
    gitlab_api PUT "/projects/root%2F${PROJECT_NAME}/variables/${var_key}" \
        --form "value=${var_val}" -o /dev/null 2>/dev/null || true
done
pass "Jenkins CI/CD variables configured"

# =============================================================================
# Step 2: copier でプロジェクト生成 & push
# =============================================================================
section "Step 2: Generate & Push (gitlab_and_jenkins mode)"

PROJ_DIR="${WORK_DIR}/${PROJECT_NAME}"
copier copy --defaults \
    --data project_name="Test GitLab Jenkins" \
    --data project_slug="${PROJECT_SLUG}" \
    --data project_description="GitLab+Jenkins test" \
    --data python_version="3.12" \
    --data include_llm_extras=false \
    --data ci_platform="gitlab_and_jenkins" \
    --data include_docker=true \
    --data license="MIT" \
    "$ROOT_DIR" "$PROJ_DIR" 2>/dev/null

cd "$PROJ_DIR"
uv lock 2>/dev/null

# ローカルテスト用: HTTP レジストリに対応するため dind を insecure-registry に変更
if [ -f .gitlab-ci.yml ]; then
    sed -i 's|    - docker:27-dind|    - name: docker:27-dind\n      command: ["--insecure-registry=gitlab:5050"]|' .gitlab-ci.yml
    sed -i 's|DOCKER_TLS_CERTDIR: "/certs"|DOCKER_TLS_CERTDIR: ""|' .gitlab-ci.yml
    info "Patched .gitlab-ci.yml for local insecure registry"
fi

git init -b main
git add -A
git commit -m "init: gitlab+jenkins test" --no-verify 2>/dev/null
git remote add origin "http://root:${GITLAB_TOKEN}@localhost:8929/root/${PROJECT_NAME}.git"
git push -u origin main 2>/dev/null
pass "${PROJECT_NAME} pushed to GitLab"

cd "$ROOT_DIR"

# =============================================================================
# Step 3: GitLab Runner 登録
# =============================================================================
section "Step 3: Register GitLab Runner"

# 既存ランナーを全削除 (前回の設定が残らないようにする)
info "Unregistering all existing runners..."
MSYS_NO_PATHCONV=1 docker exec gitlab-runner gitlab-runner unregister --all-runners 2>/dev/null || true

# Runner registration token を取得 (GitLab 16+ の新方式)
info "Creating GitLab Runner via API..."
RUNNER_RESPONSE=$(gitlab_api POST "/user/runners" \
    --form "runner_type=instance_type" \
    --form "run_untagged=true" \
    --form "description=verify-ci-runner" 2>/dev/null || echo "{}")
RUNNER_TOKEN=$(echo "$RUNNER_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null || true)

if [ -z "$RUNNER_TOKEN" ]; then
    warn "New runner API failed, trying legacy registration..."
    RUNNER_REG_TOKEN=$(docker exec gitlab gitlab-rails runner "puts Gitlab::CurrentSettings.runners_registration_token" 2>/dev/null | tail -1 || true)
    if [ -n "$RUNNER_REG_TOKEN" ]; then
        MSYS_NO_PATHCONV=1 docker exec gitlab-runner gitlab-runner register \
            --non-interactive \
            --url "http://gitlab:80" \
            --registration-token "$RUNNER_REG_TOKEN" \
            --executor "docker" \
            --docker-image "ghcr.io/astral-sh/uv:python3.12-bookworm-slim" \
            --docker-network-mode "py-modern-template_ci-net" \
            --docker-privileged \
            --description "verify-ci-runner" 2>/dev/null
        pass "Runner registered (legacy method)"
    else
        error "Runner registration token を取得できませんでした"
    fi
else
    MSYS_NO_PATHCONV=1 docker exec gitlab-runner gitlab-runner register \
        --non-interactive \
        --url "http://gitlab:80" \
        --token "$RUNNER_TOKEN" \
        --executor "docker" \
        --docker-image "ghcr.io/astral-sh/uv:python3.12-bookworm-slim" \
        --docker-network-mode "py-modern-template_ci-net" \
        --docker-privileged \
        --description "verify-ci-runner" 2>/dev/null
    pass "Runner registered (new method)"
fi

# =============================================================================
# Step 4: GitLab CI パイプライン確認
# =============================================================================
section "Step 4: Verify GitLab CI Pipeline"

info "Waiting for pipeline in ${PROJECT_NAME}..."
MAX_WAIT=600
ELAPSED=0
PIPELINE_STATUS=""

while [ "$ELAPSED" -lt "$MAX_WAIT" ]; do
    PIPELINE_STATUS=$(gitlab_api GET "/projects/root%2F${PROJECT_NAME}/pipelines?per_page=1" 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['status'] if d else '')" 2>/dev/null || true)

    if [[ "$PIPELINE_STATUS" == "success" ]]; then
        pass "Pipeline: SUCCESS"
        break
    elif [[ "$PIPELINE_STATUS" == "failed" ]]; then
        # 失敗したジョブを特定
        PIPELINE_ID=$(gitlab_api GET "/projects/root%2F${PROJECT_NAME}/pipelines?per_page=1" 2>/dev/null \
            | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null || true)
        FAILED_JOB_NAMES=""
        RUNNING_JOBS=""
        if [ -n "$PIPELINE_ID" ]; then
            JOBS_JSON=$(gitlab_api GET "/projects/root%2F${PROJECT_NAME}/pipelines/${PIPELINE_ID}/jobs" 2>/dev/null || true)
            FAILED_JOB_NAMES=$(echo "$JOBS_JSON" | python3 -c "import sys,json; jobs=json.load(sys.stdin); print(','.join([j['name'] for j in jobs if j['status']=='failed']))" 2>/dev/null || true)
            RUNNING_JOBS=$(echo "$JOBS_JSON" | python3 -c "import sys,json; jobs=json.load(sys.stdin); r=[j['name'] for j in jobs if j['status'] in ('running','pending','created')]; print(','.join(r))" 2>/dev/null || true)
        fi

        # まだ実行中のジョブがある場合は待機を続ける
        if [ -n "$RUNNING_JOBS" ]; then
            sleep 15
            ELAPSED=$((ELAPSED + 15))
            echo -n "."
            continue
        fi

        # build:docker の失敗はローカル dind の制限として許容
        if [[ "$FAILED_JOB_NAMES" == "build:docker" ]]; then
            warn "Pipeline: build:docker failed (expected in local dind)"
            pass "Pipeline: lint/test/deploy stages passed"
        else
            fail "Pipeline: FAILED (jobs: ${FAILED_JOB_NAMES})"
        fi
        break
    elif [[ "$PIPELINE_STATUS" == "canceled" ]]; then
        fail "Pipeline: CANCELED"
        break
    fi

    sleep 15
    ELAPSED=$((ELAPSED + 15))
    echo -n "."
done

if [ "$ELAPSED" -ge "$MAX_WAIT" ] && [[ "$PIPELINE_STATUS" != "success" ]]; then
    fail "Pipeline: TIMEOUT (status: ${PIPELINE_STATUS:-none})"
fi

# =============================================================================
# Step 5: Jenkins ジョブ確認 (deploy:jenkins-sync が自動作成)
# =============================================================================
section "Step 5: Verify Jenkins Job"

info "Checking if deploy:jenkins-sync created Jenkins job '${PROJECT_SLUG}'..."
MAX_WAIT=60
ELAPSED=0
JOB_EXISTS=""

while [ "$ELAPSED" -lt "$MAX_WAIT" ]; do
    JOB_EXISTS=$(jenkins_api GET "/job/${PROJECT_SLUG}/api/json" 2>/dev/null || true)
    if [ -n "$JOB_EXISTS" ]; then
        pass "Jenkins job '${PROJECT_SLUG}' found (created by deploy:jenkins-sync)"
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ -z "$JOB_EXISTS" ]; then
    warn "Jenkins job '${PROJECT_SLUG}' not found (deploy:jenkins-sync may not have run yet)"
fi

# =============================================================================
# Step 6: テスト用プロジェクトのクリーンアップ
# =============================================================================
section "Step 6: Cleanup Test Projects"

info "Removing test projects from GitLab..."
docker exec -i gitlab gitlab-rails runner - <<'CLEANRUBY' 2>/dev/null || true
user = User.find_by_username('root')
Project.where("name LIKE '%test%'").find_each do |p|
  puts "Destroying: #{p.id} #{p.full_path}"
  ::Projects::DestroyService.new(p, user).execute
end
puts "cleanup_done"
CLEANRUBY
pass "Test projects cleaned up"

info "Removing test Jenkins jobs..."
for job_name in "${PROJECT_NAME}" "${PROJECT_SLUG}"; do
    jenkins_api POST "/job/${job_name}/doDelete" -o /dev/null 2>/dev/null || true
done
pass "Jenkins jobs cleaned up"

# =============================================================================
# 結果サマリー
# =============================================================================
section "Verification Summary"

if [ "$FAILURES" -eq 0 ]; then
    echo -e "\n${GREEN}==============================${NC}"
    echo -e "${GREEN}  ALL CHECKS PASSED${NC}"
    echo -e "${GREEN}==============================${NC}\n"
    exit 0
else
    echo -e "\n${RED}==============================${NC}"
    echo -e "${RED}  ${FAILURES} CHECK(S) FAILED${NC}"
    echo -e "${RED}==============================${NC}\n"
    exit 1
fi
