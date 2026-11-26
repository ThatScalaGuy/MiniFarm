#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: sh Tools/test_simulators.sh <iPhone-simulator-UDID> <iPad-simulator-UDID>' >&2
    exit 2
fi
cd "$(dirname "$0")/.."
mkdir -p build
output=$(mktemp -d build/qa.XXXXXX)
xcodegen generate
printf 'QA evidence: %s\n' "$output"

run_tests() {
    xcodebuild -project MiniFarm.xcodeproj -scheme MiniFarm \
        -destination "id=$1" -derivedDataPath build/DerivedData \
        -parallel-testing-enabled NO -resultBundlePath "$output/$2.xcresult" \
        "$3" >"$output/$2.log" 2>&1 || {
            tail -n 60 "$output/$2.log" >&2
            return 1
        }
    xcrun xcresulttool get test-results summary --path "$output/$2.xcresult" >"$output/$2.json"
    python3 Tools/verify_first_harvest.py "$1" >"$output/$2-harvest.json"
    xcrun xcresulttool export attachments --path "$output/$2.xcresult" \
        --test-id 'FarmJourneyTests/testFirstHarvestAndRestoredStep()' \
        --output-path "$output/$2-images"
}

run_tests "$1" iPhone test
run_tests "$2" iPad test-without-building
python3 Tools/verify_bundle.py build/DerivedData/Build/Products/Debug-iphonesimulator/MiniFarm.app
