# shellcheck shell=bash
# lib/ui.sh — the UI quality gates, one definition shared by gsd-flow-next,
# gsd-worktree-guard, gsd-doctor and gsd-ui (see docs/ui-quality-plan.md).
#
#   .planning/design/DESIGN.md   the project's design system (one per project).
#                                A stub carries GSD_UI_STUB; it counts as filled
#                                once that line is gone.
#   <P>-LAYOUT.md                per phase with screens: the chosen /gsd-sketch
#                                (`sketch:`), the pages to shoot (`pages:`), and
#                                the layout contract. `sketch: skip <reason>` is
#                                an explicit, visible opt-out.
#   <P>-SHOTS.md                 per phase: gsd-ui shots wrote screenshots (the
#                                PNGs sit in <P>-SHOTS/, not committed), or
#                                `skipped: <reason>`.
#
# ui_gates in .gsd.conf (main checkout): warn (default) = gsd-flow-next shows
# the steps, doctor notes; strict = the guard blocks too, doctor reports
# findings; off = none of it.
# Needs lib/common.sh.

GSD_UI_STUB='<!-- gsd:design-stub'

gsd_ui_gates() {  # $1=any checkout → warn|strict|off
  local v
  v=$(gsd_conf_get "$(gsd_main "$1" 2>/dev/null || true)" ui_gates)
  [ -n "$v" ] || v=$(gsd_conf_get "$1" ui_gates)
  case "$v" in strict|off) printf '%s' "$v" ;; *) printf warn ;; esac
}

gsd_ui_design_file() { printf '%s/.planning/design/DESIGN.md' "$1"; }

gsd_ui_design_state() {  # $1=checkout → missing|stub|ok
  local f; f=$(gsd_ui_design_file "$1")
  [ -f "$f" ] || { printf missing; return; }
  if grep -qF "$GSD_UI_STUB" "$f"; then printf stub; else printf ok; fi
}

gsd_ui_field() {  # $1=file $2=key → value of the first `key: value` line
  [ -f "$1" ] || return 0
  sed -n -E "s/^$2:[[:space:]]*//p" "$1" | head -1 | sed -e 's/[[:space:]]*$//'
}

gsd_ui_winner() {  # $1=sketch dir → the winner from its README frontmatter ('' = none)
  local w
  w=$(sed -n '/^---$/,/^---$/p' "$1/README.md" 2>/dev/null | sed -n -E 's/^winner:[[:space:]]*//p' | head -1 | tr -d "\"'[:space:]")
  case "$w" in ''|null|'~'|none) ;; *) printf '%s' "$w" ;; esac
}

gsd_ui_layout_state() {  # $1=checkout $2=phase dir $3=P → missing|nosketch|badsketch|nowinner|nopages|skip|ok
  local f="$2/$3-LAYOUT.md" s
  [ -f "$f" ] || { printf missing; return; }
  s=$(gsd_ui_field "$f" sketch)
  case "$s" in
    '') printf nosketch; return ;;
    skip|skip[[:space:]]*) printf skip; return ;;
  esac
  [ -d "$1/$s" ] || { printf badsketch; return; }
  [ -n "$(gsd_ui_winner "$1/$s")" ] || { printf nowinner; return; }
  [ -n "$(gsd_ui_field "$f" pages)" ] || { printf nopages; return; }
  printf ok
}

gsd_ui_shots_state() {  # $1=phase dir $2=P → missing|skip|ok
  local f="$1/$2-SHOTS.md"
  [ -f "$f" ] || { printf missing; return; }
  if [ -n "$(gsd_ui_field "$f" skipped)" ]; then printf skip; else printf ok; fi
}

gsd_ui_has_screens() {  # $1=checkout → true when any phase has a UI-SPEC or LAYOUT
  local f
  for f in "$1"/.planning/phases/*/*-UI-SPEC.md "$1"/.planning/phases/*/*-LAYOUT.md; do
    [ -f "$f" ] && return 0
  done
  return 1
}

gsd_ui_playwright() {  # $1=checkout → the playwright CLI to use ('' = none)
  if [ -n "${GSD_PLAYWRIGHT:-}" ]; then printf '%s' "$GSD_PLAYWRIGHT"
  elif [ -x "$1/node_modules/.bin/playwright" ]; then printf '%s' "$1/node_modules/.bin/playwright"
  elif command -v playwright >/dev/null 2>&1; then command -v playwright
  fi
}

gsd_ui_scaffold_design() {  # $1=checkout — create the DESIGN.md stub + refs/ when missing; never overwrites
  local d="$1/.planning/design"
  mkdir -p "$d/refs"
  [ -e "$d/refs/.gitkeep" ] || : > "$d/refs/.gitkeep"
  [ -f "$d/DESIGN.md" ] && return 0
  cat > "$d/DESIGN.md" <<'EOF'
# Design system

<!-- gsd:design-stub — delete this line once the sections below are filled -->

Every screen in this project uses what is listed here. Don't invent new
styles: add to this file first, then use it.

## References

3–5 screenshots of real apps whose look you want, in `.planning/design/refs/`
(Mobbin, Refero, or apps you use). One line each: what to take from it.

## Tokens

Color, type scale, spacing, radius, shadow — and the file they live in.

## Components

Name → file (seed from shadcn/Radix or the project's UI kit).

## Page templates

List, detail, form, dashboard, … → file. Each phase names the template its
screens use in `<P>-LAYOUT.md`.

## Layout rules

- One main focus per screen.
- More than ~12 items → search, filters or tabs.
- The main button is on the first screen and never covered (cookie banner,
  chat bubble).
- One alignment system per page; consistent title casing.
EOF
}

gsd_ui_layout_template() {  # $1=file $2=phase number — write the LAYOUT template; never overwrites
  [ -f "$1" ] && return 0
  cat > "$1" <<EOF
# Phase $2 layout

<!-- gsd:layout — the layout contract for this phase's screens. gsd-flow-next
     reads sketch: and pages:; gsd-ui shots reads pages:. -->

sketch:
pages:
template:
reference:

## Sections, top to bottom

1.

## Main focus

## Main button

## Notes
EOF
}
