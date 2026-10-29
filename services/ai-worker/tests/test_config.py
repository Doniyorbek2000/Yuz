from __future__ import annotations

import pytest

from yuz_worker.config import ConfigError, WorkerConfig

VALID = {"WORKER_TOKEN": "w" * 32, "API_URL": "http://api:3000/", "CONCURRENCY": "4"}


def test_reads_a_valid_environment() -> None:
    config = WorkerConfig.from_env(VALID)
    assert config.api_url == "http://api:3000"
    assert config.concurrency == 4
    assert config.max_pixels == 24_000_000


def test_reports_every_problem_at_once() -> None:
    with pytest.raises(ConfigError) as error:
        WorkerConfig.from_env({"WORKER_TOKEN": "short", "API_URL": "ftp://x", "CONCURRENCY": "99"})
    message = str(error.value)
    assert "WORKER_TOKEN" in message
    assert "API_URL" in message
    assert "CONCURRENCY" in message
