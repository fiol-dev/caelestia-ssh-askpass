#!/usr/bin/env bash
# Symlinks bin/caelestia-ssh-askpass into ~/.local/bin.
set -euo pipefail

repo_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
target_dir="$HOME/.local/bin"
mkdir -p "$target_dir"

ln -sf "$repo_root/bin/caelestia-ssh-askpass" "$target_dir/caelestia-ssh-askpass"

echo "✓ Linked $target_dir/caelestia-ssh-askpass -> $repo_root/bin/caelestia-ssh-askpass"
echo
echo "Make sure $target_dir is on PATH, then point ssh at it, e.g. in fish:"
echo
echo '    set -gx SSH_ASKPASS caelestia-ssh-askpass'
echo '    set -gx SSH_ASKPASS_REQUIRE force'
