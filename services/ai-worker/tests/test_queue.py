from __future__ import annotations

import asyncio
import os
import uuid
from pathlib import Path

import httpx
import pytest
from bullmq import Queue, Worker

from tests.conftest import left_half_person
from tests.test_processor import INPUT_KEY, OUTPUT_PREFIX, FakeApi
from yuz_worker.api import ApiClient
from yuz_worker.main import queue_handler
from yuz_worker.processor import JobProcessor
from yuz_worker.providers.background import BackgroundProvider
from yuz_worker.storage import Storage

REDIS_URL = os.environ.get("TEST_REDIS_URL")

pytestmark = pytest.mark.skipif(not REDIS_URL, reason="TEST_REDIS_URL not set")


async def test_processes_jobs_published_on_the_queue(tmp_path: Path, photo: bytes) -> None:
    api = FakeApi()
    storage = Storage(tmp_path)
    storage.write(INPUT_KEY, photo)
    client = ApiClient("http://api.test", "t" * 40, transport=httpx.MockTransport(api.handler))
    processor = JobProcessor(client, storage, [BackgroundProvider(left_half_person)])

    # A unique queue per run keeps parallel CI jobs and leftovers apart.
    name = f"yuz-test-{uuid.uuid4().hex}"
    queue = Queue(name, {"connection": REDIS_URL})
    finished: asyncio.Queue[str] = asyncio.Queue()
    worker = Worker(name, queue_handler(processor), {"connection": REDIS_URL})
    worker.on("completed", lambda job, result: finished.put_nowait(result))
    try:
        # Same shape the API publishes: {"jobId": ...}, job id = AI job id.
        await queue.add("process", {"jobId": "job-1"}, {"jobId": "job-1"})
        await queue.add("process", {"unexpected": True})
        results = sorted([await asyncio.wait_for(finished.get(), 20) for _ in range(2)])
    finally:
        await worker.close()
        await queue.obliterate(force=True)
        await queue.close()
        await client.close()

    assert results == ["skipped", "succeeded"]
    assert storage.read(f"{OUTPUT_PREFIX}/result.jpg")[:2] == b"\xff\xd8"
