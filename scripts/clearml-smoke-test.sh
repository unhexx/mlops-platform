#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-deploy/clearml/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: environment file not found: $ENV_FILE" >&2
  exit 1
fi

get_env() {
  local key="$1"
  awk -F= -v k="$key" '$1 == k {sub(/^[[:space:]]+/, "", $2); print $2}' "$ENV_FILE" | tail -n 1
}

WEB_URL="$(get_env CLEARML_WEB_EXTERNAL_URL)"
API_URL="$(get_env CLEARML_API_EXTERNAL_URL)"
FILES_URL="$(get_env CLEARML_FILESERVER_URL)"

if [[ -z "$WEB_URL" || -z "$API_URL" || -z "$FILES_URL" ]]; then
  echo "ERROR: one or more required URLs are missing in $ENV_FILE" >&2
  exit 1
fi

check_url() {
  local name="$1"
  local url="$2"
  echo "==> Checking $name: $url"
  local status
  status="$(curl -k -L -o /dev/null -s -w '%{http_code}' --max-time 20 "$url")"
  case "$status" in
    200|301|302|303|307|308|401|403)
      echo "PASS $name returned HTTP $status"
      ;;
    *)
      echo "FAIL $name returned HTTP $status" >&2
      return 1
      ;;
  esac
}

check_url "webserver" "$WEB_URL"
check_url "apiserver" "$API_URL"
check_url "fileserver" "$FILES_URL"

echo "==> Optional endpoint checks"
curl -k -fsS --max-time 20 "$API_URL/debug.ping" >/dev/null && echo "PASS apiserver debug.ping"
curl -k -fsS --max-time 20 "$FILES_URL" >/dev/null && echo "PASS fileserver root"

echo "Smoke test finished successfully."
