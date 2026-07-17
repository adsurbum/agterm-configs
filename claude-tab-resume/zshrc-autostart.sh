# >>> claude tab auto-resume >>>
# Auto-launch claude on shell startup in an agterm tab that has a recorded
# conversation (~/.claude/agterm-tab-map/<tab-id>, written by the SessionStart
# hook). Kept at the END of .zshrc so claude (~/.local/bin) is on PATH by the
# time it runs. Does not depend on agterm's restore-running-command setting.
# _CLAUDE_TAB_AUTOSTARTED is exported so subshells of the same pane skip this.
# The map is per pane (<tab-id>.<left|right|scratch>), so each pane of a split
# session restores its OWN conversation — and a pane that had no claude
# running (no map entry) stays a plain shell.
if [[ -o interactive && -n "${AGTERM_SESSION_ID:-}" && -z "${_CLAUDE_TAB_AUTOSTARTED:-}" ]]; then
  export _CLAUDE_TAB_AUTOSTARTED=1
  __claude_tab_map="$HOME/.claude/agterm-tab-map/$AGTERM_SESSION_ID.${AGTERM_PANE:-left}"
  if [[ -f "$__claude_tab_map" ]]; then
    __claude_tab_sid="$(<"$__claude_tab_map")"
    if [[ -n "$__claude_tab_sid" && -f "$HOME/.claude/projects/$(pwd | tr '/' '-')/$__claude_tab_sid.jsonl" ]]; then
      claude
    fi
  fi
  unset __claude_tab_map __claude_tab_sid
fi
# <<< claude tab auto-resume <<<
