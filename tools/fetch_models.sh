#!/usr/bin/env bash
# Downloads the MediaPipe Face Landmarker model into the Android assets and
# iOS resources of yuz_beauty_engine and verifies its SHA-256.
# Model: Google MediaPipe face_landmarker (float16, v1), Apache-2.0 model card.
set -euo pipefail

readonly MODEL_URL="https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ENGINE_DIR="${ROOT_DIR}/packages/yuz_beauty_engine"
readonly CHECKSUM_FILE="${ROOT_DIR}/tools/models.sha256"
readonly ANDROID_TARGET="${ENGINE_DIR}/android/src/main/assets/yuz_beauty_engine/models/face_landmarker.task"
readonly IOS_TARGET="${ENGINE_DIR}/ios/Resources/face_landmarker.task"

expected_sha="$(awk '$2 == "face_landmarker.task" { print $1 }' "${CHECKSUM_FILE}")"
if [[ -z "${expected_sha}" ]]; then
  echo "error: no checksum for face_landmarker.task in ${CHECKSUM_FILE}" >&2
  exit 1
fi

tmp_file="$(mktemp)"
trap 'rm -f "${tmp_file}"' EXIT

if [[ -f "${ANDROID_TARGET}" ]] && [[ "$(sha256sum "${ANDROID_TARGET}" | awk '{print $1}')" == "${expected_sha}" ]]; then
  cp "${ANDROID_TARGET}" "${tmp_file}"
else
  curl --fail --silent --show-error --location --retry 3 --output "${tmp_file}" "${MODEL_URL}"
fi

actual_sha="$(sha256sum "${tmp_file}" | awk '{print $1}')"
if [[ "${actual_sha}" != "${expected_sha}" ]]; then
  echo "error: checksum mismatch for face_landmarker.task" >&2
  echo "  expected ${expected_sha}" >&2
  echo "  actual   ${actual_sha}" >&2
  exit 1
fi

mkdir -p "$(dirname "${ANDROID_TARGET}")" "$(dirname "${IOS_TARGET}")"
cp "${tmp_file}" "${ANDROID_TARGET}"
cp "${tmp_file}" "${IOS_TARGET}"
echo "face_landmarker.task verified (${actual_sha})"
