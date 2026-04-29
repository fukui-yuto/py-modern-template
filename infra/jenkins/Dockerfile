FROM jenkins/jenkins:lts-jdk17

# セットアップウィザードをスキップ
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Xmx512m"

# Docker CLI をインストール (Docker agent 用)
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*
USER jenkins

# プラグインをインストール
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# 管理者ユーザーを自動作成
COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/
