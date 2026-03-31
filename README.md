# tmux-visual-join

A tmux plugin that provides an interactive popup for pulling panes from other windows into your current window.

![screenshot](screenshot.png)

## Installation

### With [TPM](https://github.com/tmux-plugins/tpm)

Add to your `.tmux.conf`:

```tmux
set -g @plugin 'jd/tmux-visual-join'
```

Then press `prefix + I` to install.

### Manual

Clone the repo and source it in your `.tmux.conf`:

```tmux
run-shell '/path/to/tmux-visual-join/visual-join.tmux'
```

## Usage

Press `prefix + m` to open the pane picker popup. It lists all panes in your current session except those in the current window.

| Key              | Action                              |
|------------------|-------------------------------------|
| `j` / `Down`     | Move selection down                 |
| `k` / `Up`       | Move selection up                   |
| `v` or `Enter`   | Join pane as vertical split (side by side) |
| `h`              | Join pane as horizontal split (stacked)    |
| `Esc` / `q`      | Cancel                              |

## Configuration

Override the default keybinding in `.tmux.conf`:

```tmux
set -g @visual-join-key 'P'
```

## Requirements

- tmux 3.2+ (for `display-popup` support)
- bash 4+
