#!/usr/bin/env python3
"""Customize the shipped 3.26.10.401 native theme service at package time.

Usage: python3 theme.py --package-root "$out"
   or: python3 theme.py --themes-root "$out/app/wemeet/bin/themes"

The modern Qt theme consumer calls ResourceThemeColorManager; it does not read
modern colors from themes/default/styles/color.json. Both 88-key maps live in
the framework's static initializer. theme.json records each recovered token
with one vendor/replacement ARGB value. Patch both its uint32 immediate and
string operand: Qt's numeric getter and QSS string getter need the same value.
Retain every key, API, and interaction state; never rewrite pooled white/black
constants. Some NXUI buttons and embedded assets use separate color producers.

This exact-build patch puts NUL-terminated #AARRGGBB strings in existing verified
ELF padding and extends its first PT_LOAD to cover them. It adds no segment,
changes no section addresses, and grows no file. Set dontStrip = true: strip
may remove unsectioned padding. The original library is saved beside it as
.vendor-original.gz, protected from ELF fixup. Invoke before autoPatchelf;
a subsequent invocation after fixup is also accepted when the mapped patched
text and palette are unchanged.

The palette changes 45 light and 50 dark tokens: blue primary/link states, slate
text, outlines, and neutral surfaces. White button foregrounds are retained;
white-on-primary contrast is 6.23/6.34 (light/dark), pressed 8.42/7.97. Vendor
danger/success/warning colors, video overlays, alpha masks, bitmap icons, fonts,
and layout resources stay intact. Home, meeting, recording indicators and share
selection have partial visual coverage; primary NXUI buttons, dark mode and
embedded web screens remain separate unverified surfaces.

Evidence: _reference/wemeet/theme-boundary/consumer-evidence.json,
initializer-observation.json and compiled-map.asm. This establishes native
token consumption, not visual coverage of every screen.
"""

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile


# Pinned executable .text, independent of Nix's interpreter/RPATH rewriting.
TEXT_VA = 0x6B36B0
TEXT_SIZE = 0x64FD2C
PALETTE_VA = 0x10AAD8C
PADDING_END = 0x10AB888


def load_segments(data):
    """Read only this pinned ELF64 little-endian x86-64 layout."""
    if data[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", data, 18)[0] != 62:
        raise ValueError("expected the x86-64 little-endian vendor ELF")
    phoff = struct.unpack_from("<Q", data, 32)[0]
    entsize, count = struct.unpack_from("<HH", data, 54)
    if entsize != 56 or phoff + entsize * count > len(data):
        raise ValueError("unsupported ELF program header layout")
    segments = []
    for index in range(count):
        header = phoff + index * entsize
        kind, flags, offset, va, _, filesz, memsz, alignment = struct.unpack_from(
            "<IIQQQQQQ", data, header
        )
        if kind == 1:
            if offset + filesz > len(data) or filesz > memsz:
                raise ValueError("invalid loadable segment extent")
            segments.append((header, flags, offset, va, filesz, memsz, alignment))
    return segments


def file_offset(segments, va, size):
    matches = [offset + va - start for _, _, offset, start, length, _, _ in segments
               if start <= va and va + size <= start + length]
    if len(matches) != 1:
        raise ValueError(f"address 0x{va:x} is not uniquely file-backed")
    return matches[0]


def read_c_string(data, segments, va):
    offset = file_offset(segments, va, 1)
    end = data.find(b"\0", offset, offset + 128)
    if end < 0:
        raise ValueError("unterminated theme literal")
    file_offset(segments, va, end - offset + 1)
    return bytes(data[offset:end]).decode("ascii")


def operand_target(data, segments, va):
    offset = file_offset(segments, va, 7)
    if data[offset:offset + 3] != b"\x48\x8d\x35":
        raise ValueError(f"unexpected theme initializer opcode at 0x{va:x}")
    return va + 7 + struct.unpack_from("<i", data, offset + 3)[0]


def make_patch(source, manifest):
    segments = load_segments(source)
    text = file_offset(segments, TEXT_VA, TEXT_SIZE)
    if hashlib.sha256(source[text:text + TEXT_SIZE]).hexdigest() != manifest["text_sha256"]:
        raise ValueError("unsupported vendor code: expected Tencent Meeting 3.26.10.401")

    first = [segment for segment in segments if segment[3] == 0 and segment[2] == 0]
    if len(first) != 1:
        raise ValueError("expected the original zero-based loadable segment")
    header, flags, _, _, filesz, memsz, _ = first[0]
    if flags != 5 or filesz != PALETTE_VA or memsz != PALETTE_VA:
        raise ValueError("unsupported vendor segment extent; apply before package fixup")
    if not any(segment[2] == PADDING_END and segment[3] == 0x12AB888 for segment in segments):
        raise ValueError("vendor padding boundary changed")
    if any(source[PALETTE_VA:PADDING_END]):
        raise ValueError("palette padding is not unused zero bytes")

    colors = sorted({token["value"] for mode in manifest["modes"].values()
                     for token in mode["tokens"] if "value" in token})
    payload = bytearray()
    addresses = {}
    for color in colors:
        if len(color) != 9 or color[0] != "#" or any(c not in "0123456789ABCDEF" for c in color[1:]):
            raise ValueError(f"invalid #AARRGGBB palette value {color!r}")
        addresses[color] = PALETTE_VA + len(payload)
        payload.extend(color.encode("ascii") + b"\0")
    end = (PALETTE_VA + len(payload) + 15) & ~15
    if end > PADDING_END:
        raise ValueError("palette does not fit the verified vendor padding")

    patched = bytearray(source)
    coverage = {}
    for mode, spec in manifest["modes"].items():
        if len(spec["tokens"]) != 88 or spec["stride"] != 133:
            raise ValueError("theme manifest shape differs from the recovered initializer")
        coverage[mode] = []
        for index, token in enumerate(spec["tokens"]):
            value_va = int(spec["value_instruction_va"], 16) + index * spec["stride"]
            key_va = value_va + 31
            key = read_c_string(source, segments, operand_target(source, segments, key_va))
            old = read_c_string(source, segments, operand_target(source, segments, value_va))
            if key != token["name"] or old != token["vendor"]:
                raise ValueError(f"vendor theme pair changed at {mode}/{token['name']}")
            # Each entry is {uint32 ARGB, string ARGB}. Qt's numeric service
            # getter consumes the immediate, while QSS can use the string.
            numeric_va = value_va - (60 if index == 0 else 53)
            numeric = file_offset(segments, numeric_va, 10)
            if (source[numeric:numeric + 2] != b"\xc7\x85" or
                    struct.unpack_from("<I", source, numeric + 6)[0] != int(token["vendor"][1:], 16)):
                raise ValueError(f"vendor numeric theme value changed at {mode}/{token['name']}")
            if "value" not in token:
                continue
            displacement = addresses[token["value"]] - (value_va + 7)
            struct.pack_into("<i", patched, file_offset(segments, value_va, 7) + 3, displacement)
            struct.pack_into("<I", patched, numeric + 6, int(token["value"][1:], 16))
            coverage[mode].append(token["name"])

    patched[PALETTE_VA:PALETTE_VA + len(payload)] = payload
    struct.pack_into("<QQ", patched, header + 32, end, end)
    return patched, bytes(payload), coverage


def already_patched(current, expected, payload):
    segments = load_segments(current)
    offset = file_offset(segments, TEXT_VA, TEXT_SIZE)
    expected_offset = file_offset(load_segments(expected), TEXT_VA, TEXT_SIZE)
    if current[offset:offset + TEXT_SIZE] != expected[expected_offset:expected_offset + TEXT_SIZE]:
        return False
    palette = file_offset(segments, PALETTE_VA, len(payload))
    return current[palette:palette + len(payload)] == payload


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    roots = parser.add_mutually_exclusive_group(required=True)
    roots.add_argument("--package-root", type=Path)
    roots.add_argument("--themes-root", type=Path)
    args = parser.parse_args()
    themes = (args.package_root / "app/wemeet/bin/themes") if args.package_root else args.themes_root
    if not (themes / "default/styles/color.json").is_file():
        parser.error(f"missing vendor theme resources: {themes}")
    library = themes.parent.parent / "lib/libwemeet_framework.so"
    if not library.is_file():
        parser.error("modern theme colors are compiled in ../lib/libwemeet_framework.so; a detached themes tree cannot customize them")
    if library.is_symlink():
        parser.error("dereference the package's library copy before customization")

    manifest = json.loads(Path(__file__).with_name("theme.json").read_text(encoding="utf-8"))
    # Compressed so strip/autoPatchelf cannot rewrite the original during fixup.
    backup = library.with_name(library.name + ".vendor-original.gz")
    current = library.read_bytes()
    try:
        source = gzip.decompress(backup.read_bytes()) if backup.exists() else current
        patched, payload, coverage = make_patch(source, manifest)
        if backup.exists() and already_patched(current, patched, payload):
            print(json.dumps({"status": "already-customized", "tokens": coverage}, sort_keys=True))
            return
        if backup.exists() and current != source:
            raise ValueError("library changed since its vendor backup; refusing to overwrite unrelated modifications")
        if not backup.exists():
            with backup.open("xb") as stream:
                stream.write(gzip.compress(current, mtime=0))
        mode = library.stat().st_mode & 0o777
        descriptor, temporary = tempfile.mkstemp(prefix=".wemeet-theme-", dir=library.parent)
        try:
            with os.fdopen(descriptor, "wb") as stream:
                stream.write(patched)
            os.chmod(temporary, mode)
            os.replace(temporary, library)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    except (OSError, ValueError, struct.error) as error:
        parser.error(str(error))
    print(json.dumps({"status": "customized", "tokens": coverage}, sort_keys=True))


if __name__ == "__main__":
    main()
