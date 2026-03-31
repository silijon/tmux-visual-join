#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Read user-configurable key, default to "M"
VISUAL_JOIN_KEY=$(tmux show-option -gqv @visual-join-key)
VISUAL_JOIN_KEY=${VISUAL_JOIN_KEY:-m}

tmux bind-key "$VISUAL_JOIN_KEY" run-shell -b "$CURRENT_DIR/scripts/popup.sh"
