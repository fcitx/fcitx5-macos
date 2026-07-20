# AI Agent Instructions

## Project Overview

fcitx5-macos is a macOS input method editor built with CMake + Ninja. Uses C++20 and Swift 6, targeting macOS 13.3+.

## Build

```sh
./scripts/patch.sh
cmake -B build/$(uname -m) -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build/$(uname -m)
sudo cmake --install build/$(uname -m)
```

## Translation

Use the `translate` skill (invoke via `/translate` or let the agent auto-load it) for all localization work across Swift `.strings` and C++ gettext `.po` files.
