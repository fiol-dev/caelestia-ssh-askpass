# caelestia-ssh-askpass

An `SSH_ASKPASS` implementation that looks like it belongs in
[caelestia](https://github.com/caelestia-dots/shell) instead of popping up a
random Motif/GTK dialog. It's a small [Quickshell](https://quickshell.org)
QML panel that reads caelestia's live Material You palette from
`~/.local/state/caelestia/scheme.json`, so it re-colours itself automatically
whenever your wallpaper/scheme changes — falling back to a static dark
palette if that file isn't there.

Requires Hyprland (or another wlroots compositor) and `quickshell`, since the
prompt is a `wlr-layer-shell` panel via `Quickshell.Wayland`.

## How it works

`bin/caelestia-ssh-askpass` is the actual askpass executable. Per the
[askpass protocol](https://man.openbsd.org/ssh-add#SSH_ASKPASS), `ssh`/`ssh-add`
run it with the prompt text as `$1` and read the password back from its
stdout. The script:

1. Creates a one-shot FIFO in `$XDG_RUNTIME_DIR`.
2. Launches `main.qml` via `quickshell -p`, passing the prompt and FIFO path
   as environment variables (`ASKPASS_PROMPT`, `ASKPASS_FIFO`).
3. Blocks on `cat` of the FIFO until the QML window submits (Enter/Unlock) or
   cancels (Escape/Cancel) — either way it writes to the FIFO via
   `Quickshell.execDetached(["sh", "-c", ...])` with the password passed as an
   argv value, never interpolated into a shell string.
4. Prints whatever came back to its own stdout and exits 0, or exits 1 on an
   empty (cancelled) result.

The password only ever touches a FIFO in tmpfs (`$XDG_RUNTIME_DIR`, mode
600) — it's never written to a regular file.

## Install

```sh
git clone <this-repo> ~/Projects/caelestia-ssh-askpass
~/Projects/caelestia-ssh-askpass/install.sh
```

This symlinks `bin/caelestia-ssh-askpass` into `~/.local/bin`. Then point ssh
at it — for fish, in `~/.config/fish/conf.d/ssh-agent.fish` or similar:

```fish
set -gx SSH_ASKPASS caelestia-ssh-askpass
set -gx SSH_ASKPASS_REQUIRE force
```

(`SSH_ASKPASS_REQUIRE force` makes ssh always use the GUI prompt instead of
falling back to a terminal prompt, matching the old `x11-ssh-askpass`
behaviour.)

## Optional: blur

Caelestia's own popups get blurred by a Hyprland layer rule matching their
`caelestia-*` namespace prefix. This panel uses the namespace
`caelestia-ssh-askpass`, so if your Hyprland config already has a rule like

```
layerrule = blur, namespace:^(caelestia-.*)$
```

it's picked up for free. Otherwise add one scoped to just this panel:

```
layerrule = blur, namespace:^(caelestia-ssh-askpass)$
layerrule = ignorealpha 0.3, namespace:^(caelestia-ssh-askpass)$
```

## Notes

This approximates caelestia's lock-screen look (rounded surface container,
M3 dynamic colours, Google Sans Flex) rather than reusing its actual QML
components — those live inside the caelestia-shell binary's own `qs.*`
module namespace and singletons (`Tokens`, `Colours`, PAM integration, the
per-character blob animation on the lock screen's password field) and aren't
importable from a standalone Quickshell instance. If caelestia ever exposes
those as a public QML module, this could import them directly instead of
duplicating a handful of colour roles.
