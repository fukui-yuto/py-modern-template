import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

// 管理者ユーザー作成
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin")
instance.setSecurityRealm(hudsonRealm)

// 権限設定
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// テスト環境用: CSRF 保護を無効化 (API アクセスを簡素化)
instance.setCrumbIssuer(null)

instance.save()
