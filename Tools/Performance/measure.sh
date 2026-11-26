#!/bin/bash
# Bounded, repeatable performance QA for the integrated MiniFarm host (Doc 15 §10, Doc 20 §4).
# Measures: unsigned Release .app size, cold start to the first operable view on a private iOS
# Simulator, overview-to-place switches on an injected and labelled QA farm, and the world
# projection on the fully unlocked QA farm. Simulator timings on a shared Mac are no device fps,
# battery or CI thresholds. Nothing is signed, uploaded or written into the checkout.
#
#   Tools/Performance/measure.sh                 # all steps, 5 samples
#   MINIFARM_PERF_SAMPLES=3 MINIFARM_PERF_OUT=/tmp/perf Tools/Performance/measure.sh
#   MINIFARM_PERF_STEPS="size projection" Tools/Performance/measure.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
root=$PWD
samples=${MINIFARM_PERF_SAMPLES:-5}
steps=${MINIFARM_PERF_STEPS:-"size projection simulator"}
device_name=${MINIFARM_PERF_DEVICE:-iPhone 17}
work=$(mktemp -d "${TMPDIR:-/tmp}/MiniFarm-perf.XXXXXXXX")
out=${MINIFARM_PERF_OUT:-$work/results}
mkdir -p "$out"
udid=""
cleanup() {
    if [[ -n $udid ]]; then
        xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
        xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    fi
    if [[ -z ${MINIFARM_PERF_OUT:-} ]]; then rm -rf -- "$work"; else rm -rf -- "$work/dd" "$work/spec" "$work/qafarm"; fi
}
trap cleanup EXIT
emit() { echo "MINIFARM_PERF $1" | tee -a "$out/context.log"; }
has() { [[ " $steps " == *" $1 "* ]]; }

commit=$(git rev-parse --short HEAD)
dirty=$([[ -z $(git status --porcelain --untracked-files=no) ]] && echo false || echo true)
xcode=$(xcodebuild -version | tr '\n' ' ' | sed 's/ *$//')
load=$(sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1}')
emit "{\"metric\":\"context\",\"commit\":\"$commit\",\"dirty\":$dirty,\"xcode\":\"$xcode\",\"mac\":\"$(sysctl -n hw.model)\",\"cpus\":$(sysctl -n hw.ncpu),\"loadAverage\":$load}"

if has size; then
    # Unthinned arm64 device build without signing; App Store thinning and encryption change this.
    products="$work/dd/device/Build/Products/Release-iphoneos"
    xcodebuild -quiet -project MiniFarm.xcodeproj -scheme MiniFarm -configuration Release \
        -destination 'generic/platform=iOS' -derivedDataPath "$work/dd/device" \
        CONFIGURATION_BUILD_DIR="$products" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= build
    app="$products/MiniFarm.app"
    ditto -c -k --keepParent "$app" "$work/MiniFarm.zip"
    python3 - "$app" "$work/MiniFarm.zip" <<'EOF' | tee -a "$out/context.log"
import json, os, sys
app, archive = sys.argv[1], sys.argv[2]
def size(path):
    if os.path.isfile(path): return os.path.getsize(path)
    return sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(path) for f in fs)
parts = {name: size(os.path.join(app, name)) for name in ("MiniFarm", "Models", "Audio", "Content", "Assets.car")}
files = sum(len(fs) for _, _, fs in os.walk(app))
total = size(app)
print("MINIFARM_PERF " + json.dumps({"metric": "appSize", "unit": "bytes", "total": total, "files": files,
      "zip": os.path.getsize(archive), "other": total - sum(parts.values()), **parts}, sort_keys=True))
EOF
fi

qafarm="$work/qafarm"
if has projection || has simulator; then
    # The QA tool links the app's own platform-neutral gameplay and storage sources on macOS.
    xcrun swiftc -O -swift-version 6 -target arm64-apple-macos15 -module-name MiniFarmQA -o "$qafarm" \
        App/Gameplay/*.swift App/Family/Storage/*.swift App/Family/Model/*.swift App/Family/Store/SessionTimer.swift \
        App/Host/FarmWorldBridge.swift App/World/FarmWorldState.swift App/World/WorldLayout.swift \
        App/World/FarmDriveWork.swift App/World/WorldVignette.swift App/Art/Rituals/FarmStory.swift \
        Tools/Performance/QAFarm/main.swift
fi
if has projection; then
    "$qafarm" projection App/Resources/Content 300 | tee -a "$out/context.log"
fi

if has simulator; then
    spec="$work/spec"
    mkdir -p "$spec"
    for item in project.yml App Configuration Tests UITests; do ln -s "$root/$item" "$spec/$item"; done
    ln -s "$root/Tools/Performance/UITests" "$spec/PerformanceUITests"
    cp Tools/Performance/project.yml "$spec/performance.yml"
    (cd "$spec" && xcodegen generate --quiet --spec performance.yml)

    read -r runtime device_type < <(xcrun simctl list -j runtimes | python3 -c '
import json, sys
wanted = sys.argv[1]
choices = [(r, t) for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]
           for t in r.get("supportedDeviceTypes", []) if t["name"] == wanted]
if not choices:
    sys.exit(f"no available iOS runtime supports {wanted}")
runtime, kind = max(choices, key=lambda c: [int(p) for p in c[0]["version"].split(".")])
print(runtime["identifier"], kind["identifier"])' "$device_name")
    udid=$(xcrun simctl create "MiniFarm-Perf-$$" "$device_type" "$runtime")
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b >/dev/null
    emit "{\"metric\":\"simulator\",\"runtime\":\"$runtime\",\"deviceType\":\"$device_type\"}"

    xcodebuild -quiet -project "$spec/MiniFarmPerformance.xcodeproj" -scheme MiniFarmPerformance -configuration Release \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath "$work/dd/sim" CODE_SIGNING_ALLOWED=NO build-for-testing
    xctestrun=$(ls "$work"/dd/sim/Build/Products/*.xctestrun)
    run() {  # run <log name> <scenario> <test>…
        local name=$1 scenario=$2; shift 2
        local only=()
        for test in "$@"; do only+=("-only-testing:MiniFarmPerformanceUITests/LaunchAndPlaceTimingTests/$test"); done
        TEST_RUNNER_MINIFARM_PERF_SCENARIO=$scenario TEST_RUNNER_MINIFARM_PERF_SAMPLES=$samples \
            xcodebuild test-without-building -xctestrun "$xctestrun" -destination "id=$udid" \
            -resultBundlePath "$out/$name.xcresult" "${only[@]}" >"$out/$name.log" 2>&1 \
            || echo "warning: $name had failing tests, see $out/$name.xcresult" >&2
    }

    # Fresh install: no family exists yet, the first operable control is the setup button.
    run fresh fresh testColdLaunchToOperablePicker

    # The labelled QA farm (profile "Kaninchen", level 5, all places) is written through the
    # app's own FamilyStorage into this private simulator only. Production setup stays untouched.
    container=$(xcrun simctl get_app_container "$udid" de.thatscalaguy.minifarm data)
    "$qafarm" farm App/Resources/Content "$container/Library/Application Support/MiniFarm/Family" | tee -a "$out/context.log"
    run qa qa testColdLaunchToOperablePicker testSystemLaunchMetric testOverviewToPlaceOnQAFarm
fi

echo "== MiniFarm performance QA ($commit, results in $out)"
python3 -B Tools/Performance/summarize.py "$out"/*.log
