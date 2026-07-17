# claude — same as `alias claude='claude --name "$(basename "$PWD")"'`, plus:
# each tab remembers its own conversation. A SessionStart hook records which
# conversation lives in this tab (~/.claude/agterm-tab-map/<tab-id> — new chat,
# /clear, and --resume all update it, latest start wins). A bare `claude` in
# this tab resumes that recorded conversation; an explicit `claude -r` always
# shows the normal picker (manual override), and `--resume <id>` / any other
# args pass through untouched. The auto-launch block at the END of this file
# (after PATH setup) starts claude automatically when the tab's shell opens.
claude() {
  local name="$(basename "$PWD")"
  local resume="" bare_r=0
  local -a out
  local cur
  while (( $# )); do
    cur=$1; shift
    case "$cur" in
      --name)
        (( $# )) && { name=$1; shift; } ;;
      --resume|-r)
        if (( $# )) && [[ "$1" != -* ]]; then resume=$1; shift; else bare_r=1; fi ;;
      *) out+=("$cur") ;;
    esac
  done
  if [[ -z "$resume" && $bare_r -eq 0 && -n "${AGTERM_SESSION_ID:-}" ]]; then
    local map="$HOME/.claude/agterm-tab-map/$AGTERM_SESSION_ID.${AGTERM_PANE:-left}"
    if [[ -f "$map" ]]; then
      local sid="$(<"$map")"
      [[ -n "$sid" && -f "$HOME/.claude/projects/$(pwd | tr '/' '-')/$sid.jsonl" ]] && resume=$sid
    fi
  fi
  local -a rargs
  if [[ -n "$resume" ]]; then
    rargs=(--resume "$resume")
  elif [[ $bare_r -eq 1 ]]; then
    rargs=(-r)
  fi
  command claude --name "$name" "${rargs[@]}" "${out[@]}"
}
