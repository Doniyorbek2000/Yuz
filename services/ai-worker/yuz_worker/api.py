from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import httpx


class JobGone(Exception):
    """The job was cancelled, finished or deleted before the worker got to it."""


@dataclass(frozen=True)
class StartedJob:
    id: str
    type: str
    params: dict[str, Any]
    input_key: str
    output_prefix: str


class ApiClient:
    """Internal API of the Yuz backend (shared-secret authenticated)."""

    def __init__(self, base_url: str, token: str, transport: httpx.AsyncBaseTransport | None = None) -> None:
        self._client = httpx.AsyncClient(
            base_url=base_url,
            headers={"Authorization": f"Bearer {token}"},
            timeout=httpx.Timeout(30.0),
            transport=transport,
        )

    async def start(self, job_id: str) -> StartedJob:
        response = await self._client.post(f"/internal/ai-jobs/{job_id}/start")
        if response.status_code in (404, 409):
            raise JobGone(job_id)
        response.raise_for_status()
        body = response.json()
        params = body.get("params")
        return StartedJob(
            id=body["id"],
            type=body["type"],
            params=params if isinstance(params, dict) else {},
            input_key=body["inputKey"],
            output_prefix=body["outputPrefix"],
        )

    async def complete(self, job_id: str, result_key: str) -> None:
        response = await self._client.post(
            f"/internal/ai-jobs/{job_id}/complete", json={"resultKey": result_key}
        )
        response.raise_for_status()

    async def fail(self, job_id: str, error: str) -> None:
        response = await self._client.post(f"/internal/ai-jobs/{job_id}/fail", json={"error": error[:500]})
        # A job that already reached a final state needs no failure report.
        if response.status_code not in (404, 409):
            response.raise_for_status()

    async def close(self) -> None:
        await self._client.aclose()
