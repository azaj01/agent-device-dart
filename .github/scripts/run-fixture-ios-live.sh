#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
video_dir="${FIXTURE_ARTIFACT_DIR:?}/videos"
udid="${FIXTURE_IOS_UDID:?}"

mkdir -p "$video_dir" "${AGENT_DEVICE_STATE_DIR:?}"
cd "$repo_root"

compress_video() {
  local raw="$1"
  local out="$2"
  if [[ ! -f "$raw" ]]; then return; fi
  ffmpeg -y -i "$raw" \
    -c:v libx264 -crf 22 -preset fast -profile:v main -level 4.0 \
    -pix_fmt yuv420p \
    -vf "fps=min(30\\,source_fps)" \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    "$out" || true
  if [[ -f "$out" ]]; then rm -f "$raw"; fi
}

# Retry a command a few times, sleeping between attempts. CI simulators are
# slow on first touch, so a single transient failure shouldn't fail the job.
retry() {
  local max="$1"; shift
  local n=1
  until "$@"; do
    local rc=$?
    if [ "$n" -ge "$max" ]; then
      echo "::warning::command failed after ${max} attempts (rc=${rc}): $*" >&2
      return "$rc"
    fi
    echo "attempt ${n}/${max} failed (rc=${rc}), retrying in 5s: $*" >&2
    n=$((n + 1)); sleep 5
  done
}

# Pre-warm the app launch OUTSIDE ad's 30s xcrun timeout. The first cold launch
# of a freshly-installed app on a just-booted CI simulator can exceed 30s
# (dyld/SpringBoard warmup), which is what makes `ad open` time out with
# "xcrun timed out after 30000ms". A direct simctl launch has no such cap and
# is a fast no-op once the app is already foreground.
retry 5 xcrun simctl launch "$udid" com.example.agentDeviceFixtureApp || true

retry 3 dart run packages/agent_device/bin/agent_device.dart open com.example.agentDeviceFixtureApp --session fixture-ios-ci --platform ios --serial "$udid" --json
retry 3 dart run packages/agent_device/bin/agent_device.dart snapshot --session fixture-ios-ci --platform ios --serial "$udid" --json

# TestRecorder inside the Dart test handles record start/stop + chapter
# markers. AD_RECORD_TESTS tells it where to write the raw MP4.
test_exit=0
AGENT_DEVICE_FIXTURE_IOS_LIVE=1 \
AGENT_DEVICE_FIXTURE_IOS_UDID="$udid" \
AD_RECORD_TESTS="$video_dir" \
dart test packages/agent_device/test/platforms/ios/fixture_app_live_test.dart || test_exit=$?

# Compress the chaptered recording for upload (regardless of test result).
compress_video "$video_dir/fixture-ios.mp4" "$video_dir/fixture-ios-compressed.mp4"

exit "$test_exit"
