"""アプリケーション設定。環境変数 / .env ファイルから読み込む。"""

from __future__ import annotations

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """アプリケーション全体の設定。"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = Field(default="py_modern_template")
    log_level: str = Field(default="INFO")
    debug: bool = Field(default=False)

    # LLM 関連(extras=llm のときだけ使う)
    google_api_key: str | None = Field(default=None)
    langsmith_api_key: str | None = Field(default=None)
    langsmith_project: str = Field(default="py_modern_template")


settings = Settings()
