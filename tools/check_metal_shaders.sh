#!/usr/bin/env bash
# Compiles the runtime Metal source embedded in BeautyShaders.swift with the
# real Metal compiler (macOS + Xcode only). The engine compiles this source at
# runtime, so without this check a kernel error would only surface on device.
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SWIFT_FILE="${ROOT_DIR}/packages/yuz_beauty_engine/ios/Classes/Render/BeautyShaders.swift"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

# Extract the text between `static let source = """` and the closing `"""`.
awk '/static let source = """/{inside=1; next} inside && /^[[:space:]]*"""/{exit} inside{print}' \
  "${SWIFT_FILE}" > "${work_dir}/BeautyShaders.metal"

if [[ ! -s "${work_dir}/BeautyShaders.metal" ]]; then
  echo "error: could not extract Metal source from ${SWIFT_FILE}" >&2
  exit 1
fi

xcrun -sdk iphoneos metal -std=ios-metal2.4 -Werror -c "${work_dir}/BeautyShaders.metal" -o "${work_dir}/BeautyShaders.air"
xcrun -sdk iphoneos metallib "${work_dir}/BeautyShaders.air" -o "${work_dir}/BeautyShaders.metallib"
echo "Metal kernels compiled: $(wc -l < "${work_dir}/BeautyShaders.metal") lines"
