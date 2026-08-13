#!/bin/zsh
set -e

# Apply multiple patches to the given directory if it has no uncommitted changes.
apply_patch() {
    local dir="$1"
    shift
    if [ -z "$(git -C "$dir" status --porcelain --ignore-submodules=all)" ]; then
        git apply --directory="$dir" "$@"
        echo "Applied patches to $dir"
    else
        echo "Skipping $dir: has uncommitted changes"
    fi
}

apply_patch fcitx5 patches/*(N)
apply_patch fcitx5-webview/webview fcitx5-webview/patches/webview.patch
