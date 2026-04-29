pipeline {
    agent {
        docker {
            image 'ghcr.io/astral-sh/uv:python3.12-bookworm-slim'
            args '--user root'
        }
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Install') {
            steps {
                sh 'uv sync --all-extras --dev --frozen'
            }
        }

        stage('Lint') {
            parallel {
                stage('ruff check') {
                    steps {
                        sh 'uv run ruff check .'
                    }
                }
                stage('ruff format') {
                    steps {
                        sh 'uv run ruff format --check .'
                    }
                }
            }
        }

        stage('Type Check') {
            steps {
                sh 'uv run mypy src tests'
            }
        }

        stage('Test') {
            steps {
                sh 'uv run pytest --junitxml=report.xml'
            }
            post {
                always {
                    junit 'report.xml'
                }
            }
        }
    }

    post {
        cleanup {
            cleanWs()
        }
    }
}
