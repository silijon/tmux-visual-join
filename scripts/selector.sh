#!/usr/bin/env bash

# selector.sh - runs inside tmux display-popup
# Env: CURRENT_WINDOW, CURRENT_SESSION_ID, CURRENT_WINDOW_ID set by popup.sh

# Format: <join_target>\t<session_name>\t<visible_row>
ROW_FMT='#{session_id}:#{window_id}.#{pane_id}	#{session_name}	#{window_index}.#{pane_index} #{window_name} [#{pane_title}] #{pane_current_command}'

declare -a SESSIONS=()
declare -A PANES_BY_SESSION
declare -A COUNTS

# Load all panes from all sessions, grouped by session
while IFS=$'\t' read -r target sess_name visible; do
  # Skip panes in the current window
  [[ "$target" == "${CURRENT_SESSION_ID}:${CURRENT_WINDOW_ID}."* ]] && continue
  PANES_BY_SESSION["$sess_name"]+="${target}"$'\t'"${visible}"$'\n'
done < <(tmux list-panes -a -F "$ROW_FMT")

# Count panes per session (before SESSIONS is built so counts are accurate)
for sess in "${!PANES_BY_SESSION[@]}"; do
  COUNTS["$sess"]=$(printf '%s' "${PANES_BY_SESSION[$sess]}" | grep -c $'\t')
done

# Get current session name
CURRENT_SESSION_NAME=$(tmux display-message -p -t "$CURRENT_SESSION_ID" '#{session_name}')

# Build SESSIONS in natural order; always include current session even if empty
ACTIVE_TAB=0
while IFS= read -r s; do
  if [[ -n "${PANES_BY_SESSION[$s]:-}" || "$s" == "$CURRENT_SESSION_NAME" ]]; then
    if [[ "$s" == "$CURRENT_SESSION_NAME" ]]; then
      ACTIVE_TAB="${#SESSIONS[@]}"
    fi
    SESSIONS+=("$s")
  fi
done < <(tmux list-sessions -F '#{session_created} #{session_name}' | sort -n | cut -d' ' -f2-)

declare -a CURRENT_PANES=()
SELECTED=0

load_active_tab() {
  local sess="${SESSIONS[$ACTIVE_TAB]}"
  local raw="${PANES_BY_SESSION[$sess]:-}"
  if [[ -z "$raw" ]]; then
    CURRENT_PANES=()
  else
    mapfile -t CURRENT_PANES <<< "${raw%$'\n'}"
  fi
  SELECTED=0
}

load_active_tab

read -r POPUP_ROWS POPUP_COLS < <(stty size 2>/dev/null)
: "${POPUP_ROWS:=24}"
: "${POPUP_COLS:=80}"

# Hide cursor
printf '\e[?25l'

cleanup() {
  printf '\e[?25h'
}
trap cleanup EXIT

join_pane() {
  local flags="$1"
  [[ "${#CURRENT_PANES[@]}" -eq 0 ]] && return
  local target="${CURRENT_PANES[$SELECTED]%%$'\t'*}"
  if ! tmux join-pane $flags -s "$target" -t "$CURRENT_WINDOW"; then
    tmux display-message "visual-join: join failed"
    exit 1
  fi
  exit 0
}

render_preview() {
  local pane_count="${#CURRENT_PANES[@]}"
  [[ "$pane_count" -eq 0 ]] && return

  # Calculate rows consumed by chrome above the preview
  local used=2  # footer + blank line
  if [[ "${#SESSIONS[@]}" -gt 1 ]]; then
    used=$((used + 2))  # tab strip + blank line
  fi
  used=$((used + pane_count))  # pane list rows

  local preview_rows=$((POPUP_ROWS - used - 2))  # 1 = separator + 1 = avoid scroll on last row
  [[ "$preview_rows" -lt 3 ]] && return

  # Separator (leave 1 col margin to prevent autowrap consuming an extra row)
  local sep_cols=$((POPUP_COLS - 1))
  local sep
  sep=$(printf '─%.0s' $(seq 1 "$sep_cols"))
  printf '\e[2m%s\e[0m\n' "$sep"

  # Extract the pane_id (%NN) from the join target (session_id:window_id.%pane_id)
  local raw_target="${CURRENT_PANES[$SELECTED]%%$'\t'*}"
  local pane_id="%${raw_target##*%}"

  local max_cols=$((POPUP_COLS - 1))

  # Grab full scrollback so tail gets real content, not the empty bottom of the visible screen.
  # Then strip trailing blank lines so we show the most recent actual content.
  local output
  output=$(tmux capture-pane -ep -S - -t "$pane_id" 2>/dev/null \
    | LC_ALL=C awk -v max="$max_cols" '
      {
        out = ""; vis = 0; i = 1; n = length($0);
        while (i <= n && vis < max) {
          c = substr($0, i, 1);
          if (c == "\033") {
            out = out c; i++;
            if (i <= n && substr($0, i, 1) == "[") {
              out = out "["; i++;
              while (i <= n) {
                ch = substr($0, i, 1); out = out ch; i++;
                if (ch ~ /[@-~]/) break;
              }
            }
          } else {
            out = out c; vis++; i++;
          }
        }
        print out "\033[0m";
      }' \
    | LC_ALL=C awk '
      { lines[NR] = $0 }
      END {
        last = 0;
        for (i = 1; i <= NR; i++) {
          s = lines[i];
          gsub(/\033\[[0-9;]*[@-~]/, "", s);
          if (length(s) > 0) last = i;
        }
        for (i = 1; i <= last; i++) print lines[i];
      }')

  local actual
  actual=$(printf '%s\n' "$output" | wc -l)
  printf '%s\n' "$output" | tail -n "$preview_rows"

  # Pad to fill preview_rows if content is shorter
  local pad=$((preview_rows - actual))
  [[ $actual -gt $preview_rows ]] && pad=0
  [[ $pad -gt 0 ]] && printf '\n%.0s' $(seq 1 $pad)
}

render() {
  printf '\e[H\e[2J'

  # Footer (shown at top)
  if [[ "${#SESSIONS[@]}" -gt 1 ]]; then
    printf '\e[2mj/k=move  Tab/S-Tab=session  1-9=jump  v/Enter=vertical  h=horizontal  Esc/q=cancel\e[0m\n\n'
  else
    printf '\e[2mj/k=move  v/Enter=vertical  h=horizontal  Esc/q=cancel\e[0m\n\n'
  fi

  # Tab strip — only if more than one session
  if [[ "${#SESSIONS[@]}" -gt 1 ]]; then
    for i in "${!SESSIONS[@]}"; do
      local sess="${SESSIONS[$i]}"
      local count="${COUNTS[$sess]:-0}"
      if [[ "$i" -eq "$ACTIVE_TAB" ]]; then
        printf '\e[1;7m[ %s (%s) ]\e[0m ' "$sess" "$count"
      else
        printf '\e[2m %s (%s) \e[0m ' "$sess" "$count"
      fi
    done
    printf '\n\n'
  fi

  if [[ "${#CURRENT_PANES[@]}" -eq 0 ]]; then
    echo "  (no panes to join in this session)"
  else
    for i in "${!CURRENT_PANES[@]}"; do
      local visible="${CURRENT_PANES[$i]#*$'\t'}"
      if [[ "$i" -eq "$SELECTED" ]]; then
        printf '\e[1;7m  %s  \e[0m\n' "$visible"
      else
        printf '  %s\n' "$visible"
      fi
    done
  fi

  render_preview
}

render

while true; do
  IFS= read -rsn1 key

  case "$key" in
    j)
      if [[ "${#CURRENT_PANES[@]}" -gt 0 && "$SELECTED" -lt $((${#CURRENT_PANES[@]} - 1)) ]]; then
        ((SELECTED++))
      fi
      render
      ;;
    k)
      if [[ "${#CURRENT_PANES[@]}" -gt 0 && "$SELECTED" -gt 0 ]]; then
        ((SELECTED--))
      fi
      render
      ;;
    v | "")
      join_pane "-h"
      ;;
    h)
      join_pane ""
      ;;
    $'\t')
      if [[ "${#SESSIONS[@]}" -gt 1 ]]; then
        ACTIVE_TAB=$(( (ACTIVE_TAB + 1) % ${#SESSIONS[@]} ))
        load_active_tab
        render
      fi
      ;;
    [1-9])
      idx=$((key - 1))
      if [[ "$idx" -lt "${#SESSIONS[@]}" ]]; then
        ACTIVE_TAB=$idx
        load_active_tab
        render
      fi
      ;;
    $'\x1b')
      extra=""
      while IFS= read -rsn1 -t 0.1 ch; do
        extra+="$ch"
      done
      case "$extra" in
        '[A')
          if [[ "${#CURRENT_PANES[@]}" -gt 0 && "$SELECTED" -gt 0 ]]; then
            ((SELECTED--))
          fi
          render
          ;;
        '[B')
          if [[ "${#CURRENT_PANES[@]}" -gt 0 && "$SELECTED" -lt $((${#CURRENT_PANES[@]} - 1)) ]]; then
            ((SELECTED++))
          fi
          render
          ;;
        '[Z')
          if [[ "${#SESSIONS[@]}" -gt 1 ]]; then
            ACTIVE_TAB=$(( (ACTIVE_TAB - 1 + ${#SESSIONS[@]}) % ${#SESSIONS[@]} ))
            load_active_tab
            render
          fi
          ;;
        *)
          if [[ -z "$extra" ]]; then
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
