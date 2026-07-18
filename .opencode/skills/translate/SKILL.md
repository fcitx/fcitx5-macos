---
name: translate
description: Translate fcitx5-macos localization files (Swift .strings and C++ gettext .po) between English, Simplified Chinese, Traditional Chinese, Russian, and other languages
---

# Translation Reference

This skill provides format rules, terminology, and guidelines for translating fcitx5-macos. The `/translate` command orchestrates the workflow.

## Project Overview

fcitx5-macos has **two parallel i18n systems**:

| System | Source code | Template | Locale files | Encoding |
|--------|------------|----------|-------------|----------|
| Swift (Apple) | `NSLocalizedString()` in Swift | `assets/en.lproj/Localizable.strings` | `assets/<locale>.lproj/*.strings` | **UTF-16** |
| C++ (gettext) | `_()` / `N_()` in C++ headers | `po/base.pot` | `po/<locale>.po` | UTF-8 |

The fcitx5-beast submodule (`fcitx5-beast/po/`) has its own separate gettext files.

### Locale Mapping

| POSIX code (po) | Apple lproj | Language |
|-----------------|-------------|----------|
| zh_CN | zh-Hans | Simplified Chinese |
| zh_TW | zh-Hant | Traditional Chinese |
| ru | ru | Russian |
| ja | ja | Japanese |
| ko | ko | Korean |
| de | de | German |
| fr | fr | French |
| es | es | Spanish |

## Swift Localization (.strings)

### File Format

Apple `.strings` format, UTF-16 encoded. Each entry is:

```
"key" = "value";
```

- In `en.lproj/Localizable.strings`, key and value are **identical** (e.g. `"Add" = "Add";`).
- In other locales, only the value is translated.
- The translated files contain **no comments and no blank lines** between entries.

### Files

| File | Path |
|------|------|
| English (source of truth) | `assets/en.lproj/Localizable.strings` |
| Simplified Chinese | `assets/zh-Hans.lproj/Localizable.strings` |
| Traditional Chinese | `assets/zh-Hant.lproj/Localizable.strings` |
| Russian | `assets/ru.lproj/Localizable.strings` |

InfoPlist.strings follow the same structure in each `.lproj` directory.

### Editing Rules

- **Encoding**: Files MUST remain UTF-16. The lint script (`scripts/lint.sh`) verifies this.
- **Format**: Each line must be `"key" = "value";`. No trailing whitespace.
- **Comments/blank lines**: Stripped in non-English files. Do not add them.
- **New keys**: Add to the English file first, then run the merge script, or add the key to all locale files manually.
- **Placeholder tokens**: `%@`, `%d`, `%s`, `%1$@`, `%2$@` etc. MUST be preserved exactly. Do not translate them.
- **Strings that are already paths or identifiers** (e.g. `"/Library/Input Methods/Fcitx5.app"`) should NOT be translated — keep the value identical to the English key.

## C++ Localization (gettext .po)

### File Format

Standard GNU gettext format. Each entry:

```
#: source/file.h:line_number
msgid "English text"
msgstr "Translated text"
```

### Files

**Main project:**

| File | Path |
|------|------|
| POT template | `po/base.pot` |
| Language list | `po/LINGUAS` |

**fcitx5-beast submodule:**

| File | Path |
|------|------|
| POT template | `fcitx5-beast/po/base.pot` |
| Language list | `fcitx5-beast/po/LINGUAS` |

### Editing Rules

- **Encoding**: UTF-8.
- **Header**: Update `PO-Revision-Date` and `Last-Translator` when modifying a file.
- **Format**: Follow standard `.po` file conventions exactly.
- **Placeholder tokens**: `%d`, `%s`, `%1$d`, `%1$s` etc. MUST be preserved exactly.
- **`fuzzy` flag**: Only use when you are unsure of the translation. Mark it and leave a comment explaining the uncertainty. Fuzzy entries are NOT shown to users.
- **Empty `msgstr ""`**: Means untranslated. Every `msgid` must have a non-empty `msgstr` in completed translations.

### Validation

```sh
msgfmt -c po/<lang>.po -o /dev/null
```

Checks for format errors, missing translations, and placeholder mismatches.

## Terminology Reference

Use these translations consistently across both Swift and C++ files:

| English | Simplified Chinese | Traditional Chinese | Russian |
|---------|-------------------|--------------------|---------| 
| input method | 输入法 | 輸入法 | метод ввода |
| addon | 附加组件 | 附加元件 | дополнение |
| configuration / config | 配置 | 設定 | настройка |
| profile | 配置方案 | 設定方案 | профиль |
| status bar | 状态栏 | 狀態列 | строка состояния |
| global config | 全局配置 | 全域設定 | глобальные настройки |
| addon config | 附加组件配置 | 附加元件設定 | настройка дополнения |
| clipboard | 剪贴板 | 剪貼簿 | буфер обмена |
| pasteboard | 剪贴板 | 剪貼簿 | буфер обмена |
| keyboard layout | 键盘布局 | 鍵盤配置 | раскладка клавиатуры |
| custom phrase | 自定义词组 | 自訂詞組 | пользовательская фраза |
| plugin | 插件 | 外掛程式 | плагин |
| shortcut | 快捷键 | 快捷鍵 | сочетание клавиш |
| vim mode | Vim 模式 | Vim 模式 | режим Vim |

## General Translation Rules

1. **Keep translations concise** — UI space is limited. Prefer short, natural phrasing.
2. **Maintain consistency** — If a term is translated one way, use the same translation everywhere.
3. **Respect platform conventions** — Use terminology that macOS users would expect (e.g. "Settings" not "Preferences" for zh-Hans if that's the established pattern).
4. **No machine-translation artifacts** — Avoid overly formal or stilted phrasing. Translations should read naturally.
5. **Do not translate** — brand names (Fcitx5, Boost.Beast), file paths, command names, technical identifiers, or code. Also keep well-known UI product names or design terms in their original form if translating them would cause confusion (e.g. "Liquid Glass", "Dynamic Island").
6. **Preserve format specifiers** — all `%@`, `%d`, `%s`, `%1$@`, positional specifiers etc. must appear in the translation in the same order.
7. **Punctuation** — Use the punctuation conventions of the target language (e.g. Chinese full-width ？。、 vs English half-width ?.).

## Output Format

When translating, present changes clearly:

- For **Swift .strings**: Show the full `"key" = "value";` lines that were added or modified.
- For **C++ .po**: Show the `msgid`/`msgstr` blocks that were added or modified.
- Group changes by file.
- If adding new entries, mention the source file and line number.
