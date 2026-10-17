#!/usr/bin/env bash
# Build and upload an App Store release using an App Store Connect team API key.
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: ./scripts/release_ios.sh [--dry-run]

Defaults are loaded from scripts/release_ios.env when present.
Environment variables supplied by the caller override file values.

Required environment variables:
  ASC_KEY_PATH       Absolute path to the .p8 private key (kept outside the repo)
  ASC_KEY_ID         App Store Connect API key ID
  ASC_ISSUER_ID      App Store Connect issuer ID

Optional environment variables:
  APPLE_TEAM_ID      Signing team; defaults to ios/Config.xcconfig
  BUILD_NAME         App version; defaults to pubspec.yaml
  BUILD_NUMBER       Build number; defaults to pubspec.yaml suffix or 1
  RELEASE_OUTPUT_DIR Output directory; defaults to build/ios/releases/<timestamp>

Xcode manages the uploaded build number to avoid conflicts. --dry-run validates
configuration and prints the commands without building or uploading.
HELP
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
dry_run=false
case "${1:-}" in
  '') ;;
  --dry-run) dry_run=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || fail 'Only --dry-run or --help is supported.'
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
load_config() {
  local name index
  local names=(ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID APPLE_TEAM_ID BUILD_NAME BUILD_NUMBER RELEASE_OUTPUT_DIR)
  local saved_names=() saved_values=()
  for name in "${names[@]}"; do
    if [[ ${!name+x} ]]; then
      saved_names+=("$name")
      saved_values+=("${!name}")
    fi
  done
  if [[ -f "$project_dir/scripts/release_ios.env" ]]; then
    source "$project_dir/scripts/release_ios.env"
  fi
  for ((index = 0; index < ${#saved_names[@]}; index++)); do
    printf -v "${saved_names[index]}" '%s' "${saved_values[index]}"
  done
  # Metadata is read by Python, so file defaults must also be exported.
  for name in "${names[@]}"; do
    export "$name"
  done
}
load_config
[[ "$(uname -s)" == Darwin ]] || fail 'An iOS release requires macOS and Xcode.'
for tool in flutter xcodebuild python3; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required command is unavailable: $tool"
done
for name in ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID; do
  [[ -n "${!name:-}" ]] || fail "Set $name before running this script."
done
[[ "$ASC_KEY_PATH" = /* ]] || fail 'ASC_KEY_PATH must be an absolute path.'
[[ -r "$ASC_KEY_PATH" && -f "$ASC_KEY_PATH" ]] || fail 'ASC_KEY_PATH must point to a readable .p8 file.'
[[ "$ASC_KEY_ID" =~ ^[A-Za-z0-9]+$ ]] || fail 'ASC_KEY_ID must contain only letters and digits.'
[[ "$ASC_ISSUER_ID" =~ ^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$ ]] || fail 'ASC_ISSUER_ID must be a UUID.'

cd "$project_dir"
# Read metadata without sourcing files as executable shell code.
metadata="$(python3 - <<'PY'
import os, pathlib, re
text = pathlib.Path('pubspec.yaml').read_text()
match = re.search(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9.]+))?', text, re.M)
if not match:
    raise SystemExit('Cannot read version from pubspec.yaml')
team = os.environ.get('APPLE_TEAM_ID', '')
config = pathlib.Path('ios/Config.xcconfig')
if not team and config.is_file():
    found = re.search(r'^\s*DEVELOPMENT_TEAM\s*=\s*([A-Za-z0-9]+)', config.read_text(), re.M)
    if found:
        team = found.group(1)
print(match.group(1), match.group(2) or '1', team)
PY
)"
read -r pubspec_version pubspec_build signing_team <<< "$metadata"
build_name="${BUILD_NAME:-$pubspec_version}"
build_number="${BUILD_NUMBER:-$pubspec_build}"
[[ "$build_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'BUILD_NAME must have the form 1.6.0.'
[[ "$build_number" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || fail 'BUILD_NUMBER must have one to three numeric components.'
[[ "$signing_team" =~ ^[A-Za-z0-9]{10}$ && "$signing_team" != YOUR_TEAM_ID ]] || fail 'Set APPLE_TEAM_ID or DEVELOPMENT_TEAM in ios/Config.xcconfig.'

output_dir="${RELEASE_OUTPUT_DIR:-$project_dir/build/ios/releases/$(date +%Y%m%d-%H%M%S)-$$}"
[[ "$output_dir" = /* ]] || output_dir="$project_dir/$output_dir"
# Never overwrite an earlier archive, IPA or upload log.
mkdir -p "$(dirname "$output_dir")"
mkdir "$output_dir" || fail 'RELEASE_OUTPUT_DIR already exists; choose a new directory.'
archive_path="$output_dir/Runner.xcarchive"
python3 - "$output_dir" "$signing_team" <<'PY'
import pathlib, plistlib, sys
root, team = pathlib.Path(sys.argv[1]), sys.argv[2]
for destination in ('export', 'upload'):
    options = {'method': 'app-store-connect', 'destination': destination,
               'signingStyle': 'automatic', 'teamID': team,
               'uploadSymbols': True, 'manageAppVersionAndBuildNumber': True}
    (root / f'{destination}.plist').write_bytes(plistlib.dumps(options))
PY

auth_args=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)
run_step() {
  local step="$1"
  shift
  printf '\n== %s ==\n' "$step"
  if "$dry_run"; then
    printf '%q ' "$@"
    printf '\n'
  else
    if ! "$@" 2>&1 | tee "$output_dir/$step.log"; then
      fail "$step failed. See $output_dir/$step.log. No subsequent step was run."
    fi
  fi
}

printf 'Release: %s (%s), team %s\nOutput: %s\n' "$build_name" "$build_number" "$signing_team" "$output_dir"
# Flutter prepares plugins, CocoaPods and generated build settings. The actual
# archive and both exports explicitly authenticate with the API key.
run_step configure flutter build ios --release --config-only \
  "--build-name=$build_name" "--build-number=$build_number"
run_step archive xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" "${auth_args[@]}" \
  "DEVELOPMENT_TEAM=$signing_team" archive
run_step export xcodebuild -exportArchive -archivePath "$archive_path" \
  -exportOptionsPlist "$output_dir/export.plist" -exportPath "$output_dir/ipa" \
  "${auth_args[@]}"
run_step upload xcodebuild -exportArchive -archivePath "$archive_path" \
  -exportOptionsPlist "$output_dir/upload.plist" -exportPath "$output_dir/upload" \
  "${auth_args[@]}"

if "$dry_run"; then
  printf '\nDry run completed. No build or upload was performed.\n'
else
  printf '\nUpload accepted by App Store Connect. Apple still needs to process the build.\nIPA: %s/ipa\nArchive and logs: %s\n' "$output_dir" "$output_dir"
fi
