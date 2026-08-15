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
  local token
  token="$(make_ghost_jwt "$key_id" "$key_secret")"

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

stream_content_payloads() {
  local content_type="$1"
  jq -c --arg content_type "$content_type" '
    .db[0].data as $data
    | ($data.tags // [] | map({key: (.id | tostring), value: .}) | from_entries) as $tags_by_id
    | ($data.authors // [] | map({key: (.id | tostring), value: .}) | from_entries) as $authors_by_id
    | ($data.posts // [])
    | map(select((.type // "post") == $content_type))
    | .[]
    | . as $post
    | {
        title: $post.title,
        slug: $post.slug,
        status: $post.status,
        visibility: $post.visibility,
        featured: (
          if ($post.featured | type) == "boolean" then
            $post.featured
          elif ($post.featured | type) == "number" then
            ($post.featured != 0)
          elif ($post.featured | type) == "string" then
            (($post.featured | ascii_downcase) == "true" or $post.featured == "1")
          else
            null
          end
        ),
        published_at: $post.published_at,
        custom_excerpt: $post.custom_excerpt,
        excerpt: $post.excerpt,
        feature_image: $post.feature_image,
        lexical: $post.lexical,
        mobiledoc: $post.mobiledoc,
        html: $post.html,
        tags: [
          ($data.posts_tags // [])[]
          | select((.post_id | tostring) == ($post.id | tostring))
          | (.tag_id | tostring) as $tag_id
          | $tags_by_id[$tag_id]
          | select(. != null)
          | {name: .name}
        ],
        authors: [
          ($data.posts_authors // [])[]
          | select((.post_id | tostring) == ($post.id | tostring))
          | (.author_id | tostring) as $author_id
          | $authors_by_id[$author_id]
          | select(. != null)
          | {email: .email}
        ]
      }
    | with_entries(select(.value != null))
  ' "$export_file"
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
require_command openssl
require_command jq

ghost_url="${ghost_url%/}"
api_base="$ghost_url/ghost/api/admin"

key_id="${admin_api_key%%:*}"
key_secret="${admin_api_key#*:}"

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
echo "Importing tags..."
tag_errors=0
while IFS= read -r tag_json; do
  tag_name="$(printf '%s' "$tag_json" | jq -r '.name')"
  body="{\"tags\":[$tag_json]}"
  if ! post_resource "tags" "$body" "tag '$tag_name'"; then
    tag_errors=$(( tag_errors + 1 ))
  fi
done < <(jq -c '.db[0].data.tags // [] | .[]' "$export_file")
if [[ "$tag_errors" -gt 0 ]]; then
  errors=$(( errors + tag_errors ))
fi

# Import posts (includes drafts)
echo "Importing posts..."
post_errors=0
while IFS= read -r post_json; do
  post_title="$(printf '%s' "$post_json" | jq -r '.title')"
  body="{\"posts\":[$post_json]}"
  if ! post_resource "posts" "$body" "post '$post_title'"; then
    post_errors=$(( post_errors + 1 ))
  fi
done < <(stream_content_payloads "post")
if [[ "$post_errors" -gt 0 ]]; then
  errors=$(( errors + post_errors ))
fi

# Import pages
echo "Importing pages..."
page_errors=0
while IFS= read -r page_json; do
  page_title="$(printf '%s' "$page_json" | jq -r '.title')"
  body="{\"pages\":[$page_json]}"
  if ! post_resource "pages" "$body" "page '$page_title'"; then
    page_errors=$(( page_errors + 1 ))
  fi
done < <(stream_content_payloads "page")
if [[ "$page_errors" -gt 0 ]]; then
  errors=$(( errors + page_errors ))
fi

if [[ "$errors" -gt 0 ]]; then
  echo "Ghost import completed with $errors error(s)." >&2
  exit 1
fi

echo "Ghost import completed successfully."
