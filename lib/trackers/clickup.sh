# shellcheck shell=bash
# lib/trackers/clickup.sh — ClickUp adapter for bin/gsd-tracker.
#
# Auth: a personal API token (pk_…), first match wins:
#   1. $CLICKUP_API_TOKEN in the environment
#   2. ~/.config/gsd/clickup.env (sourced; must set CLICKUP_API_TOKEN=…)
# Create one in ClickUp: avatar → Settings → Apps → API Token.
#
# start/finish resolve the status against the task's own list: names match
# ignoring case, spaces, hyphens and underscores ("in testing" finds
# "In-Testing"). Candidates, in order:
#   start:  configured status, "in progress", "in development"
#   finish: configured status, "in testing",  "in review"
# They are idempotent (a task already there gets no second comment) and
# cascade to open subtasks. GSD_CLICKUP_ENG_LIST=<list id> prints a reminder
# when a started task lives in another list (the API can't move it).
# Sourced by bin/gsd-tracker (die, tracker_status set there).

CONFIG="${GSD_CLICKUP_CONFIG:-$HOME/.config/gsd/clickup.env}"

load_token() {
  if [ -z "${CLICKUP_API_TOKEN:-}" ] && [ -f "$CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG"
  fi
  [ -n "${CLICKUP_API_TOKEN:-}" ] \
    || die "no CLICKUP_API_TOKEN — export it or put CLICKUP_API_TOKEN=pk_… in $CONFIG"
}

api() {  # api <method> <path> [json-body]; prints response body, fails on HTTP >= 400
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS --max-time 15 -X "$method"
              -H "Authorization: $CLICKUP_API_TOKEN"
              -H "Content-Type: application/json")
  [ -n "$body" ] && args+=(-d "$body")
  local out http
  out=$(curl "${args[@]}" -w '\n%{http_code}' "https://api.clickup.com/api/v2$path") \
    || { printf 'gsd-tracker: curl failed (network?)\n' >&2; return 2; }
  http="${out##*$'\n'}"
  out="${out%$'\n'*}"
  if [ "$http" -ge 400 ] 2>/dev/null; then
    printf 'gsd-tracker: ClickUp API %s %s → HTTP %s: %s\n' "$method" "$path" "$http" "$out" >&2
    return 2
  fi
  printf '%s\n' "$out"
}

json_escape() {  # minimal JSON string escaper for comment/status payloads
  local py
  py=$(gsd_python) || die "no python 3.7+ found (tried python3, then python) — needed to build the request body"
  printf '%s' "$1" | "$py" -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

norm() {  # normalize a status name for comparison: lowercase, alnum only
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'
}

need_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required for '$1' — install it, e.g. brew install jq"
}

# resolve_status <list_id> <candidate>… — print the exact spelling of the first
# candidate that exists among the list's statuses (matched via norm). Falls
# back to the first candidate verbatim (with a warning) if the list can't be
# fetched or nothing matches — the PUT then fails visibly.
resolve_status() {
  local list_id="$1"; shift
  local list_json names cand name
  if ! list_json=$(api GET "/list/$list_id"); then
    printf 'gsd-tracker: cannot fetch list %s statuses — trying "%s" verbatim\n' "$list_id" "$1" >&2
    printf '%s\n' "$1"; return 0
  fi
  names=$(printf '%s' "$list_json" | jq -r '.statuses[].status')
  for cand in "$@"; do
    while IFS= read -r name; do
      if [ "$(norm "$name")" = "$(norm "$cand")" ]; then
        printf '%s\n' "$name"; return 0
      fi
    done <<< "$names"
  done
  printf 'gsd-tracker: no candidate (%s) matches list %s statuses [%s] — trying "%s" verbatim\n' \
    "$*" "$list_id" "$(printf '%s' "$names" | paste -sd ',' -)" "$1" >&2
  printf '%s\n' "$1"
}

clickup_move() {  # $1=start|finish $2=id $3=comment
  local cmd="$1" id="$2" text="$3" rc=0 cur_json cur st sid home conf
  need_jq "$cmd"
  load_token
  local cands=()
  conf=$(tracker_status "$cmd")
  [ -z "$conf" ] || cands+=("$conf")
  if [ "$cmd" = start ]; then cands+=("in progress" "in development")
  else cands+=("in testing" "in review"); fi
  # Fetch once, with subtasks for the cascade.
  cur_json=$(api GET "/task/$id?include_subtasks=true") || exit 2
  cur=$(printf '%s' "$cur_json" | jq -r '.status.status')
  st=$(resolve_status "$(printf '%s' "$cur_json" | jq -r '.list.id')" "${cands[@]}")
  if [ "$(norm "$cur")" = "$(norm "$st")" ]; then
    echo "• ClickUp $id already '$st' — status and comment skipped (idempotent)"
  else
    # both attempted independently — a bad status name must not swallow the comment
    api PUT "/task/$id" "{\"status\": $(json_escape "$st")}" >/dev/null \
      && echo "✔ ClickUp $id → status '$st'" || rc=2
    api POST "/task/$id/comment" "{\"comment_text\": $(json_escape "$text")}" >/dev/null \
      && echo "✔ ClickUp $id → comment posted" || rc=2
  fi
  # Open subtasks ride along; closed/complete ones are never touched.
  for sid in $(printf '%s' "$cur_json" | jq -r --arg st "$st" \
      'def n: ascii_downcase | gsub("[^a-z0-9]"; "");
       .subtasks[]? | select(.date_closed == null and (.status.status | n) != ($st | n) and .status.type != "closed" and (.status.status | test("^complete"; "i") | not)) | .id'); do
    api PUT "/task/$sid" "{\"status\": $(json_escape "$st")}" >/dev/null \
      && echo "✔ ClickUp $sid (subtask) → status '$st'" || rc=2
  done
  if [ "$cmd" = start ] && [ -n "${GSD_CLICKUP_ENG_LIST:-}" ]; then
    home=$(printf '%s' "$cur_json" | jq -r '.list.id')
    if [ "$home" != "$GSD_CLICKUP_ENG_LIST" ]; then
      echo "• task lives in list '$(printf '%s' "$cur_json" | jq -r '.list.name')' — move it to list $GSD_CLICKUP_ENG_LIST by hand (the API can't)"
    fi
  fi
  exit "$rc"
}

clickup_snapshot() {  # $1=id → markdown on stdout
  local id="$1" task comments
  need_jq snapshot
  load_token
  task=$(api GET "/task/$id?include_markdown_description=true") || exit 2
  comments=$(api GET "/task/$id/comment") || comments='{"comments":[]}'
  printf '%s' "$task" | jq -r --arg id "$id" '
    "# \(.name)\n\nTicket: ClickUp \($id) · \(.url // "") · status: \(.status.status // "?")\n\n" +
    ((.markdown_description // .description // "") | if . == "" then "_(no description)_" else . end)'
  printf '%s' "$comments" | jq -r '
    [.comments[]? | .comment_text // "" | select(. != "")] as $c
    | if ($c | length) > 0 then "\n## Comments\n\n" + ($c | map("- " + (gsub("\n"; "\n  "))) | join("\n")) else empty end'
}

tracker_run() {  # $1=command, rest=args
  case "$1" in
    start|finish) clickup_move "$1" "$2" "$3" ;;
    comment)
      load_token
      api POST "/task/$2/comment" "{\"comment_text\": $(json_escape "$3")}" >/dev/null \
        && echo "✔ ClickUp $2 → comment posted" || exit 2 ;;
    status)
      load_token
      api PUT "/task/$2" "{\"status\": $(json_escape "$3")}" >/dev/null \
        && echo "✔ ClickUp $2 → status '$3'" || exit 2 ;;
    snapshot) clickup_snapshot "$2" ;;
    check)
      load_token
      api GET /user >/dev/null && echo "✔ ClickUp token OK" || exit 2 ;;
  esac
}
