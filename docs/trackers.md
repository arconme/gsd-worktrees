# Tickets and trackers

A **ticket** is the issue or task in your tracker that a phase implements
(a ClickUp task, a Jira issue, a GitHub issue, …). Linking one is optional.

## Link a phase to a ticket

```sh
gsd-start -n "shopping cart" --ticket 869e33cv4
gsd-start -n "login" --ticket https://acme.atlassian.net/browse/PROJ-42
```

The phase title and slug end with the tag `tk-<id>`:

```
### Phase 7: shopping cart tk-869e33cv4       (ROADMAP.md)
phase-7-shopping-cart-tk-869e33cv4            (branch / worktree)
```

`--ticket` takes the bare id, `tk-<id>`, `#<id>`, or the ticket URL (the last
path segment). Ids are letters and digits, with `-` between parts (`PROJ-42`).
A second claim with the same ticket is refused, however it is worded.

The tag is read back from the ROADMAP title (exact case), then the branch name
(lowercased). A tag already in the description works the same as `--ticket`.

## Pick a tracker

In `.gsd.conf`:

```ini
tracker = none        # default: tags only, nothing is updated
tracker = clickup     # the ClickUp API
tracker = custom      # your own script
tracker_command = scripts/tracker.sh     # custom only; relative to the repo root
tracker_status_start = In Progress       # optional
tracker_status_finish = In QA            # optional
```

`GSD_TRACKER=<name>` overrides `tracker =` for one command.

With a tracker set:

| When | What happens |
|---|---|
| `gsd-start` claims or attaches | `gsd-tracker start <id>`: ticket → "in progress", plus a comment |
| `/gsd-flow` first step | `ticket`: `gsd-tracker snapshot <id> --out <P>-TICKET.md`, then commit |
| `gsd-finish --pr` opens the PR | `gsd-tracker finish <id>`: ticket → "in testing", plus a comment |
| `gsd-finish` merges | the same, with the merge commit |

A tracker failure is only a note. It never blocks a claim or a merge.
With `tracker = none` the `ticket` flow step is skipped.

## ClickUp

Token, first match wins: `$CLICKUP_API_TOKEN`, or `CLICKUP_API_TOKEN=pk_…` in
`~/.config/gsd/clickup.env`. Check it: `gsd-tracker check`. Needs `jq`.

Status names match the task's own list, ignoring case, spaces, `-` and `_`
("in testing" finds "In-Testing"). Tried in order: the configured status, then
"in progress" / "in development" (start) or "in testing" / "in review"
(finish). Open subtasks move with the task. A task already in the target
status gets no second comment.

## Custom

Any tracker, through a script you keep in the repo:

```sh
<tracker_command> start    <id> <text>     # GSD_TRACKER_STATUS = configured start status, or empty
<tracker_command> finish   <id> <text>     # GSD_TRACKER_STATUS = configured finish status, or empty
<tracker_command> comment  <id> <text>
<tracker_command> status   <id> <status>
<tracker_command> snapshot <id>            # print the ticket as markdown on stdout
<tracker_command> check                    # exit 0 when set up
```

Exit 0 on success. Any other exit is reported as "tracker call failed".
Example for GitHub issues:

```sh
#!/usr/bin/env bash
case "$1" in
  start|finish|comment) gh issue comment "$2" --body "$3" ;;
  status)   gh issue edit "$2" --add-label "$3" ;;
  snapshot) gh issue view "$2" --comments ;;
  check)    gh auth status ;;
esac
```

## Old names

Still read, never written:

- `--cu <id>` → same as `--ticket` (also strips a `CU-` prefix).
- `cu_<id>` / `CU-<id>` / `ClickUp <id>` tags in titles and branches.
- `<P>-STORY.md` counts as the ticket snapshot. A `cu_` phase folder counts too.
- `gsd-clickup <cmd>` = `gsd-tracker --tracker clickup <cmd>`.
- `GSD_CLICKUP_STATUS_START` / `_FINISH` still work (`GSD_TRACKER_STATUS_*` win).

`gsd-doctor` findings:

| Code | Meaning | Fix |
|---|---|---|
| T070 | ROADMAP has `cu_` tags but `tracker = none` | add `tracker = clickup` |
| T071 | unknown `tracker =` value | use none, clickup, or custom |
| T072 | `tracker = custom` without an executable `tracker_command` | set it, `chmod +x` |
| T040 | (with `flow = strict`) a merged phase has no ticket snapshot | the `gsd-tracker snapshot` command it prints |
