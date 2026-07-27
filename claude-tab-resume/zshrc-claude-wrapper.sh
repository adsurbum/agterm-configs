# claude — same as `alias claude='claude --name "$(basename "$PWD")"'`, plus:
# in an agterm tab, a bare `claude` resumes the conversation recorded for this
# tab+pane (~/.claude/agterm-tab-map/<tab-id>.<pane> — new chat, /clear, and
# --resume all update it, latest start wins). An explicit `claude -r` always
# opens the interactive resume picker.
# AGTERM_CLAUDE_INTERACTIVE=1 marks wrapper-launched interactive sessions: the
# SessionStart hook (agterm-tab-map.sh) writes the pane map ONLY when it is set.
# Headless `claude -p` runs (eval scripts, demo/serve.py, subprocess) inherit
# AGTERM_* env and used to clobber the map — ⌘B then forked a random eval
# session. Print mode also skips the auto-resume injection: a manual
# `claude -p "q"` in a mapped pane must not append turns to the pane's session.
claude() {
  local name="$(basename "$PWD")"
  local resume="" bare_r=0 headless=0 skip_map=0
  local -a out
  local cur
  while (( $# )); do
    cur=$1; shift
    case "$cur" in
      --name)
        (( $# )) && { name=$1; shift; } ;;
      --resume|-r)
        if (( $# )) && [[ "$1" != -* ]]; then resume=$1; shift; else bare_r=1; fi ;;
      -p|--print)
        headless=1; out+=("$cur") ;;
      -c|--continue)
        skip_map=1; out+=("$cur") ;;
      *) out+=("$cur") ;;
    esac
  done
  # A short hex session id (as shown in the status line) is not a valid --resume
  # value; expand it to the full UUID. This project first, then all projects.
  if [[ -n "$resume" && "$resume" =~ '^[0-9a-f]{4,35}$' ]]; then
    local -a _cs_m
    _cs_m=("$HOME/.claude/projects/$(pwd | tr '/' '-')/$resume"*.jsonl(N))
    (( ${#_cs_m} == 0 )) && _cs_m=("$HOME"/.claude/projects/*/"$resume"*.jsonl(N))
    if (( ${#_cs_m} == 1 )); then
      resume=${${_cs_m[1]:t}:r}
    elif (( ${#_cs_m} > 1 )); then
      print -u2 "claude: session prefix '$resume' is ambiguous (${#_cs_m} matches):"
      print -u2 -l -- ${${_cs_m[@]:t}:r}
      return 1
    fi
  fi

  if [[ $headless -eq 0 && $skip_map -eq 0 && -z "$resume" && $bare_r -eq 0 && -n "${AGTERM_SESSION_ID:-}" ]]; then
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
  if [[ $headless -eq 1 ]]; then
    command claude --name "$name" "${rargs[@]}" "${out[@]}"
  else
    AGTERM_CLAUDE_INTERACTIVE=1 command claude --name "$name" "${rargs[@]}" "${out[@]}"
  fi
}
