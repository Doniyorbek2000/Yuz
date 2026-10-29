from __future__ import annotations

import io

import numpy as np
import pytest
from PIL import Image


def jpeg_bytes(width: int = 64, height: int = 48, orientation: int | None = None) -> bytes:
    """Left half red, right half blue, so orientation and compositing are observable."""
    pixels = np.zeros((height, width, 3), dtype=np.uint8)
    pixels[:, : width // 2] = (220, 30, 30)
    pixels[:, width // 2 :] = (30, 30, 220)
    image = Image.fromarray(pixels)
    buffer = io.BytesIO()
    if orientation is None:
        image.save(buffer, "JPEG", quality=95)
    else:
        exif = Image.Exif()
        exif[0x0112] = orientation
        image.save(buffer, "JPEG", quality=95, exif=exif)
    return buffer.getvalue()


def left_half_person(rgb: np.ndarray) -> np.ndarray:
    """Fake segmenter: the person fills the left half of the frame."""
    mask = np.zeros(rgb.shape[:2], dtype=np.float32)
    mask[:, : rgb.shape[1] // 2] = 1.0
    return mask


@pytest.fixture
def photo() -> bytes:
    return jpeg_bytes()
