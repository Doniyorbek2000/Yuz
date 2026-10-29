from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

QUEUE_NAME = "yuz-ai-jobs"


class ConfigError(ValueError):
    pass


@dataclass(frozen=True)
class WorkerConfig:
    api_url: str
    worker_token: str
    redis_url: str
    storage_dir: Path
    model_dir: Path
    concurrency: int
    max_pixels: int

    @staticmethod
    def from_env(env: dict[str, str] | None = None) -> WorkerConfig:
        """Reads and validates the environment; every problem is reported at once."""
        source = os.environ if env is None else env
        problems: list[str] = []
        token = source.get("WORKER_TOKEN", "")
        if len(token) < 32:
            problems.append("WORKER_TOKEN must be at least 32 characters")
        api_url = source.get("API_URL", "http://localhost:3000").rstrip("/")
        if not api_url.startswith(("http://", "https://")):
            problems.append("API_URL must be an http(s) URL")
        try:
            concurrency = int(source.get("CONCURRENCY", "2"))
            if not 1 <= concurrency <= 16:
                raise ValueError
        except ValueError:
            problems.append("CONCURRENCY must be an integer 1..16")
            concurrency = 1
        try:
            max_pixels = int(source.get("MAX_PIXELS", str(24_000_000)))
        except ValueError:
            problems.append("MAX_PIXELS must be an integer")
            max_pixels = 24_000_000
        if problems:
            raise ConfigError("Invalid configuration: " + "; ".join(problems))
        return WorkerConfig(
            api_url=api_url,
            worker_token=token,
            redis_url=source.get("REDIS_URL", "redis://localhost:6379/0"),
            storage_dir=Path(source.get("STORAGE_DIR", "./storage")).resolve(),
            model_dir=Path(source.get("MODEL_DIR", "./models")).resolve(),
            concurrency=concurrency,
            max_pixels=max_pixels,
        )
