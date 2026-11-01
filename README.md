# Latto

Latto is a Quickshell workspace containing two projects:

- [`latto-island/`](latto-island/README.md): the standalone dynamic island for Linux.
- [`latto-bar/`](latto-bar/README.md): the Hyprland top bar with the island embedded in its center.

Each project has its own README with setup, usage and feature details. The `latto/` directory is the shared Git repository. Install from this directory with `./latto-island/install.sh` and choose the standalone island or the bar with the island embedded. The installer copies the selection into `~/.config/quickshell/latto`. Re-run it after pulling updates; use `--island` or `--bar` to select a mode directly.
