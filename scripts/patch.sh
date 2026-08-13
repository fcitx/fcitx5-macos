#!/bin/zsh
set -e

apply_patch() {
    local dir="$1"
    local patch="$2"
    if [ -z "$(git -C "$dir" status --porcelain --ignore-submodules=all)" ]; then
        git apply --directory="$dir" "$patch"
        echo "Applied $patch"
    else
        echo "Skipping $patch: $dir has uncommitted changes"
    fi
}

for patch in patches/*(N); do
    apply_patch fcitx5 "$patch"
done

apply_patch fcitx5-webview/webview fcitx5-webview/patches/webview.patch
