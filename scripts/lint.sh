set -e

find keycode macosfrontend macosnotifications webpanel src tests -name '*.cpp' -o -name '*.h' | xargs clang-format -Werror --dry-run -style=file:fcitx5/.clang-format
clang-format -Werror --dry-run macosfrontend/pasteboard.mm
swift-format lint --configuration .swift-format.json -rs macosfrontend macosnotifications src assets appium
./scripts/check-code-style.sh

ruff check appium
ruff format --check appium

localizables=$(find assets -name 'Localizable.strings')
for localizable in $localizables; do
  file $localizable | grep UTF-16
done
