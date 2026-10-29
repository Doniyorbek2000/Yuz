from __future__ import annotations

import io
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from tests.conftest import jpeg_bytes, left_half_person
from yuz_worker.providers import InvalidInput, ProviderUnavailable
from yuz_worker.providers.background import BackgroundProvider, MediaPipeSegmenter

MODEL = Path(__file__).resolve().parents[1] / "models" / "selfie_segmenter.tflite"


def decode(data: bytes) -> Image.Image:
    return Image.open(io.BytesIO(data))


def test_color_mode_keeps_the_person_and_paints_the_background(photo: bytes) -> None:
    result = BackgroundProvider(left_half_person).process(photo, {"mode": "color", "color": "#00FF00"})
    assert result.extension == "jpg"
    image = np.asarray(decode(result.data).convert("RGB"), dtype=np.int16)
    assert image.shape == (48, 64, 3)
    # Away from the feathered edge: person untouched, background replaced.
    assert np.abs(image[24, 5] - (220, 30, 30)).max() < 25
    assert np.abs(image[24, 58] - (0, 255, 0)).max() < 25


def test_remove_mode_returns_transparent_png(photo: bytes) -> None:
    result = BackgroundProvider(left_half_person).process(photo, {"mode": "remove"})
    assert result.extension == "png"
    image = decode(result.data)
    assert image.mode == "RGBA"
    alpha = np.asarray(image)[..., 3]
    assert alpha[24, 5] > 240
    assert alpha[24, 58] < 15


def test_blur_mode_is_the_default(photo: bytes) -> None:
    result = BackgroundProvider(left_half_person).process(photo, {})
    assert result.extension == "jpg"
    assert decode(result.data).size == (64, 48)


@pytest.mark.parametrize(
    ("params", "reason"),
    [
        ({"mode": "sepia"}, "mode must be one of"),
        ({"mode": "color", "color": "red"}, "color must be #RRGGBB"),
        ({"mode": "color", "color": 12}, "color must be #RRGGBB"),
    ],
)
def test_rejects_invalid_params(photo: bytes, params: dict[str, object], reason: str) -> None:
    with pytest.raises(InvalidInput, match=reason):
        BackgroundProvider(left_half_person).process(photo, params)


def test_rejects_unreadable_and_oversized_images(photo: bytes) -> None:
    with pytest.raises(InvalidInput, match="unreadable_image"):
        BackgroundProvider(left_half_person).process(b"not an image", {})
    with pytest.raises(InvalidInput, match="image_too_large"):
        BackgroundProvider(left_half_person, max_pixels=1000).process(photo, {})


def test_reports_photos_without_people(photo: bytes) -> None:
    with pytest.raises(InvalidInput, match="no_person_detected"):
        BackgroundProvider(lambda rgb: np.zeros(rgb.shape[:2], dtype=np.float32)).process(photo, {})


def test_applies_exif_rotation_before_segmenting() -> None:
    seen: list[tuple[int, ...]] = []

    def segmenter(rgb: np.ndarray) -> np.ndarray:
        seen.append(rgb.shape)
        return left_half_person(rgb)

    # Orientation 6: stored landscape, displayed portrait.
    result = BackgroundProvider(segmenter).process(jpeg_bytes(orientation=6), {"mode": "color"})
    assert seen == [(64, 48, 3)]
    assert decode(result.data).size == (48, 64)


def test_segments_large_photos_at_reduced_size() -> None:
    seen: list[tuple[int, ...]] = []

    def segmenter(rgb: np.ndarray) -> np.ndarray:
        seen.append(rgb.shape)
        return left_half_person(rgb)

    result = BackgroundProvider(segmenter).process(jpeg_bytes(1600, 1200), {"mode": "remove"})
    assert seen == [(576, 768, 3)]
    assert decode(result.data).size == (1600, 1200)


def test_missing_model_disables_the_provider(tmp_path: Path) -> None:
    with pytest.raises(ProviderUnavailable):
        MediaPipeSegmenter(tmp_path / "missing.tflite")


@pytest.mark.skipif(not MODEL.is_file(), reason="model not fetched: run tools/fetch_models.sh")
def test_real_model_finds_nobody_in_a_flat_image() -> None:
    segment = MediaPipeSegmenter(MODEL)
    try:
        mask = segment(np.full((256, 256, 3), 128, dtype=np.uint8))
    finally:
        segment.close()
    assert mask.shape == (256, 256)
    assert mask.dtype == np.float32
    assert float(mask.mean()) < 0.01
