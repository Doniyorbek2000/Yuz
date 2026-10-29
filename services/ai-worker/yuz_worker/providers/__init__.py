from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Protocol


class InvalidInput(Exception):
    """The photo or the parameters cannot be processed (not retried)."""


class ProviderUnavailable(Exception):
    """No provider is configured for this job type."""


@dataclass(frozen=True)
class ProviderResult:
    data: bytes
    extension: str  # "png" or "jpg"


class Provider(Protocol):
    job_types: frozenset[str]

    def process(self, image: bytes, params: dict[str, Any]) -> ProviderResult: ...

    def close(self) -> None: ...
