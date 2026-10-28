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

## Commands

`gsd-tracker` is the one layer sessions and scripts call; each tracker is a
connector under it (`lib/trackers/<name>.sh`). Shared verbs, the same for
every tracker:

| Verb | Does |
|---|---|
| `snapshot <id> [--out <file>]` | print the ticket as markdown |
| `comment <id> <text>` · `status <id> <status>` | write back |
| `start` / `finish <id> <text>` | status + comment (called by `gsd-start` / `gsd-finish`) |
| `create <where> <title> [option…]` | new ticket; prints its id + url |
| `update <id> <option>…` | change fields |
| `tasks [option…]` | find tickets |
| `check` · `which` | login works · which tracker |

Options for `create` / `update` / `tasks` go to the connector as written; what
`<where>` is and which options work are the connector's. A connector may add
its own commands (`TRACKER_EXTRA`; ClickUp: `lists`, `members`, `api`). With
`tracker = none`, `comment` / `status` / `start` / `finish` do nothing and
succeed (so a claim never fails for want of a tracker), while `snapshot` /
`create` / `update` / `tasks` fail. Agents learn this from the `gsd-tracker`
skill: it checks `gsd-tracker which` first.

## Pick a tracker

In `.gsd.conf`:

```ini
tracker = none        # default: tags only, nothing is updated
tracker = clickup     # the ClickUp API
tracker = custom      # your own script
tracker_command = scripts/tracker.sh     # custom only; relative to the repo root
tracker_status_start = In Progress       # optional
tracker_status_finish = In QA            # optional
tracker_profile = acme                   # optional: this project's own login (below)
```

`GSD_TRACKER=<name>` overrides `tracker =` for one command.

With a tracker set:

| When | What happens |
|---|---|
| `gsd-start` claims or attaches | `gsd-tracker start <id>`: ticket → "in progress", plus a comment |
| `/gsdw-flow` first step | `ticket`: `gsd-tracker snapshot <id> --out <P>-TICKET.md`, then commit |
| `gsd-finish --pr` opens the PR | `gsd-tracker finish <id>`: ticket → "in testing", plus a comment |
| `gsd-finish` merges | the same, with the merge commit |

A new claim (`gsd-start -n`, `--insert`) needs its ticket: `--ticket <id>` or
a `tk-<id>` tag in the description. Without one it is refused, and nothing is
claimed; `--no-ticket` claims anyway, for work no ticket covers. `gsd-start -p`
on a phase with no ticket only notes it.

`gsd-init` asks which tracker to use (in a terminal, while `.gsd.conf` names
none). A script passes `gsd-init --tracker none|clickup|custom`
(`--tracker-command <script>` for custom); `gsd-bootstrap-repo` takes the same
flags.

A tracker failure is only a note. It never blocks a claim or a merge.
With `tracker = none` the `ticket` flow step is skipped.

## ClickUp

Token, first match wins: `$CLICKUP_API_TOKEN`, or `CLICKUP_API_TOKEN=pk_…` in
the token file. Check it: `gsd-tracker check`. Needs `jq`.

The token file is `~/.config/gsd/clickup.env`, shared by every project. To use
a different ClickUp user in one project (other workspace, split rate limits),
run this in the repo's main checkout (not a phase worktree):

```sh
gsd-tracker login            # or: gsd-tracker login acme
```

It asks for the token (typing is hidden), tests it with ClickUp, saves it to
`~/.config/gsd/clickup-<profile>.env` (only you can read it) and adds
`tracker_profile = <profile>` to `.gsd.conf`. The profile is the name you
give, else the one already set, else the repo folder's name. A token ClickUp
refuses is never saved. Run it again to replace the token; other lines in the
file (e.g. `CLICKUP_TEAM_ID`) are kept. When you typed the token, it then offers
to commit `.gsd.conf` (`[Y/n]`; that file only, never pushed) — only if the
file had no edits of its own and the checkout is on the base branch; otherwise
it prints the commit command. On another machine, run `gsd-tracker login` once
more. `echo pk_… | gsd-tracker login` works too (no question then).

In a phase worktree it refuses before asking for the token and names the main
checkout: it would edit and commit that checkout's `.gsd.conf`, not the folder
you are in. Existing worktrees need nothing: every gsd command reads
`.gsd.conf` from the main checkout, and the token file is in your home folder.
It edits `.gsd.conf` under the same lock as `gsd-start` and `gsd-finish`, so it
waits for one that is running (the question is asked before, so they never
wait on your answer).

By hand, the same thing is:

```ini
tracker_profile = acme     # in .gsd.conf — a name only, safe to commit
```

```sh
# on each machine, outside the repo
echo 'CLICKUP_API_TOKEN=pk_…' > ~/.config/gsd/clickup-acme.env
```

With a profile set, only `clickup-acme.env` is read. There is no fallback to
`clickup.env`: a missing file is an error, not the wrong user. The file sits
outside every checkout, so all phase worktrees see it. An exported
`$CLICKUP_API_TOKEN` still wins (`gsd-doctor` notes it), and
`GSD_TRACKER_PROFILE=<name>` overrides the profile for one command.

Status names match the task's own list, ignoring case, spaces, `-` and `_`
("in testing" finds "In-Testing"). Tried in order: the configured status, then
"in progress" / "in development" (start) or "in testing" / "in review"
(finish). Open subtasks move with the task. A task already in the target
status gets no second comment.

### Create, update, find — and ClickUp's own commands

With `tracker = clickup`, `gsd-tracker create` / `update` / `tasks` work on
ClickUp, and ClickUp's own commands `lists`, `members` and `api` go through
`gsd-tracker` too:

```sh
gsd-tracker lists                       # spaces, folders, lists — with ids
gsd-tracker members                     # id, username, email
gsd-tracker tasks --list 901 --assign me --status "in progress"
gsd-tracker tasks --match "login"       # name search over up to 1,000 tasks
gsd-tracker create 901 "Fix login" --desc "# Steps…" --assign sara@x.io --priority 2 --tag bug
gsd-tracker update 869e33cv4 --name "Fix login on Safari" --assign me --unassign 42
gsd-tracker api DELETE /task/869e33cv4/tag/bug   # any API v2 call; prints the body
```

`create`'s `<where>` is a list id. `<who>` is `me`, a user id, an email or a
username. `--desc -` reads the markdown from stdin. Priority: 1 urgent,
2 high, 3 normal, 4 low. `tasks`, `lists` and `members` need the workspace:
`CLICKUP_TEAM_ID` (env or the token file), else the only workspace the token
sees. They use the same token and profile as above. `gsd-clickup <command>`
is the same with the tracker fixed to ClickUp, for use outside a fitted repo.
See `gsd-clickup --help`.

## Custom

Any tracker, through a script you keep in the repo:

```sh
<tracker_command> start    <id> <text>     # GSD_TRACKER_STATUS = configured start status, or empty
<tracker_command> finish   <id> <text>     # GSD_TRACKER_STATUS = configured finish status, or empty
<tracker_command> comment  <id> <text>
<tracker_command> status   <id> <status>
<tracker_command> snapshot <id>            # print the ticket as markdown on stdout
<tracker_command> check                    # exit 0 when set up
<tracker_command> create <where> <title> [option…]   # optional: options as the user wrote them
<tracker_command> update <id> <option>…
<tracker_command> tasks  [option…]
```

A script that can't do a verb exits nonzero (reported as "tracker call
failed"). Connector-only commands (`lists`, …) are not passed to it.

`GSD_TRACKER_PROFILE` holds `tracker_profile` (or is empty), so the script can
pick its own login.

Exit 0 on success. Any other exit is reported as "tracker call failed".
A call that runs longer than 60 seconds (`GSD_TRACKER_TIMEOUT` to change it)
is stopped, so a script stuck on the network never hangs `gsd-start` or
`gsd-finish`.
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
- `GSD_CLICKUP_STATUS_START` / `_FINISH` still work (`GSD_TRACKER_STATUS_*` win).

`gsd-doctor` findings:

| Code | Meaning | Fix |
|---|---|---|
| T070 | ROADMAP has `cu_` tags but `tracker = none` | add `tracker = clickup` |
| T071 | unknown `tracker =` value | use none, clickup, or custom |
| T072 | `tracker = custom` without an executable `tracker_command` | set it, `chmod +x` |
| T040 | (with `flow = strict`) a merged phase has no ticket snapshot | the `gsd-tracker snapshot` command it prints |
