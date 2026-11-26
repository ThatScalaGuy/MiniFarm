#!/bin/bash
set -euo pipefail

CDPATH='' cd "$(dirname "$0")/../.."
python3 -B -m unittest discover -s Tools/Validation -p 'test_*.py'

derived_data=$(mktemp -d "${TMPDIR:-/tmp}/MiniFarm-build.XXXXXXXX")
trap 'rm -rf -- "$derived_data"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Generate a reference project, never overwrite a developer's checkout.
spec_root="$derived_data/spec"
mkdir "$spec_root"
for input in project.yml App Configuration Tests UITests; do
  ln -s "$PWD/$input" "$spec_root/$input"
done
(cd "$spec_root" && xcodegen generate --quiet)
for metadata in project.pbxproj xcshareddata/xcschemes/MiniFarm.xcscheme; do
  if ! cmp -s "$spec_root/MiniFarm.xcodeproj/$metadata" "MiniFarm.xcodeproj/$metadata"; then
    echo "MiniFarm.xcodeproj is stale. Run xcodegen generate in the checkout." >&2
    exit 1
  fi
done

products="$derived_data/Build/Products/Release-iphonesimulator"
xcodebuild -quiet \
  -project MiniFarm.xcodeproj \
  -scheme MiniFarm \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$derived_data" \
  CONFIGURATION_BUILD_DIR="$products" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM= \
  build

app="$products/MiniFarm.app"
python3 Tools/Validation/check_bundle.py "$app"
