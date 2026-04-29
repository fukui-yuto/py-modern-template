"""structlog による構造化ログ設定。"""

from __future__ import annotations

import logging
import sys

import structlog


def configure_logging(level: str = "INFO", *, json_output: bool = False) -> None:
    """structlog を初期化する。"""
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=level.upper(),
    )

    processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]

    if json_output:
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(getattr(logging, level.upper())),
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """名前付きロガーを取得する。"""
    logger: structlog.stdlib.BoundLogger = structlog.get_logger(name)
    return logger
