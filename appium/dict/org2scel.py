#!/usr/bin/env python3

import argparse
import struct
import sys
from collections import OrderedDict
from typing import BinaryIO

HEADER: bytes = bytes(
    [0x40, 0x15, 0x00, 0x00, 0x44, 0x43, 0x53, 0x01, 0x01, 0x00, 0x00, 0x00]
)

PHRASE_OFFSET: int = 0x5C
DEL_OFFSET: int = 0x74
ENTRY_OFFSET: int = 0x120
DESC_OFFSET: int = 0x130
SOURCE_OFFSET: int = 0x338
LONG_DESC_OFFSET: int = 0x540
EXAMPLE_OFFSET: int = 0xD40
PINYIN_OFFSET: int = 0x1540

Entry = tuple[str, str, int]
PinyinMap = OrderedDict[str, int]


def utf16le_encode(text: str) -> bytes:
    """Encode string to UTF-16LE bytes."""
    return text.encode("utf-16-le")


def build_pinyin_index(entries: list[Entry]) -> tuple[PinyinMap, list[str]]:
    """Build pinyin index from entries, return (pinyin_map, pinyin_list)."""
    pinyin_set: PinyinMap = OrderedDict()
    for _, pinyin_str, _ in entries:
        for py in pinyin_str.split("'"):
            if py and py not in pinyin_set:
                pinyin_set[py] = len(pinyin_set)
    return pinyin_set, list(pinyin_set.keys())


def parse_txt_file(filepath: str) -> list[Entry]:
    """Parse libime txt file format: word<whitespace>pinyin<whitespace>[freq]"""
    entries: list[Entry] = []
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) >= 2:
                word = parts[0]
                pinyin = parts[1]
                freq = 0
                if len(parts) >= 3:
                    try:
                        freq = int(parts[2])
                    except ValueError:
                        freq = 0
                entries.append((word, pinyin, freq))
    return entries


def write_byte_array(f: BinaryIO, data: bytes) -> None:
    """Write byte array with 2-byte length prefix."""
    f.write(struct.pack("<H", len(data)))
    f.write(data)


def write_fixed_utf16_string(f: BinaryIO, text: str, max_bytes: int) -> None:
    """Write a fixed-size UTF-16LE string buffer."""
    encoded = utf16le_encode(text)
    if len(encoded) > max_bytes:
        encoded = encoded[:max_bytes]
    padding = max_bytes - len(encoded)
    f.write(encoded)
    f.write(b"\x00" * padding)


def group_entries(entries: list[Entry]) -> OrderedDict[str, list[tuple[str, int]]]:
    """Group words by their pinyin sequence."""
    grouped = OrderedDict()
    for word, pinyin_str, freq in entries:
        if pinyin_str not in grouped:
            grouped[pinyin_str] = []
        grouped[pinyin_str].append((word, freq))
    return grouped


def write_scel(
    filepath: str,
    entries: list[Entry],
    pinyin_map: PinyinMap,
    pinyin_list: list[str],
    desc: str = "",
    source: str = "",
    long_desc: str = "",
    example: str = "",
) -> None:
    """Write SCEL file."""
    grouped = group_entries(entries)

    with open(filepath, "wb") as f:
        # Write header
        f.write(HEADER)

        # Pad up to PHRASE_OFFSET
        f.write(b"\x00" * (PHRASE_OFFSET - len(HEADER)))

        # Write phrase offset & count (both 0 since we only write entries)
        f.write(struct.pack("<II", 0, 0))

        # Pad up to DEL_OFFSET
        f.write(b"\x00" * (DEL_OFFSET - f.tell()))

        # Write del offset & count (both 0)
        f.write(struct.pack("<II", 0, 0))

        # Pad up to ENTRY_OFFSET
        f.write(b"\x00" * (ENTRY_OFFSET - f.tell()))

        # Write entry count
        f.write(struct.pack("<I", len(grouped)))

        # Write description metadata
        f.seek(DESC_OFFSET)
        write_fixed_utf16_string(f, desc, SOURCE_OFFSET - DESC_OFFSET)
        write_fixed_utf16_string(f, source, LONG_DESC_OFFSET - SOURCE_OFFSET)
        write_fixed_utf16_string(f, long_desc, EXAMPLE_OFFSET - LONG_DESC_OFFSET)
        write_fixed_utf16_string(f, example, PINYIN_OFFSET - EXAMPLE_OFFSET)

        # Write pinyin and entries
        f.seek(PINYIN_OFFSET)

        # Write pinyin count
        f.write(struct.pack("<I", len(pinyin_list)))
        for idx, py in enumerate(pinyin_list):
            f.write(struct.pack("<H", idx))
            py_bytes = utf16le_encode(py)
            write_byte_array(f, py_bytes)

        # Write entry section
        for pinyin_str, words in grouped.items():
            # 1. symCount (uint16_t)
            f.write(struct.pack("<H", len(words)))

            # 2. pyindex (bytearray of uint16_t indices)
            pinyin_parts = pinyin_str.split("'")
            py_indices = [pinyin_map[py] for py in pinyin_parts if py in pinyin_map]

            py_index_bytes = b""
            for idx in py_indices:
                py_index_bytes += struct.pack("<H", idx)
            write_byte_array(f, py_index_bytes)

            # 3. For each word/symbol:
            for word, freq in words:
                word_bytes = utf16le_encode(word)
                write_byte_array(f, word_bytes)

                # Write extra buffer: 10 bytes (2 bytes freq + 8 bytes padding)
                extra_buf = struct.pack("<H", freq) + b"\x00" * 8
                write_byte_array(f, extra_buf)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert libime txt to Sogou scel format"
    )
    parser.add_argument("input", help="Input libime txt file")
    parser.add_argument("-o", "--output", help="Output scel file")
    parser.add_argument(
        "-d", "--description", default="", help="Dictionary description"
    )
    parser.add_argument("-s", "--source", default="", help="Dictionary source")
    parser.add_argument(
        "-l", "--long-description", default="", help="Dictionary long description"
    )
    parser.add_argument("--example", default="", help="Dictionary example words")

    args = parser.parse_args()

    output: str = args.output
    if not output:
        base = args.input.rsplit(".", 1)[0]
        output = base + ".scel"

    entries = parse_txt_file(args.input)
    if not entries:
        print("Error: No valid entries found", file=sys.stderr)
        sys.exit(1)

    pinyin_map, pinyin_list = build_pinyin_index(entries)

    write_scel(
        output,
        entries,
        pinyin_map,
        pinyin_list,
        desc=args.description,
        source=args.source,
        long_desc=args.long_description,
        example=args.example,
    )

    print(f"Converted {len(entries)} entries to {output}", file=sys.stderr)


if __name__ == "__main__":
    main()
