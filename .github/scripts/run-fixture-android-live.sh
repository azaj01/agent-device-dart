#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
video_dir="${FIXTURE_ARTIFACT_DIR:?}/videos"

mkdir -p "$video_dir" "${AGENT_DEVICE_STATE_DIR:?}"
cd "$repo_root"

compress_video() {
  local raw="$1"
  local out="$2"
  if [[ ! -f "$raw" ]]; then return; fi
  ffmpeg -y -i "$raw" \
    -c:v libx264 -crf 22 -preset fast -profile:v main -level 4.0 \
    -vf "fps=min(30\\,source_fps)" \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    "$out" || true
  if [[ -f "$out" ]]; then rm -f "$raw"; fi
}

cd test_apps/agent_device_fixture_app
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
cd "$repo_root"

# Disable stylus handwriting overlay — it intercepts adb input text on
# API 36+ emulators and corrupts fill/type commands.
adb -s emulator-5554 shell settings put secure stylus_handwriting_enabled 0 || true

dart run packages/agent_device/bin/agent_device.dart open com.example.agent_device_fixture_app --session fixture-android-ci --platform android --serial emulator-5554 --json
dart run packages/agent_device/bin/agent_device.dart snapshot --session fixture-android-ci --platform android --serial emulator-5554 --json

# TestRecorder inside the Dart test handles record start/stop + chapter
# markers. AD_RECORD_TESTS tells it where to write the raw MP4.
test_exit=0
AGENT_DEVICE_FIXTURE_ANDROID_LIVE=1 \
AGENT_DEVICE_FIXTURE_ANDROID_SERIAL=emulator-5554 \
AD_RECORD_TESTS="$video_dir" \
dart test packages/agent_device/test/platforms/android/fixture_app_live_test.dart || test_exit=$?

# Compress the chaptered recording for upload (regardless of test result).
compress_video "$video_dir/fixture-android.mp4" "$video_dir/fixture-android-compressed.mp4"

exit "$test_exit"
