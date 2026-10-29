# syntax=docker/dockerfile:1.7
# Yuz AI worker. Build:  docker build -t yuz-ai-worker services/ai-worker
FROM python:3.13.17-slim-bookworm AS runtime

# MediaPipe's CPU runtime links against EGL/GLES even without a GPU.
RUN apt-get update \
  && apt-get install -y --no-install-recommends libegl1 libgles2 libgl1 libglib2.0-0 curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Kept in sync with tools/models.sha256 (enforced by tests/test_model_pin.py).
ARG SEGMENTER_URL=https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/1/selfie_segmenter.tflite
ARG SEGMENTER_SHA256=191ac9529ae506ee0beefa6b2c945a172dab9d07d1e802a290a4e4038226658b
RUN mkdir -p /opt/yuz/models \
  && curl --fail --silent --show-error --location --retry 3 -o /opt/yuz/models/selfie_segmenter.tflite "${SEGMENTER_URL}" \
  && echo "${SEGMENTER_SHA256}  /opt/yuz/models/selfie_segmenter.tflite" | sha256sum -c -

WORKDIR /app
COPY requirements.lock ./
RUN pip install --no-cache-dir -r requirements.lock
COPY pyproject.toml ./
COPY yuz_worker ./yuz_worker
RUN pip install --no-cache-dir --no-deps .

# Same uid as the API's "node" user: both read and write the 0600 files on the shared volume.
RUN useradd --uid 1000 --create-home --shell /usr/sbin/nologin worker
USER worker
ENV MODEL_DIR=/opt/yuz/models PYTHONUNBUFFERED=1
CMD ["yuz-ai-worker"]
