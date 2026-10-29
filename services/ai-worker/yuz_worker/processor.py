from __future__ import annotations

import asyncio
import logging
from collections.abc import Iterable

from .api import ApiClient, JobGone
from .providers import InvalidInput, Provider, ProviderUnavailable
from .storage import Storage

log = logging.getLogger("yuz_worker")


class JobProcessor:
    """One job: start -> provider -> result file -> complete; any failure -> fail (refunded by the API)."""

    def __init__(self, api: ApiClient, storage: Storage, providers: Iterable[Provider]) -> None:
        self._api = api
        self._storage = storage
        self._providers: dict[str, Provider] = {}
        for provider in providers:
            for job_type in provider.job_types:
                self._providers[job_type] = provider

    @property
    def job_types(self) -> frozenset[str]:
        return frozenset(self._providers)

    async def handle(self, job_id: str) -> str:
        """Returns the outcome ("succeeded", "failed:<reason>" or "skipped")."""
        try:
            job = await self._api.start(job_id)
        except JobGone:
            log.info("job %s is no longer queued; skipping", job_id)
            return "skipped"
        try:
            provider = self._providers.get(job.type)
            if provider is None:
                raise ProviderUnavailable(f"no provider for {job.type}")
            image = await asyncio.to_thread(self._storage.read, job.input_key)
            # CPU-bound model inference stays off the event loop.
            result = await asyncio.to_thread(provider.process, image, job.params)
            result_key = f"{job.output_prefix}/result.{result.extension}"
            await asyncio.to_thread(self._storage.write, result_key, result.data)
            await self._api.complete(job.id, result_key)
            log.info("job %s (%s) succeeded", job.id, job.type)
            return "succeeded"
        except InvalidInput as error:
            reason = f"invalid_input:{error}"
        except ProviderUnavailable as error:
            log.warning("job %s: %s", job_id, error)
            reason = "provider_not_configured"
        except FileNotFoundError:
            reason = "input_missing"
        except Exception:
            log.exception("job %s crashed", job_id)
            reason = "internal_error"
        await self._api.fail(job_id, reason)
        return f"failed:{reason}"
