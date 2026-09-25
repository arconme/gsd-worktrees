# shellcheck shell=bash
# lib/trackers/custom.sh — any tracker, through the repo's own script.
#
# .gsd.conf:  tracker = custom
#             tracker_command = scripts/tracker.sh   (relative to the repo root)
# Called as:  <cmd> start|finish|comment|status <id> <text-or-status>
#             <cmd> snapshot <id>     → prints the ticket as markdown
#             <cmd> check             → exit 0 when set up
# For start/finish, GSD_TRACKER_STATUS holds the configured status name (or is
# empty: the script picks its own). A nonzero exit is reported, never fatal to
# gsd-start / gsd-finish.
# Sourced by bin/gsd-tracker (REPO, die, tracker_status set there).

custom_cmd() {
  local c; c=$(gsd_tracker_command "$REPO")
  [ -n "$c" ] || die "tracker = custom needs tracker_command = <script> in .gsd.conf"
  [ -x "$c" ] || die "tracker_command '$c' is not an executable file"
  printf '%s\n' "$c"
}

tracker_run() {  # $1=command, rest=args
  local cmd="$1" c; shift
  c=$(custom_cmd) || exit 1
  case "$cmd" in
    start|finish) GSD_TRACKER_STATUS=$(tracker_status "$cmd") "$c" "$cmd" "$@" || exit 2 ;;
    *) GSD_TRACKER_STATUS="" "$c" "$cmd" "$@" || exit 2 ;;
  esac
}
