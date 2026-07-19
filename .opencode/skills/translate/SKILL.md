---
name: translate
description: Translate fcitx5-macos localization files (Swift .strings and C++ gettext .po) between English, Simplified Chinese, Traditional Chinese, Russian, Vietnamese, and other languages
---

# Translation Reference

This skill provides format rules, terminology, and guidelines for translating fcitx5-macos. The `/translate` command orchestrates the workflow.

## Project Overview

fcitx5-macos has **two parallel i18n systems**:

| System | Source code | Template | Locale files | Encoding |
|--------|------------|----------|-------------|----------|
| Swift (Apple) | `NSLocalizedString()` in Swift | `assets/en.lproj/Localizable.strings` | `assets/<locale>.lproj/*.strings` | **UTF-16 LE** |
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
| vi | vi | Vietnamese |

## Swift Localization (.strings)

### File Format

Apple `.strings` format, UTF-16 LE (little-endian) encoded. Each entry is:

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

InfoPlist.strings exist in `en`, `zh-Hans`, `zh-Hant`, and `ru` locales. Content is the app name (`Fcitx5`) and bundle identifiers — do NOT translate. For new locales, create `InfoPlist.strings` with identical content.

### Editing Rules

- **Encoding**: Files MUST be UTF-16 **LE (little-endian)** with BOM (`FF FE`). NOT UTF-16 BE. The lint script (`scripts/lint.sh`) verifies encoding via `file` command which checks for `UTF-16, little-endian text`.

  **Writing UTF-16 LE in Python — pick ONE approach, never combine them:**

  ```python
  # Option A: use utf-16 codec (automatically adds BOM — do NOT manually write \ufeff)
  with open(path, 'w', encoding='utf-16') as f:
      f.write('"key" = "value";\n')

  # Option B: use utf-16-le codec (manually write BOM)
  with open(path, 'wb') as f:
      f.write(b'\xff\xfe')  # BOM
      f.write('"key" = "value";\n'.encode('utf-16-le'))
  ```

  **Common mistake**: Using `utf-16` encoding AND manually writing `\ufeff` results in a double BOM, which `file` misidentifies (e.g. as "AIX core file"). This breaks `lint.sh`.
- **Format**: Each line must be `"key" = "value";`. No trailing whitespace.
- **Comments/blank lines**: Stripped in non-English files. Do not add them.
- **New keys**: Add to the English file first, then run the merge script, or add the key to all locale files manually.
- **Placeholder tokens**: `%@`, `%d`, `%s`, `%1$@`, `%2$@` etc. MUST be preserved exactly. Do not translate them.
- **Quote escaping**: Any literal `"` inside a key or value MUST be escaped as `\"`. This includes quotes around product names, UI terms, etc. (e.g. `"\"%@\" notification is disabled"` not `""%@" notification is disabled"`). Run `python3 scripts/validate-strings.py assets/<locale>.lproj/Localizable.strings` after writing to verify.
- **Strings that are already paths or identifiers** (e.g. `"/Library/Input Methods/Fcitx5.app"`) should NOT be translated — keep the value identical to the English key.

### Creating a New Language

When adding a language that doesn't exist yet (e.g. `vi`):

1. **Run sync first** to ensure `po/base.pot` and `assets/en.lproj/Localizable.strings` are up to date:
   ```sh
   cmake --build build/$(uname -m) --target GenerateStrings
   cmake --build build/$(uname -m) --target pot
   ```
   Verify `build/<arch>` exists (use `ls build/` to check).

2. **Create `po/<lang>.po`** from `po/base.pot`:
   - Copy the header block from an existing `.po` file (e.g. `zh_CN.po`) and adapt it.
   - Set `Language: <lang>`, update `Last-Translator` and `PO-Revision-Date`.
   - Set `Content-Transfer-Encoding: 8bit` (NOT `eight` — this is the standard gettext value).
   - Translate every `msgstr`.

3. **Create `assets/<lproj>/Localizable.strings`** in UTF-16 LE with BOM.
   - Copy all entries from `assets/en.lproj/Localizable.strings`.
   - Replace each value with the translation.
   - Run `python3 scripts/validate-strings.py assets/<lproj>/Localizable.strings` to verify.

4. **Create `assets/<lproj>/InfoPlist.strings`** — copy from `en.lproj` (content is identical across locales).

5. **Update `po/LINGUAS`** — add the POSIX locale code (e.g. `vi`), one per line, in alphabetical order.

6. **Update `assets/CMakeLists.txt`** — add the Apple locale code (e.g. `vi`) to the `LOCALES` list, in alphabetical order.

7. **Update `fcitx5-beast/po/LINGUAS`** — add the POSIX locale code if the submodule has a `.po` file for it.

8. **Create `fcitx5-beast/po/<lang>.po`** if it doesn't exist — same process as step 2, using `fcitx5-beast/po/base.pot` and an existing `.po` as template.

## C++ Localization (gettext .po)

### File Format

Standard GNU gettext format. Each entry:

```po
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
- **Content-Transfer-Encoding**: Must be `8bit` (the standard gettext value for UTF-8 content).
- **Format**: Follow standard `.po` file conventions exactly.
- **Placeholder tokens**: `%d`, `%s`, `%1$d`, `%1$s` etc. MUST be preserved exactly.
- **`fuzzy` flag**: Only use when you are unsure of the translation. Mark it and leave a comment explaining the uncertainty. Fuzzy entries are NOT shown to users.
- **Empty `msgstr ""`**: Means untranslated. Every `msgid` must have a non-empty `msgstr` in completed translations.

### PO File Header Template

Use this as the header when creating a new `.po` file, adapting the fields:

```po
msgid ""
msgstr ""
"Project-Id-Version: fcitx 5\n"
"Report-Msgid-Bugs-To: \n"
"POT-Creation-Date: YYYY-MM-DD HH:MM±ZZZZ\n"
"PO-Revision-Date: YYYY-MM-DD HH:MM±ZZZZ\n"
"Last-Translator: Your Name <email>\n"
"Language-Team: Language Name\n"
"Language: <lang>\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
```

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
8. **UI option values in instructional text** — When a translated string references UI option names that appear as actual labels in the app (e.g. "None", "Blur", "Light", "Dark"), translate them to match the target language's UI labels. Do not leave them as English within otherwise translated text.

## Output Format

When translating, present changes clearly:

- For **Swift .strings**: Show the full `"key" = "value";` lines that were added or modified.
- For **C++ .po**: Show the `msgid`/`msgstr` blocks that were added or modified.
- Group changes by file.
- If adding new entries, mention the source file and line number.
