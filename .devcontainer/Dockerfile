FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

# uv インストール
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# just インストール
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

USER vscode
