#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  import-ghost-export.sh \
    --ghost-url https://blog.example.com \
    --export-file /path/to/ghost_export.json \
    --admin-email admin@example.com \
    --admin-password '<password>' [--insecure]

Description:
  Imports a Ghost export JSON file using the Ghost Admin API session flow.
USAGE
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

ghost_url=""
export_file=""
admin_email=""
admin_password=""
insecure="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ghost-url)
      ghost_url="$2"
      shift 2
      ;;
    --export-file)
      export_file="$2"
      shift 2
      ;;
    --admin-email)
      admin_email="$2"
      shift 2
      ;;
    --admin-password)
      admin_password="$2"
      shift 2
      ;;
    --insecure)
      insecure="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ghost_url" || -z "$export_file" || -z "$admin_email" || -z "$admin_password" ]]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

if [[ ! -f "$export_file" ]]; then
  echo "Export file not found: $export_file" >&2
  exit 1
fi

require_command curl
require_command jq

ghost_url="${ghost_url%/}"
api_base="$ghost_url/ghost/api/admin"

tmp_dir="$(mktemp -d)"
cookie_jar="$tmp_dir/cookies.txt"
login_response="$tmp_dir/login_response.json"
import_response="$tmp_dir/import_response.json"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

curl_flags=(--silent --show-error --location)
if [[ "$insecure" == "true" ]]; then
  curl_flags+=(--insecure)
fi

echo "Logging into Ghost Admin API at $ghost_url"

login_payload="$(jq -n --arg username "$admin_email" --arg password "$admin_password" '{username: $username, password: $password}')"

login_status="$(
  curl "${curl_flags[@]}" \
    --output "$login_response" \
    --write-out '%{http_code}' \
    --cookie-jar "$cookie_jar" \
    --header 'Content-Type: application/json' \
    --header 'Accept-Version: v6.0' \
    --header "Origin: $ghost_url" \
    --header "Referer: $ghost_url/ghost/" \
    --request POST \
    --data "$login_payload" \
    "$api_base/session/"
)"

if [[ "$login_status" -lt 200 || "$login_status" -gt 299 ]]; then
  echo "Ghost Admin login failed with HTTP $login_status" >&2
  cat "$login_response" >&2
  exit 1
fi

echo "Importing export file: $export_file"

import_status="$(
  curl "${curl_flags[@]}" \
    --output "$import_response" \
    --write-out '%{http_code}' \
    --cookie "$cookie_jar" \
    --header 'Accept-Version: v6.0' \
    --header "Origin: $ghost_url" \
    --header "Referer: $ghost_url/ghost/" \
    --request POST \
    --form "importfile=@${export_file};type=application/json" \
    "$api_base/db/"
)"

if [[ "$import_status" -lt 200 || "$import_status" -gt 299 ]]; then
  echo "Ghost import failed with HTTP $import_status" >&2
  cat "$import_response" >&2
  exit 1
fi

echo "Ghost import completed successfully."
