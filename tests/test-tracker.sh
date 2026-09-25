#!/usr/bin/env bash
# test-tracker.sh — tickets: id parsing, gsd-tracker with none / custom /
# clickup, the gsd-clickup alias, and the ticket paths through gsd-start,
# gsd-finish and gsd-doctor.
# CI-safe: the ClickUp API is a curl stub, gsd-sdk and gh are stubbed, and
# remotes are local bare repos.
set -uo pipefail
PKG=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export PATH="$WORK/stub:$PKG/bin:$PATH"
unset GSD_PROVIDER GSD_AGENT GSD_AGENT_COMMAND GSD_LOCK_HELD GSD_SKIP_GUARD GSD_TRACKER \
      GSD_TRACKER_STATUS_START GSD_TRACKER_STATUS_FINISH GSD_CLICKUP_STATUS_START \
      GSD_CLICKUP_STATUS_FINISH GSD_CLICKUP_ENG_LIST
export CLICKUP_API_TOKEN=pk_test GSD_CLICKUP_CONFIG=/dev/null
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/      /'; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { if grep -q -- "$2" "$3"; then ok "$1"; else bad "$1" "$(tail -5 "$3")"; fi; }
hasnt() { if grep -q -- "$2" "$3"; then bad "$1" "$(grep -- "$2" "$3" | head -3)"; else ok "$1"; fi; }
fails() { local name=$1; shift; if "$@" > "$WORK/out" 2>&1; then bad "$name" "unexpected success"; else ok "$name"; fi; }
section() { printf '\n%s\n' "$1"; }
commit() { git -C "$1" add -A; git -C "$1" commit -qm "${2:-c}"; }

# ── stubs ────────────────────────────────────────────────────────────────────
mkdir -p "$WORK/stub"
cat > "$WORK/stub/gsd-sdk" <<'SDK'
#!/usr/bin/env bash
case "$1 $2" in
  "query phase.add")
    rm="$5/.planning/ROADMAP.md"
    n=$(grep -oE '^### Phase [0-9]+:' "$rm" | grep -oE '[0-9]+' | sort -n | tail -1)
    printf '\n### Phase %s: %s\n' "$((n + 1))" "$3" >> "$rm" ;;
  *) echo "stub gsd-sdk: unsupported $*" >&2; exit 1 ;;
esac
SDK
cat > "$WORK/stub/gh" <<'GH'
#!/usr/bin/env bash
echo "https://github.com/example/shop/pull/1"
GH
# curl: a fake ClickUp API. Logs "METHOD PATH BODY"; prints body + http code
# (the adapter passes -w '\n%{http_code}').
cat > "$WORK/stub/curl" <<'CURL'
#!/usr/bin/env bash
m=GET; body=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in -X) m=$2; shift ;; -d) body=$2; shift ;; -H|-w|--max-time) shift ;; http*) url=$1 ;; esac
  shift
done
path=${url#https://api.clickup.com/api/v2}
printf '%s %s %s\n' "$m" "$path" "$body" >> "$CURL_LOG"
code=200
case "$m $path" in
  "GET /task/abc123?include_subtasks=true")
    out='{"status":{"status":"to do"},"list":{"id":"L1","name":"Backlog"},"subtasks":[
      {"id":"sub1","status":{"status":"to do","type":"open"},"date_closed":null},
      {"id":"sub2","status":{"status":"complete","type":"closed"},"date_closed":"1"}]}' ;;
  "GET /task/done123?include_subtasks=true")
    out='{"status":{"status":"In-Progress"},"list":{"id":"L1","name":"Backlog"},"subtasks":[]}' ;;
  "GET /list/L1") out='{"statuses":[{"status":"to do"},{"status":"In-Progress"},{"status":"In-Testing"}]}' ;;
  "GET /task/abc123?include_markdown_description=true")
    out='{"name":"Cart","url":"https://app.clickup.com/t/abc123","status":{"status":"to do"},"markdown_description":"As a buyer I keep a cart."}' ;;
  "GET /task/abc123/comment") out='{"comments":[{"comment_text":"looks good"}]}' ;;
  "GET /user") out='{"user":{}}' ;;
  PUT*|POST*) out='{}' ;;
  *) out='{"err":"not found"}'; code=404 ;;
esac
printf '%s\n%s' "$out" "$code"
CURL
chmod +x "$WORK/stub/gsd-sdk" "$WORK/stub/gh" "$WORK/stub/curl"
export CURL_LOG="$WORK/curl.log"

# a custom tracker: logs its argv and GSD_TRACKER_STATUS; FAIL-* ids fail
cat > "$WORK/tracker.sh" <<'TR'
#!/usr/bin/env bash
printf '%s|%s|status=%s\n' "$1" "$*" "${GSD_TRACKER_STATUS:-}" >> "$TRACKER_LOG"
case "${2:-}" in FAIL-*) exit 1 ;; esac
[ "$1" != snapshot ] || printf '# Ticket %s\n\nproduct words\n' "$2"
TR
chmod +x "$WORK/tracker.sh"
export TRACKER_LOG="$WORK/tracker.log"

. "$PKG/lib/common.sh"; . "$PKG/lib/tracker.sh"

section "ticket ids — parse, extract, match"
is "bare id"                       "$(gsd_ticket_norm 869e33cv4)" 869e33cv4
is "tk- prefix"                    "$(gsd_ticket_norm tk-PROJ-42)" PROJ-42
is "legacy cu_ prefix"             "$(gsd_ticket_norm cu_869e33cv4)" 869e33cv4
is "CU- kept outside clickup (a Jira key)" "$(gsd_ticket_norm CU-12)" CU-12
is "CU- stripped for clickup"      "$(gsd_ticket_norm CU-869e33cv4 clickup)" 869e33cv4
is "ClickUp URL"                   "$(gsd_ticket_norm https://app.clickup.com/t/869e33cv4)" 869e33cv4
is "Jira URL with a query"         "$(gsd_ticket_norm 'https://x.atlassian.net/browse/PROJ-42?focus=1')" PROJ-42
is "#42"                           "$(gsd_ticket_norm '#42')" 42
if gsd_ticket_norm 'a b' >/dev/null; then bad "a space is refused"; else ok "a space is refused"; fi
if gsd_ticket_norm 'x;rm' >/dev/null; then bad "shell text is refused"; else ok "shell text is refused"; fi
is "extract from a title"          "$(gsd_ticket_extract '### Phase 7: cart tk-PROJ-42')" PROJ-42
is "extract before (INSERTED)"     "$(gsd_ticket_extract 'Phase 2.1: bug tk-abc123 (INSERTED)')" abc123
is "extract from a branch"         "$(gsd_ticket_extract phase-7-cart-tk-proj-42)" proj-42
is "extract legacy cu_"            "$(gsd_ticket_extract 'cart cu_869e33cv4')" 869e33cv4
is "extract legacy ClickUp <id>"   "$(gsd_ticket_extract 'cart ClickUp 869e33cv4')" 869e33cv4
is "no tag → nothing"              "$(gsd_ticket_extract 'plain stuck title')" ""
if gsd_ticket_tagged "cart tk-PROJ-42" PROJ-4; then bad "PROJ-4 is not PROJ-42"; else ok "PROJ-4 is not PROJ-42"; fi
if gsd_ticket_tagged "cart tk-PROJ-42" proj-42; then ok "tag match ignores case"; else bad "tag match ignores case"; fi

section "gsd-tracker — tracker = none (the default)"
R="$WORK/none"; mkdir -p "$R"; git -C "$R" init -qb main
(cd "$R" && gsd-tracker which) > "$WORK/out"; is "which → none" "$(cat "$WORK/out")" none
(cd "$R" && gsd-tracker start PROJ-1 hi) > "$WORK/out" 2>&1
is  "start is a no-op that succeeds" "$?" 0
has "…and says so"                   "tracker = none" "$WORK/out"
fails "snapshot is refused"          bash -c 'cd "$1" && gsd-tracker snapshot PROJ-1' _ "$R"
fails "an unknown tracker is refused" gsd-tracker --tracker jira start PROJ-1 hi
fails "a bad id is refused"          gsd-tracker --tracker custom start 'a b' hi
is "extract works without a tracker" "$(gsd-tracker extract 'x tk-Z9')" Z9

section "gsd-tracker — tracker = custom"
R="$WORK/custom"; mkdir -p "$R/scripts"; git -C "$R" init -qb main
cp "$WORK/tracker.sh" "$R/scripts/tracker.sh"
printf 'tracker = custom\ntracker_command = scripts/tracker.sh\ntracker_status_start = Doing\n' > "$R/.gsd.conf"
: > "$TRACKER_LOG"
(cd "$R" && gsd-tracker start https://x/browse/PROJ-42 "phase 7 started") > "$WORK/out" 2>&1
is  "start runs the script"            "$?" 0
has "…relative command, normalized id, text" "^start|start PROJ-42 phase 7 started|status=Doing$" "$TRACKER_LOG"
(cd "$R" && GSD_TRACKER_STATUS_START=Build gsd-tracker start PROJ-42 x) >/dev/null 2>&1
has "env status beats .gsd.conf"       "status=Build$" "$TRACKER_LOG"
(cd "$R" && gsd-tracker comment PROJ-42 note) >/dev/null 2>&1
has "comment gets no status"           "^comment|comment PROJ-42 note|status=$" "$TRACKER_LOG"
fails "a failing script → nonzero"     bash -c 'cd "$1" && gsd-tracker finish FAIL-1 x' _ "$R"
is  "…exit 2 (tracker call failed)"    "$(cd "$R" && gsd-tracker finish FAIL-1 x >/dev/null 2>&1; echo $?)" 2
(cd "$R" && gsd-tracker snapshot PROJ-42 --out "$WORK/t.md") > "$WORK/out" 2>&1
has "snapshot --out writes the file"   "product words" "$WORK/t.md"
fails "a failed snapshot → nonzero"    bash -c 'cd "$1" && gsd-tracker snapshot FAIL-2 --out "$2"' _ "$R" "$WORK/f.md"
if [ -e "$WORK/f.md" ]; then bad "…and leaves no file"; else ok "…and leaves no file"; fi
chmod -x "$R/scripts/tracker.sh"
fails "a non-executable command is refused" bash -c 'cd "$1" && gsd-tracker start PROJ-42 x' _ "$R"
has   "…naming it"                     "not an executable" "$WORK/out"

section "gsd-tracker — tracker = clickup (fake API)"
if ! command -v jq >/dev/null 2>&1; then
  echo "  SKIPPED: jq not installed"
else
  R="$WORK/cu"; mkdir -p "$R"; git -C "$R" init -qb main; printf 'tracker = clickup\n' > "$R/.gsd.conf"
  : > "$CURL_LOG"
  (cd "$R" && gsd-tracker start abc123 "phase started") > "$WORK/out" 2>&1
  is  "start succeeds"                      "$?" 0
  has "status resolved in the list's spelling" 'PUT /task/abc123 {"status": "In-Progress"}' "$CURL_LOG"
  has "comment posted"                      'POST /task/abc123/comment {"comment_text": "phase started"}' "$CURL_LOG"
  has "open subtask cascades"               'PUT /task/sub1 ' "$CURL_LOG"
  hasnt "closed subtask left alone"         'PUT /task/sub2 ' "$CURL_LOG"
  : > "$CURL_LOG"; (cd "$R" && gsd-tracker start done123 again) > "$WORK/out" 2>&1
  hasnt "already there → no status write (idempotent)" 'PUT /task/done123' "$CURL_LOG"
  hasnt "…and no second comment"            'POST /task/done123' "$CURL_LOG"
  : > "$CURL_LOG"; (cd "$R" && gsd-tracker finish abc123 merged) >/dev/null 2>&1
  has "finish → In-Testing"                 'PUT /task/abc123 {"status": "In-Testing"}' "$CURL_LOG"
  printf 'tracker = clickup\ntracker_status_finish = to do\n' > "$R/.gsd.conf"
  : > "$CURL_LOG"; (cd "$R" && gsd-tracker finish done123 back) >/dev/null 2>&1
  has "tracker_status_finish from .gsd.conf wins" 'PUT /task/done123 {"status": "to do"}' "$CURL_LOG"
  (cd "$R" && gsd-tracker snapshot abc123) > "$WORK/snap" 2>&1
  has "snapshot: title"                     "^# Cart" "$WORK/snap"
  has "snapshot: description"               "As a buyer I keep a cart." "$WORK/snap"
  has "snapshot: comments"                  "^- looks good" "$WORK/snap"
  is  "an API error → exit 2"               "$(cd "$R" && gsd-tracker start nope404 x >/dev/null 2>&1; echo $?)" 2
  : > "$CURL_LOG"; (cd "$WORK/none" && gsd-clickup start abc123 hi) >/dev/null 2>&1
  has "gsd-clickup alias forces clickup (repo says none)" 'PUT /task/abc123' "$CURL_LOG"
  is  "gsd-clickup extract still works"     "$(gsd-clickup extract 'cart cu_abc123')" abc123
fi

# ── through gsd-start / gsd-finish ───────────────────────────────────────────
project() {  # $1=dir $2=extra .gsd.conf lines — repo on main + bare origin
  git init -q --bare -b main "$1.git"
  mkdir -p "$1/.planning/phases" "$1/scripts"; git -C "$1" init -qb main
  printf '# Roadmap\n\n### Phase 1: catalog\n' > "$1/.planning/ROADMAP.md"
  printf 'install = none\ntest = none\n%s' "${2:-}" > "$1/.gsd.conf"
  cp "$WORK/tracker.sh" "$1/scripts/tracker.sh"
  commit "$1" init; git -C "$1" remote add origin "$1.git"; git -C "$1" push -qu origin main
}

section "gsd-start --ticket / gsd-finish — tracker = custom"
R="$WORK/shop"; project "$R" 'tracker = custom
tracker_command = scripts/tracker.sh
'
: > "$TRACKER_LOG"
(cd "$R" && gsd-start -n "shopping cart" --ticket PROJ-42 --no-launch) > "$WORK/out" 2>&1
is  "claim with --ticket succeeds"      "$?" 0
is  "title ends with tk-<id>"           "$(grep -c '^### Phase 2: shopping cart tk-PROJ-42$' "$R/.planning/ROADMAP.md")" 1
if git -C "$R" show-ref -q --verify refs/heads/phase-2-shopping-cart-tk-proj-42; then ok "branch/slug ends with tk-<id>"
else bad "branch/slug ends with tk-<id>" "$(git -C "$R" branch)"; fi
has "ticket moved to started"           "^start|start PROJ-42 🚧 GSD phase 2 started" "$TRACKER_LOG"
fails "same ticket, other words → refused" bash -c 'cd "$1" && gsd-start -n "cart again" --ticket https://x/browse/PROJ-42 --no-launch' _ "$R"
has   "…naming the phase to attach to"  "phase 2 already tracks ticket PROJ-42" "$WORK/out"
fails "a malformed --ticket is refused" bash -c 'cd "$1" && gsd-start -n "x" --ticket "a b" --no-launch' _ "$R"
(cd "$R" && gsd-start -n "legacy flag" --cu CU-abc123 --no-launch) > "$WORK/out" 2>&1
is  "--cu still works, CU- stripped"    "$(grep -c '^### Phase 3: legacy flag tk-abc123$' "$R/.planning/ROADMAP.md")" 1
(cd "$R" && gsd-start -n "flaky tracker" --ticket FAIL-9 --no-launch) > "$WORK/out" 2>&1
is  "a tracker failure doesn't block the claim" "$?" 0
has "…it is only a note"                "ticket FAIL-9 not updated (non-fatal)" "$WORK/out"
: > "$TRACKER_LOG"
(cd "$R" && gsd-start -p 2 --no-launch) > "$WORK/out" 2>&1
has "-p re-attach reads the id from the title (case kept)" "^start|start PROJ-42 " "$TRACKER_LOG"
WT=$(git -C "$R" worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} /refs\/heads\/phase-2-/{print w}')
printf 'cart\n' > "$WT/cart.txt"; commit "$WT" cart
: > "$TRACKER_LOG"
(cd "$R" && gsd-finish 2 --pr) > "$WORK/out" 2>&1
has "finish --pr → finish, PR opened"   "^finish|finish PROJ-42 🔀 GSD phase 2: PR opened" "$TRACKER_LOG"
(cd "$R" && gsd-finish 2) > "$WORK/out" 2>&1
is  "finish succeeds"                   "$?" 0
has "finish → finish, merged"           "^finish|finish PROJ-42 ✅ GSD phase 2 merged to main" "$TRACKER_LOG"

section "gsd-start --ticket — tracker = none tags only"
R="$WORK/plain"; project "$R"
: > "$TRACKER_LOG"
(cd "$R" && gsd-start -n "search" --ticket 77 --no-launch) > "$WORK/out" 2>&1
is  "claim succeeds"                    "$?" 0
is  "title tagged"                      "$(grep -c '^### Phase 2: search tk-77$' "$R/.planning/ROADMAP.md")" 1
has "…with a note that nothing is updated" "phase tagged tk-77 only" "$WORK/out"
is  "no tracker call"                   "$(wc -l < "$TRACKER_LOG" | tr -d ' ')" 0

section "gsd-doctor — tracker config"
doc() { gsd-doctor --repo "$1" --json 2>/dev/null; }
# file, not a pipe: grep -q would exit early and pipefail would fail the pipe
code() { doc "$1" > "$WORK/dj"; grep -q "\"code\":\"$2" "$WORK/dj"; }
R="$WORK/doc"; project "$R"
printf '\n### Phase 2: old cart cu_869e33cv4\n' >> "$R/.planning/ROADMAP.md"
if code "$R" T070; then ok "T070: cu_ tags with tracker = none"; else bad "T070: cu_ tags with tracker = none"; fi
printf 'tracker = clickup\n' >> "$R/.gsd.conf"
if code "$R" T07; then bad "…gone once tracker = clickup"; else ok "…gone once tracker = clickup"; fi
printf 'install = none\ntracker = jira\n' > "$R/.gsd.conf"
if code "$R" T071; then ok "T071: unknown tracker"; else bad "T071: unknown tracker"; fi
printf 'install = none\ntracker = custom\ntracker_command = scripts/missing.sh\n' > "$R/.gsd.conf"
if code "$R" T072; then ok "T072: custom command missing"; else bad "T072: custom command missing"; fi
R="$WORK/debt"; project "$R" 'flow = strict
tracker = custom
tracker_command = scripts/tracker.sh
'
printf '# Roadmap\n\n- [x] **Phase 1: catalog tk-PROJ-7**\n\n### Phase 1: catalog tk-PROJ-7\n' > "$R/.planning/ROADMAP.md"
mkdir -p "$R/.planning/phases/01-catalog-tk-proj-7"
doc "$R" > "$WORK/out"
has "T040 counts a missing ticket snapshot" "Phase 1 merged without: ticket" "$WORK/out"
has "…fix names the snapshot command"   "gsd-tracker snapshot proj-7 --out .planning/phases/01-catalog-tk-proj-7/01-TICKET.md" "$WORK/out"
printf 'install = none\nflow = strict\n' > "$R/.gsd.conf"
doc "$R" > "$WORK/out"
hasnt "tracker = none → no ticket debt"  "without: ticket" "$WORK/out"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
