from __future__ import annotations

from typer.testing import CliRunner

from py_modern_template.cli import app

runner = CliRunner()


def test_hello_default() -> None:
    result = runner.invoke(app, ["hello"])
    assert result.exit_code == 0
    assert "Hello, world!" in result.stdout


def test_hello_with_name() -> None:
    result = runner.invoke(app, ["hello", "--name", "Yuto"])
    assert result.exit_code == 0
    assert "Hello, Yuto!" in result.stdout


def test_version() -> None:
    result = runner.invoke(app, ["version"])
    assert result.exit_code == 0
    assert "py_modern_template" in result.stdout
