from __future__ import annotations

import io
import re
import threading
from collections.abc import Callable
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageFilter, ImageOps

from . import InvalidInput, ProviderResult, ProviderUnavailable

# Long edge used for segmentation; the mask is upscaled to the full photo.
SEGMENTATION_LONG_EDGE = 768
MODES = frozenset({"blur", "color", "remove"})
_HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")

# Takes RGB uint8 HxWx3, returns person confidence float32 HxW in 0..1.
Segmenter = Callable[[np.ndarray], np.ndarray]


class MediaPipeSegmenter:
    """MediaPipe selfie segmenter (Apache-2.0 model) on CPU; calls are serialized."""

    def __init__(self, model_path: Path) -> None:
        if not model_path.is_file():
            raise ProviderUnavailable(f"segmentation model missing: {model_path}")
        from mediapipe.tasks import python as mp_tasks
        from mediapipe.tasks.python import vision

        options = vision.ImageSegmenterOptions(
            base_options=mp_tasks.BaseOptions(model_asset_path=str(model_path)),
            running_mode=vision.RunningMode.IMAGE,
            output_confidence_masks=True,
            output_category_mask=False,
        )
        self._segmenter = vision.ImageSegmenter.create_from_options(options)
        self._lock = threading.Lock()

    def __call__(self, rgb: np.ndarray) -> np.ndarray:
        import mediapipe as mp

        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb))
        with self._lock:
            result = self._segmenter.segment(image)
        return np.asarray(result.confidence_masks[0].numpy_view(), dtype=np.float32)[..., 0]

    def close(self) -> None:
        """Must run before interpreter teardown; MediaPipe's own __del__ fails there."""
        with self._lock:
            self._segmenter.close()


class BackgroundProvider:
    """Replaces the background behind people: blur, solid colour or transparent cut-out."""

    job_types = frozenset({"BACKGROUND"})

    def __init__(self, segmenter: Segmenter, max_pixels: int = 24_000_000) -> None:
        self._segment = segmenter
        self._max_pixels = max_pixels

    def close(self) -> None:
        close = getattr(self._segment, "close", None)
        if callable(close):
            close()

    def process(self, image: bytes, params: dict[str, Any]) -> ProviderResult:
        mode = params.get("mode", "blur")
        if mode not in MODES:
            raise InvalidInput(f"mode must be one of {sorted(MODES)}")
        color = params.get("color", "#F5F3F7")
        if mode == "color" and (not isinstance(color, str) or not _HEX_COLOR.match(color)):
            raise InvalidInput("color must be #RRGGBB")

        photo = self._decode(image)
        mask = self._mask(photo)
        if float(mask.mean()) < 0.01:
            raise InvalidInput("no_person_detected")
        alpha = Image.fromarray((mask * 255).astype(np.uint8), mode="L")

        if mode == "remove":
            cutout = photo.convert("RGBA")
            cutout.putalpha(alpha)
            return ProviderResult(_encode(cutout, "PNG"), "png")
        if mode == "blur":
            radius = max(4, round(max(photo.size) * 0.025))
            background = photo.filter(ImageFilter.GaussianBlur(radius))
        else:
            background = Image.new("RGB", photo.size, color)
        composed = Image.composite(photo, background, alpha)
        return ProviderResult(_encode(composed, "JPEG"), "jpg")

    def _decode(self, data: bytes) -> Image.Image:
        try:
            with Image.open(io.BytesIO(data)) as probe:
                width, height = probe.size
                if width * height > self._max_pixels:
                    raise InvalidInput("image_too_large")
                probe.load()
                # Camera photos store their rotation in EXIF.
                return ImageOps.exif_transpose(probe).convert("RGB")
        except InvalidInput:
            raise
        except (OSError, Image.DecompressionBombError) as error:
            raise InvalidInput("unreadable_image") from error

    def _mask(self, photo: Image.Image) -> np.ndarray:
        scale = min(1.0, SEGMENTATION_LONG_EDGE / max(photo.size))
        size = (max(1, round(photo.width * scale)), max(1, round(photo.height * scale)))
        small = photo.resize(size, Image.BILINEAR)
        confidence = np.clip(self._segment(np.asarray(small)), 0.0, 1.0)
        mask = Image.fromarray((confidence * 255).astype(np.uint8), mode="L")
        mask = mask.resize(photo.size, Image.BILINEAR)
        # Soft edge: hair and shoulders blend instead of a cut-paper outline.
        feather = max(1, round(max(photo.size) * 0.003))
        mask = mask.filter(ImageFilter.GaussianBlur(feather))
        return np.asarray(mask, dtype=np.float32) / 255.0


def _encode(image: Image.Image, fmt: str) -> bytes:
    buffer = io.BytesIO()
    if fmt == "JPEG":
        image.save(buffer, "JPEG", quality=92, optimize=True)
    else:
        image.save(buffer, "PNG", optimize=True)
    return buffer.getvalue()
