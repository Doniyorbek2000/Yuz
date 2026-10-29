from __future__ import annotations

import re
from pathlib import Path

WORKER_DIR = Path(__file__).resolve().parents[1]
CHECKSUMS = WORKER_DIR.parents[1] / "tools" / "models.sha256"


def test_docker_image_pins_the_audited_segmenter() -> None:
    pinned = {
        name: sha
        for sha, name in (line.split() for line in CHECKSUMS.read_text().splitlines() if line.strip())
    }
    dockerfile = (WORKER_DIR / "Dockerfile").read_text()
    match = re.search(r"^ARG SEGMENTER_SHA256=([0-9a-f]{64})$", dockerfile, re.MULTILINE)
    assert match is not None
    assert match.group(1) == pinned["selfie_segmenter.tflite"]
