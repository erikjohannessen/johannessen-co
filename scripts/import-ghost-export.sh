#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  import-ghost-export.sh \
    --ghost-url https://blog.example.com \
    --export-file /path/to/ghost_export.json \
    --admin-api-key '<id:secret>' [--insecure]

Description:
  Imports a Ghost export JSON file using the Ghost Admin API JWT authentication.
  The admin API key should be an Admin API key in the format 'id:secret',
  obtainable from Ghost Admin > Settings > Integrations > Add custom integration.
USAGE
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

# Build a Ghost Admin API JWT token from an 'id:secret' key.
# Ghost uses a non-standard JWT: HS256, kid=id, iat/exp claims only.
make_ghost_jwt() {
  local key_id="$1"
  local key_secret_hex="$2"

  local now
  now="$(date +%s)"
  local exp=$(( now + 300 ))

  local header
  header="$(printf '{"alg":"HS256","typ":"JWT","kid":"%s"}' "$key_id" | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
  local payload
  payload="$(printf '{"iat":%d,"exp":%d,"aud":"/admin/"}' "$now" "$exp" | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"

  local signing_input="${header}.${payload}"

  # Convert hex secret to binary for HMAC-SHA256
  local sig
  sig="$(printf '%s' "$signing_input" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${key_secret_hex}" -binary | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"

  printf '%s.%s.%s' "$header" "$payload" "$sig"
}

ghost_url=""
export_file=""
admin_api_key=""
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
    --admin-api-key)
      admin_api_key="$2"
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

if [[ -z "$ghost_url" || -z "$export_file" || -z "$admin_api_key" ]]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

if [[ ! -f "$export_file" ]]; then
  echo "Export file not found: $export_file" >&2
  exit 1
fi

if [[ "$admin_api_key" != *:* ]]; then
  echo "Invalid --admin-api-key format; expected 'id:secret'" >&2
  exit 1
fi

require_command curl
require_command jq
require_command openssl

ghost_url="${ghost_url%/}"
api_base="$ghost_url/ghost/api/admin"

key_id="${admin_api_key%%:*}"
key_secret="${admin_api_key#*:}"

token="$(make_ghost_jwt "$key_id" "$key_secret")"

tmp_dir="$(mktemp -d)"
import_response="$tmp_dir/import_response.json"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

curl_flags=(--silent --show-error --location)
if [[ "$insecure" == "true" ]]; then
  curl_flags+=(--insecure)
fi

echo "Importing export file: $export_file"

import_status="$(
  curl "${curl_flags[@]}" \
    --output "$import_response" \
    --write-out '%{http_code}' \
    --header "Authorization: Ghost $token" \
    --header 'Accept-Version: v6.0' \
    --header "Origin: $ghost_url" \
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
