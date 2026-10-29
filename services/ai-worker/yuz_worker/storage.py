from __future__ import annotations

import os
from pathlib import Path


class Storage:
    """The storage volume shared with the API. Keys never escape the root."""

    def __init__(self, root: Path) -> None:
        self.root = root.resolve()

    def path_for(self, key: str) -> Path:
        path = (self.root / key).resolve()
        if not key or path == self.root or self.root not in path.parents:
            raise ValueError(f"storage key escapes the root: {key!r}")
        return path

    def read(self, key: str) -> bytes:
        return self.path_for(key).read_bytes()

    def write(self, key: str, data: bytes) -> None:
        """Atomic: the API never sees a half-written result."""
        path = self.path_for(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_name(f".{path.name}.part")
        temp.write_bytes(data)
        os.chmod(temp, 0o600)
        temp.replace(path)
