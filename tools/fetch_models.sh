#!/usr/bin/env bash
# Downloads the MediaPipe models and verifies each against tools/models.sha256.
#   face_landmarker.task     -> yuz_beauty_engine Android assets + iOS resources
#   selfie_segmenter.tflite  -> services/ai-worker/models
# Both are Google MediaPipe models published under Apache-2.0 model cards.
#
# Usage: tools/fetch_models.sh [face|segmenter|all]   (default: all)
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CHECKSUM_FILE="${ROOT_DIR}/tools/models.sha256"
readonly ENGINE_DIR="${ROOT_DIR}/packages/yuz_beauty_engine"
readonly MP_MODELS="https://storage.googleapis.com/mediapipe-models"

# fetch_model <name> <url> <target...>: reuses the first target when its checksum already matches.
fetch_model() {
  local name="$1" url="$2"
  shift 2
  local expected_sha
  expected_sha="$(awk -v n="${name}" '$2 == n { print $1 }' "${CHECKSUM_FILE}")"
  if [[ -z "${expected_sha}" ]]; then
    echo "error: no checksum for ${name} in ${CHECKSUM_FILE}" >&2
    return 1
  fi

  local tmp_file
  tmp_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '${tmp_file}'" RETURN

  if [[ -f "$1" ]] && [[ "$(sha256sum "$1" | awk '{print $1}')" == "${expected_sha}" ]]; then
    cp "$1" "${tmp_file}"
  else
    curl --fail --silent --show-error --location --retry 3 --output "${tmp_file}" "${url}"
  fi

  local actual_sha
  actual_sha="$(sha256sum "${tmp_file}" | awk '{print $1}')"
  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    echo "error: checksum mismatch for ${name}" >&2
    echo "  expected ${expected_sha}" >&2
    echo "  actual   ${actual_sha}" >&2
    return 1
  fi

  local target
  for target in "$@"; do
    mkdir -p "$(dirname "${target}")"
    cp "${tmp_file}" "${target}"
  done
  echo "${name} verified (${actual_sha})"
}

fetch_face() {
  fetch_model face_landmarker.task \
    "${MP_MODELS}/face_landmarker/face_landmarker/float16/1/face_landmarker.task" \
    "${ENGINE_DIR}/android/src/main/assets/yuz_beauty_engine/models/face_landmarker.task" \
    "${ENGINE_DIR}/ios/Resources/face_landmarker.task"
}

fetch_segmenter() {
  fetch_model selfie_segmenter.tflite \
    "${MP_MODELS}/image_segmenter/selfie_segmenter/float16/1/selfie_segmenter.tflite" \
    "${ROOT_DIR}/services/ai-worker/models/selfie_segmenter.tflite"
}

case "${1:-all}" in
  face) fetch_face ;;
  segmenter) fetch_segmenter ;;
  all) fetch_face && fetch_segmenter ;;
  *)
    echo "usage: $0 [face|segmenter|all]" >&2
    exit 2
    ;;
esac
