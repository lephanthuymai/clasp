#!/bin/bash

set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
distribution_directory="$repository_root/dist"
application_path="$distribution_directory/Clasp.app"
contents_path="$application_path/Contents"
macos_path="$contents_path/MacOS"
resources_path="$contents_path/Resources"

if [[ -f "$repository_root/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$repository_root/.env"
    set +a
fi

swift build --package-path "$repository_root" -c release
binary_directory="$(swift build --package-path "$repository_root" -c release --show-bin-path)"

mkdir -p "$macos_path" "$resources_path"
install -m 755 "$binary_directory/ClaspApp" "$macos_path/ClaspApp"
install -m 644 "$repository_root/Resources/Info.plist" "$contents_path/Info.plist"
if [[ -n "${CLASP_DEFAULT_CODEX_WORKSPACE_PATH:-}" ]]; then
    plutil -insert ClaspDefaultCodexWorkspacePath \
        -string "$CLASP_DEFAULT_CODEX_WORKSPACE_PATH" \
        "$contents_path/Info.plist"
fi
install -m 644 "$repository_root/Resources/Brand/ClaspLogo-v4.png" \
    "$resources_path/ClaspLogo.png"
install -m 644 "$repository_root/Resources/Brand/BreakBreathingCat-Mochi.png" \
    "$resources_path/BreakBreathingCat-Mochi.png"
install -m 644 "$repository_root/Resources/Clasp.icns" \
    "$resources_path/Clasp.icns"

codesign_identity="${CLASP_CODESIGN_IDENTITY:--}"
if [[ "$codesign_identity" == "-" ]]; then
    codesign \
        --force \
        --deep \
        --sign - \
        --requirements '=designated => identifier "com.clasp.app"' \
        "$application_path"
else
    codesign --force --deep --sign "$codesign_identity" "$application_path"
fi

echo "$application_path"
