#!/usr/bin/env bash

# selector.sh - runs inside tmux display-popup
# Env: CURRENT_WINDOW is set by popup.sh

CURRENT_WIN_INDEX=$(tmux display-message -p '#{window_index}')

# Build pane list into an array
mapfile -t PANES < <(tmux list-panes -s \
  -F '#{window_index}.#{pane_index} #{window_name} [#{pane_title}] #{pane_current_command}' \
  | grep -v "^${CURRENT_WIN_INDEX}\.")

if [ ${#PANES[@]} -eq 0 ]; then
  echo "No panes available."
  sleep 1
  exit 0
fi

SELECTED=0
TOTAL=${#PANES[@]}

# Hide cursor
printf '\e[?25l'

cleanup() {
  printf '\e[?25h'
}
trap cleanup EXIT

join_pane() {
  local flags="$1"
  TARGET="${PANES[$SELECTED]%% *}"
  SESSION=$(tmux display-message -p '#{session_name}')
  tmux join-pane $flags -s "${SESSION}:${TARGET}" -t "${CURRENT_WINDOW}"
  exit 0
}

render() {
  printf '\e[H\e[2J'
  echo "Pick a pane (j/k move, v/Enter=vertical, h=horizontal, Esc/q=cancel):"
  echo ""
  for i in "${!PANES[@]}"; do
    if [ "$i" -eq "$SELECTED" ]; then
      printf '\e[1;7m  %s  \e[0m\n' "${PANES[$i]}"
    else
      printf '  %s\n' "${PANES[$i]}"
    fi
  done
}

render

while true; do
  IFS= read -rsn1 key

  case "$key" in
    j)
      if [ "$SELECTED" -lt $((TOTAL - 1)) ]; then
        ((SELECTED++))
      fi
      render
      ;;
    k)
      if [ "$SELECTED" -gt 0 ]; then
        ((SELECTED--))
      fi
      render
      ;;
    v | "")
      # v or Enter - vertical split (side by side)
      join_pane "-h"
      ;;
    h)
      # h - horizontal split (stacked)
      join_pane ""
      ;;
    $'\x1b')
      # Escape or arrow key sequence
      extra=""
      while IFS= read -rsn1 -t 0.1 ch; do
        extra+="$ch"
      done
      case "$extra" in
        '[A')  # Up arrow
          if [ "$SELECTED" -gt 0 ]; then
            ((SELECTED--))
          fi
          render
          ;;
        '[B')  # Down arrow
          if [ "$SELECTED" -lt $((TOTAL - 1)) ]; then
            ((SELECTED++))
          fi
          render
          ;;
        *)
          # Standalone Esc or unrecognized sequence - cancel
          if [ -z "$extra" ]; then
            exit 0
          fi
          ;;
      esac
      ;;
    q)
      exit 0
      ;;
  esac
done
