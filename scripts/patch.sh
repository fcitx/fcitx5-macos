#!/bin/zsh
set -e

git apply --directory=fcitx5 patches/*
git apply --directory=fcitx5-webview/webview fcitx5-webview/patches/webview.patch
