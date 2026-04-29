"""py_modern_template - A modern Python AI/LLM application template."""

from importlib.metadata import PackageNotFoundError, version

try:
    __version__ = version("py-modern-template")
except PackageNotFoundError:
    __version__ = "0.0.0-dev"
