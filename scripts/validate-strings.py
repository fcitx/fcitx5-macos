#!/usr/bin/env python3
"""Validate Apple .strings files for correct quote escaping and key consistency."""

import sys
import re
import os


def parse_keys(path: str):
    keys = []
    try:
        with open(path, "r", encoding="utf-16") as f:
            for line in f:
                line = line.rstrip("\n")
                m = re.match(r'^"(.*)" = ".*";$', line)
                if m:
                    keys.append(m.group(1))
    except Exception:
        pass
    return keys


def check_strings_file(path: str, en_keys=None):
    errors = []
    try:
        with open(path, "r", encoding="utf-16") as f:
            for lineno, line in enumerate(f, 1):
                line = line.rstrip("\n")
                m = re.match(r'^"(.*)" = "(.*)";$', line)
                if not m:
                    continue
                for group_name, group_val in [("key", m.group(1)), ("value", m.group(2))]:
                    i = 0
                    while i < len(group_val):
                        if group_val[i] == "\\":
                            i += 2
                        elif group_val[i] == '"':
                            errors.append(
                                f"  {path}:{lineno}: unescaped quote in {group_name}: ...{group_val[max(0,i-10):i+10]}..."
                            )
                            break
                        else:
                            i += 1
    except Exception as e:
        errors.append(f"  {path}: {e}")

    if en_keys is not None:
        file_keys = parse_keys(path)
        file_key_set = set(file_keys)
        en_key_set = set(en_keys)
        missing = en_key_set - file_key_set
        extra = file_key_set - en_key_set
        if missing:
            errors.append(f"  {path}: missing keys: {', '.join(sorted(missing))}")
        if extra:
            errors.append(f"  {path}: extra keys: {', '.join(sorted(extra))}")

    return errors


if __name__ == "__main__":
    all_errors = []
    en_keys = None
    for path in sys.argv[1:]:
        if "en.lproj" in path:
            en_keys = parse_keys(path)
            break
    if en_keys is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        en_path = os.path.join(script_dir, "..", "assets", "en.lproj", "Localizable.strings")
        en_path = os.path.normpath(en_path)
        if os.path.exists(en_path):
            en_keys = parse_keys(en_path)
    for path in sys.argv[1:]:
        if "en.lproj" in path:
            continue
        all_errors.extend(check_strings_file(path, en_keys))
    if all_errors:
        print("Localizable.strings validation errors:")
        for e in all_errors:
            print(e)
        sys.exit(1)
