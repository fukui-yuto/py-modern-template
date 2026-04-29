from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def _isolate_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """テスト中は外部環境変数の影響を受けないようにする。"""
    for key in ["GOOGLE_API_KEY", "LANGSMITH_API_KEY"]:
        monkeypatch.delenv(key, raising=False)
