#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

env_file="${COOKBUK_ENV_FILE:-.env}"
json_config_file="${COOKBUK_CONFIG_FILE:-cookbuk.local.json}"

if [[ -f "$env_file" ]]; then
  config_arg=(--dart-define-from-file="$env_file")
elif [[ -f "$json_config_file" ]]; then
  config_arg=(--dart-define-from-file="$json_config_file")
else
  cat >&2 <<MSG
Missing $env_file.

Create it once:
  cp .env.example .env

Then edit the URL/token in .env and run this again.
MSG
  exit 1
fi

flutter run "${config_arg[@]}" "$@"
