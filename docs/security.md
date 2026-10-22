# Security

Small attack surface: a local, single-user menu-bar app with no network, no accounts and no stored secrets.

The real risks:
- **Command injection.** Every `osascript`/`defaults` invocation is built from fixed strings in
  code. Arguments go through `Process` argv, never a shell. Only `--set/--run <id>` reads
  external input, and it is matched against known ids.
- **Destructive actions.** Empty Trash confirms first. Eject Disks filters to `/Volumes/*` and
  never touches the root or internal system volumes (unit-tested rule).
- **Private API calls.** These are guarded by `responds(to:)` / `dlsym` checks, so a changed macOS hides the row instead of crashing.
