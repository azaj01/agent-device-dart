.PHONY: get analyze format test check clean compile compile-clean build-ios-runner

get:
	dart pub get

analyze:
	dart analyze

format:
	dart format .

test:
	dart test packages/agent_device

check: analyze test

# Build a standalone native binary at dist/agent-device. Side-by-side
# `ad` is a symlink so users can pick whichever spelling they prefer.
# Run `make compile` after every release; the binary embeds the SDK so
# it has no Dart-runtime dependency on the host.
compile:
	@mkdir -p dist
	dart compile exe packages/agent_device/bin/agent_device.dart -o dist/agent-device
	ln -sf agent-device dist/ad
	@echo "built: $$(pwd)/dist/agent-device  ($$(du -h dist/agent-device | cut -f1))"

compile-clean:
	rm -rf dist

# Rebuild the iOS XCUITest runner from source for the simulator.
#
# The CLI auto-builds the runner once and then reuses the cached products in
# `ios-runner/build/` — it does NOT rebuild when the Swift source changes. A
# stale cached runner is a real performance trap: it was measured driving the
# accessibility `snapshot` ~3.7x slower (~1600ms vs ~440ms) than a fresh build.
# Run this after editing anything under ios-runner/ (or if snapshots feel slow):
#
#   make build-ios-runner               # picks a booted simulator
#   make build-ios-runner UDID=<udid>   # target a specific simulator
build-ios-runner:
	@udid="$(UDID)"; \
	if [ -z "$$udid" ]; then \
		udid=$$(xcrun simctl list devices booted -j | python3 -c "import json,sys;d=json.load(sys.stdin);print(next((x['udid'] for r in d['devices'].values() for x in r if x.get('state')=='Booted'),''))"); \
	fi; \
	if [ -z "$$udid" ]; then echo "No booted simulator; boot one or pass UDID=<udid>"; exit 1; fi; \
	echo "Rebuilding iOS runner for simulator $$udid"; \
	rm -rf ios-runner/build; \
	xcodebuild build-for-testing \
		-project ios-runner/AgentDeviceRunner/AgentDeviceRunner.xcodeproj \
		-scheme AgentDeviceRunner \
		-destination "platform=iOS Simulator,id=$$udid" \
		-derivedDataPath ios-runner/build -quiet
	@echo "built iOS runner → ios-runner/build/Build/Products"

clean:
	rm -rf packages/*/.dart_tool packages/*/build .dart_tool dist
