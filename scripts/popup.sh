#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CURRENT_WINDOW=$(tmux display-message -p '#{session_name}:#{window_index}')
CURRENT_SESSION_ID=$(tmux display-message -p '#{session_id}')
CURRENT_WINDOW_ID=$(tmux display-message -p '#{window_id}')

# Check if there are any panes to join across all sessions
HAS_PANES=$(tmux list-panes -a -F '#{session_id}:#{window_id}' \
  | grep -v "^${CURRENT_SESSION_ID}:${CURRENT_WINDOW_ID}$" | head -1)

if [ -z "$HAS_PANES" ]; then
  tmux display-message "No panes in other windows to join."
  exit 0
fi

tmux display-popup -E -w 60% -h 60% \
  "CURRENT_WINDOW='$CURRENT_WINDOW' CURRENT_SESSION_ID='$CURRENT_SESSION_ID' CURRENT_WINDOW_ID='$CURRENT_WINDOW_ID' '$CURRENT_DIR/selector.sh'"
