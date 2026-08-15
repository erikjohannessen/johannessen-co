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
  Imports a Ghost export JSON file using individual Ghost Admin API endpoints
  (tags, posts, pages). These endpoints are available to custom integrations
  and do not require a privileged staff account.

  The admin API key should be in the format 'id:secret', obtainable from
  Ghost Admin > Settings > Integrations > Add custom integration.
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

# POST a single resource to the Admin API.
# Arguments: endpoint_path json_body resource_label
post_resource() {
  local endpoint="$1"
  local body="$2"
  local label="$3"

  local response_file="$tmp_dir/response.json"
  local status
  status="$(
    curl "${curl_flags[@]}" \
      --output "$response_file" \
      --write-out '%{http_code}' \
      --header "Authorization: Ghost $token" \
      --header 'Accept-Version: v6.0' \
      --header 'Content-Type: application/json' \
      --header "Origin: $ghost_url" \
      --request POST \
      --data "$body" \
      "$api_base/$endpoint/"
  )"

  if [[ "$status" -lt 200 || "$status" -gt 299 ]]; then
    echo "  Failed to import $label (HTTP $status)" >&2
    cat "$response_file" >&2
    echo >&2
    return 1
  fi
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

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

curl_flags=(--silent --show-error --location)
if [[ "$insecure" == "true" ]]; then
  curl_flags+=(--insecure)
fi

echo "Importing export file: $export_file"

errors=0

# Import tags
tag_count="$(jq '[.db[0].data.tags // [] | .[] ] | length' "$export_file")"
if [[ "$tag_count" -gt 0 ]]; then
  echo "Importing $tag_count tag(s)..."
  for i in $(seq 0 $(( tag_count - 1 ))); do
    tag_json="$(jq -c "{tags: [.db[0].data.tags[$i]]}" "$export_file")"
    tag_name="$(jq -r ".db[0].data.tags[$i].name" "$export_file")"
    if ! post_resource "tags" "$tag_json" "tag '$tag_name'"; then
      errors=$(( errors + 1 ))
    fi
  done
fi

# Import posts (includes drafts)
post_count="$(jq '[.db[0].data.posts // [] | .[] | select(.type == "post" or .type == null)] | length' "$export_file")"
if [[ "$post_count" -gt 0 ]]; then
  echo "Importing $post_count post(s)..."
  for i in $(seq 0 $(( post_count - 1 ))); do
    post_json="$(jq -c "{posts: [([.db[0].data.posts // [] | .[] | select(.type == \"post\" or .type == null)][$i])]}" "$export_file")"
    post_title="$(jq -r "([.db[0].data.posts // [] | .[] | select(.type == \"post\" or .type == null)][$i].title)" "$export_file")"
    if ! post_resource "posts" "$post_json" "post '$post_title'"; then
      errors=$(( errors + 1 ))
    fi
  done
fi

# Import pages
page_count="$(jq '[.db[0].data.posts // [] | .[] | select(.type == "page")] | length' "$export_file")"
if [[ "$page_count" -gt 0 ]]; then
  echo "Importing $page_count page(s)..."
  for i in $(seq 0 $(( page_count - 1 ))); do
    page_json="$(jq -c "{pages: [([.db[0].data.posts // [] | .[] | select(.type == \"page\")][$i])]}" "$export_file")"
    page_title="$(jq -r "([.db[0].data.posts // [] | .[] | select(.type == \"page\")][$i].title)" "$export_file")"
    if ! post_resource "pages" "$page_json" "page '$page_title'"; then
      errors=$(( errors + 1 ))
    fi
  done
fi

if [[ "$errors" -gt 0 ]]; then
  echo "Ghost import completed with $errors error(s)." >&2
  exit 1
fi

echo "Ghost import completed successfully."
