from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import httpx
import pytest

from tests.conftest import left_half_person
from yuz_worker.api import ApiClient
from yuz_worker.processor import JobProcessor
from yuz_worker.providers import ProviderResult
from yuz_worker.providers.background import BackgroundProvider
from yuz_worker.storage import Storage

JOB_ID = "job-1"
INPUT_KEY = "users/u1/jobs/job-1/input.jpg"
OUTPUT_PREFIX = "users/u1/jobs/job-1"


class FakeApi:
    """Records worker calls and answers like the backend's internal API."""

    def __init__(self, job_type: str = "BACKGROUND", start_status: int = 200, complete_status: int = 200):
        self.job_type = job_type
        self.start_status = start_status
        self.complete_status = complete_status
        self.calls: list[tuple[str, Any]] = []
        self.auth: set[str] = set()

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.auth.add(request.headers.get("Authorization", ""))
        action = request.url.path.rsplit("/", 1)[-1]
        body = json.loads(request.content) if request.content else None
        self.calls.append((action, body))
        if action == "start":
            if self.start_status != 200:
                return httpx.Response(self.start_status, json={"code": "job_not_queued"})
            return httpx.Response(
                200,
                json={
                    "id": JOB_ID,
                    "type": self.job_type,
                    "params": {"mode": "color", "color": "#112233"},
                    "inputKey": INPUT_KEY,
                    "outputPrefix": OUTPUT_PREFIX,
                },
            )
        if action == "complete":
            return httpx.Response(self.complete_status, json={})
        return httpx.Response(200, json={})


def build(tmp_path: Path, api: FakeApi, providers: list[Any] | None = None) -> tuple[JobProcessor, Storage]:
    storage = Storage(tmp_path)
    client = ApiClient("http://api.test", "t" * 40, transport=httpx.MockTransport(api.handler))
    if providers is None:
        providers = [BackgroundProvider(left_half_person)]
    return JobProcessor(client, storage, providers), storage


async def test_successful_job_writes_the_result_and_completes(tmp_path: Path, photo: bytes) -> None:
    api = FakeApi()
    processor, storage = build(tmp_path, api)
    storage.write(INPUT_KEY, photo)
    assert await processor.handle(JOB_ID) == "succeeded"
    assert api.calls == [("start", None), ("complete", {"resultKey": f"{OUTPUT_PREFIX}/result.jpg"})]
    assert api.auth == {"Bearer " + "t" * 40}
    assert storage.read(f"{OUTPUT_PREFIX}/result.jpg")[:2] == b"\xff\xd8"
    assert not (tmp_path / OUTPUT_PREFIX / ".result.jpg.part").exists()


@pytest.mark.parametrize("status", [404, 409])
async def test_skips_jobs_that_are_no_longer_queued(tmp_path: Path, status: int) -> None:
    api = FakeApi(start_status=status)
    processor, _ = build(tmp_path, api)
    assert await processor.handle(JOB_ID) == "skipped"
    assert [action for action, _ in api.calls] == ["start"]


async def test_missing_input_fails_the_job(tmp_path: Path) -> None:
    api = FakeApi()
    processor, _ = build(tmp_path, api)
    assert await processor.handle(JOB_ID) == "failed:input_missing"
    assert api.calls[-1] == ("fail", {"error": "input_missing"})


async def test_unserved_type_fails_as_not_configured(tmp_path: Path, photo: bytes) -> None:
    api = FakeApi(job_type="PHOTOSHOOT")
    processor, storage = build(tmp_path, api)
    storage.write(INPUT_KEY, photo)
    assert await processor.handle(JOB_ID) == "failed:provider_not_configured"
    assert api.calls[-1] == ("fail", {"error": "provider_not_configured"})


async def test_invalid_input_reports_the_reason(tmp_path: Path) -> None:
    api = FakeApi()
    processor, storage = build(tmp_path, api)
    storage.write(INPUT_KEY, b"garbage")
    assert await processor.handle(JOB_ID) == "failed:invalid_input:unreadable_image"


async def test_provider_crash_is_reported_without_details(tmp_path: Path, photo: bytes) -> None:
    class Exploding:
        job_types = frozenset({"BACKGROUND"})

        def process(self, image: bytes, params: dict[str, Any]) -> ProviderResult:
            raise RuntimeError("secret internal path /srv/x")

    api = FakeApi()
    processor, storage = build(tmp_path, api, [Exploding()])
    storage.write(INPUT_KEY, photo)
    assert await processor.handle(JOB_ID) == "failed:internal_error"
    assert api.calls[-1] == ("fail", {"error": "internal_error"})


async def test_rejected_completion_fails_the_job(tmp_path: Path, photo: bytes) -> None:
    api = FakeApi(complete_status=400)
    processor, storage = build(tmp_path, api)
    storage.write(INPUT_KEY, photo)
    assert await processor.handle(JOB_ID) == "failed:internal_error"


def test_storage_refuses_keys_outside_the_root(tmp_path: Path) -> None:
    storage = Storage(tmp_path / "root")
    for key in ["../escape.jpg", "/etc/passwd", "", "users/../../x"]:
        with pytest.raises(ValueError):
            storage.path_for(key)
    storage.write("users/a/b.png", b"x")
    assert storage.read("users/a/b.png") == b"x"
