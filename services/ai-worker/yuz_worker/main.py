from __future__ import annotations

import asyncio
import logging
import signal
from collections.abc import Awaitable, Callable
from typing import Any

from bullmq import Worker

from .api import ApiClient
from .config import QUEUE_NAME, WorkerConfig
from .processor import JobProcessor
from .providers import Provider, ProviderUnavailable
from .providers.background import BackgroundProvider, MediaPipeSegmenter
from .storage import Storage

log = logging.getLogger("yuz_worker")


def build_providers(config: WorkerConfig) -> list[Provider]:
    """Free, local providers only. Generative types (photoshoot, hairstyle,
    makeup) need a paid model API or GPU and are added only after the owner
    approves one; the API does not accept those jobs until then."""
    providers: list[Provider] = []
    try:
        segmenter = MediaPipeSegmenter(config.model_dir / "selfie_segmenter.tflite")
        providers.append(BackgroundProvider(segmenter, max_pixels=config.max_pixels))
    except ProviderUnavailable as error:
        log.error("background provider disabled: %s", error)
    return providers


def queue_handler(processor: JobProcessor) -> Callable[[Any, str], Awaitable[str]]:
    """Queue entries carry only the job id; the API is the source of truth."""

    async def process(job: Any, _token: str) -> str:
        job_id = job.data.get("jobId") if isinstance(job.data, dict) else None
        if not isinstance(job_id, str):
            log.error("malformed queue entry %s", job.id)
            return "skipped"
        return await processor.handle(job_id)

    return process


async def serve(config: WorkerConfig) -> None:
    api = ApiClient(config.api_url, config.worker_token)
    providers = build_providers(config)
    processor = JobProcessor(api, Storage(config.storage_dir), providers)
    served = sorted(processor.job_types) or "no job types"
    log.info("serving %s with concurrency %d", served, config.concurrency)

    worker = Worker(
        QUEUE_NAME,
        queue_handler(processor),
        {"connection": config.redis_url, "concurrency": config.concurrency},
    )
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)
    await stop.wait()
    log.info("shutting down: finishing running jobs")
    await worker.close()
    await api.close()
    for provider in providers:
        provider.close()


def run() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    asyncio.run(serve(WorkerConfig.from_env()))


if __name__ == "__main__":
    run()
