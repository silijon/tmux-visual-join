#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get current window identifier (session:window_index)
CURRENT_WINDOW=$(tmux display-message -p '#{session_name}:#{window_index}')
CURRENT_WIN_INDEX=$(tmux display-message -p '#{window_index}')

# List all panes in the session except those in the current window
PANE_LIST=$(tmux list-panes -s \
  -F '#{window_index}.#{pane_index} #{window_name} [#{pane_title}] #{pane_current_command}' \
  | grep -v "^${CURRENT_WIN_INDEX}\.")

if [ -z "$PANE_LIST" ]; then
  tmux display-message "No panes in other windows to join."
  exit 0
fi

tmux display-popup -E -w 60% -h 40% \
  "CURRENT_WINDOW='$CURRENT_WINDOW' '$CURRENT_DIR/selector.sh'"
