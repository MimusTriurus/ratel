#!/usr/bin/env python3
"""Converts the Jackal stage maps between the original .dat dumps and JSON.

The .dat files are java.io.DataInputStream dumps (big-endian) inherited from
meatfighter.com's Java remake: map-N.dat holds the tile grid plus the "after
destruction" tile of every group, types-N.dat holds the collision grid plus the
matching types, and enemies[-hard]-N.dat holds the spawn triggers. Authoring
those by hand is impossible, so stage-N.json is the editable form.

    python tools/map_json.py export     # .dat -> assets/maps/stage-N.json
    python tools/map_json.py verify     # json -> .dat in memory, byte compare

verify is the point of the exercise: it re-encodes each JSON back into the
original binary layout and compares it with the shipped file, which proves the
JSON carries everything the loader reads.

dirs-N.dat is deliberately left alone. It is derived data (a 2M-entry flow
field computed from the collision grid), not something anyone edits, and it
would be several MB of text per stage.
"""

import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPS = ROOT / "assets" / "maps"
TRIGGERS_GD = ROOT / "src" / "core" / "triggers.gd"

# Mirrors GameMode.TYPE_* . One character per tile keeps a row reviewable in a
# diff; the legend is written into every stage file so it stays self-describing.
TYPE_CHARS = {0: "#", 1: ".", 2: "S", 3: "~", 4: "%", 5: ">"}
TYPE_NAMES = {0: "SOLID", 1: "EMPTY", 2: "SHIELD", 3: "WATER", 4: "SWAMP",
              5: "CONVEYOR"}
CHAR_TYPES = {c: t for t, c in TYPE_CHARS.items()}


def trigger_names():
    """The 61 Triggers constants, in value order, parsed from the GDScript."""
    text = TRIGGERS_GD.read_text(encoding="utf-8")
    pairs = re.findall(r"^const\s+([A-Z0-9_]+)\s*:=\s*(\d+)$", text, re.M)
    names = [None] * len(pairs)
    for name, value in pairs:
        names[int(value)] = name
    if any(n is None for n in names):
        raise SystemExit("triggers.gd is not a dense 0..N constant list")
    return names


class Reader:
    def __init__(self, path):
        self.b = Path(path).read_bytes()
        self.o = 0

    def s16(self):
        v = struct.unpack_from(">h", self.b, self.o)[0]
        self.o += 2
        return v

    def at_end(self):
        return self.o == len(self.b)


def read_grid(path):
    r = Reader(path)
    w, h = r.s16(), r.s16()
    rows = [list(struct.unpack_from(">%dh" % w, r.b, r.o + 2 * w * y))
            for y in range(h)]
    r.o += 2 * w * h
    groups = []
    for _ in range(r.s16()):
        count = r.s16()
        groups.append([(r.s16(), r.s16(), r.s16()) for _ in range(count)])
    if not r.at_end():
        raise SystemExit("%s: %d trailing bytes" % (path, len(r.b) - r.o))
    return w, h, rows, groups


def read_triggers(path, names):
    r = Reader(path)
    count = r.s16()
    out = []
    for _ in range(count):
        index, x, y = r.s16(), r.s16(), r.s16()
        out.append({"type": names[index], "x": x, "y": y})
    if not r.at_end():
        raise SystemExit("%s: %d trailing bytes" % (path, len(r.b) - r.o))
    return out


def export_stage(index, names):
    w, h, tiles, tile_groups = read_grid(MAPS / ("map-%d.dat" % index))
    tw, th, types, type_groups = read_grid(MAPS / ("types-%d.dat" % index))
    if (w, h) != (tw, th):
        raise SystemExit("stage %d: map and types disagree on size" % index)

    # The loader pairs the two group lists positionally and drops the second
    # copy of the coordinates, so they can be merged into one cell record.
    groups = []
    for i, (a, b) in enumerate(zip(tile_groups, type_groups)):
        cells = []
        for (x, y, tile), (x2, y2, kind) in zip(a, b):
            if (x, y) != (x2, y2):
                raise SystemExit("stage %d group %d: cell mismatch" % (index, i))
            cells.append([x, y, tile, TYPE_CHARS[kind]])
        groups.append({"index": i, "cells": cells})

    return {
        "stage": index,
        "width": w,
        "height": h,
        "type_legend": {TYPE_CHARS[t]: TYPE_NAMES[t] for t in sorted(TYPE_NAMES)},
        "types": ["".join(TYPE_CHARS[t] for t in row) for row in types],
        "tiles": tiles,
        "groups": groups,
        "triggers": {
            "normal": read_triggers(MAPS / ("enemies-%d.dat" % index), names),
            "hard": read_triggers(MAPS / ("enemies-hard-%d.dat" % index), names),
        },
    }


def export_sizes(names):
    r = Reader(MAPS / "sizes.dat")
    count = r.s16()
    out = {}
    for i in range(count):
        out[names[i]] = {"width": r.s16(), "height": r.s16()}
    if not r.at_end():
        raise SystemExit("sizes.dat: trailing bytes")
    return out


# --- Writing ----------------------------------------------------------------
#
# Hand-rolled so that one map row is one line: json.dump would either put every
# tile index on its own line or the whole grid on one, and both make a diff
# useless.

def dumps_stage(doc):
    out = ["{"]
    out.append('  "stage": %d,' % doc["stage"])
    out.append('  "width": %d,' % doc["width"])
    out.append('  "height": %d,' % doc["height"])
    out.append('  "type_legend": %s,' % json.dumps(doc["type_legend"]))
    out.append('  "types": [')
    out.append(",\n".join("    %s" % json.dumps(r) for r in doc["types"]))
    out.append("  ],")
    out.append('  "tiles": [')
    out.append(",\n".join("    [%s]" % ",".join(str(t) for t in r)
                          for r in doc["tiles"]))
    out.append("  ],")
    out.append('  "groups": [')
    out.append(",\n".join(
        '    {"index": %d, "cells": [%s]}'
        % (g["index"], ", ".join(json.dumps(c) for c in g["cells"]))
        for g in doc["groups"]))
    out.append("  ],")
    out.append('  "triggers": {')
    for key, last in (("normal", False), ("hard", True)):
        out.append('    "%s": [' % key)
        out.append(",\n".join(
            '      {"type": "%s", "x": %d, "y": %d}' % (t["type"], t["x"], t["y"])
            for t in doc["triggers"][key]))
        out.append("    ]" if last else "    ],")
    out.append("  }")
    out.append("}")
    return "\n".join(out) + "\n"


# --- Re-encoding, for verify ------------------------------------------------

def pack_grid(w, h, rows, groups, cell_value):
    b = bytearray(struct.pack(">hh", w, h))
    for row in rows:
        b += struct.pack(">%dh" % w, *row)
    b += struct.pack(">h", len(groups))
    for g in groups:
        b += struct.pack(">h", len(g["cells"]))
        for cell in g["cells"]:
            b += struct.pack(">hhh", cell[0], cell[1], cell_value(cell))
    return bytes(b)


def pack_triggers(triggers, names):
    b = bytearray(struct.pack(">h", len(triggers)))
    for t in triggers:
        b += struct.pack(">hhh", names.index(t["type"]), t["x"], t["y"])
    return bytes(b)


def verify(names):
    ok = True
    for index in range(6):
        doc = json.loads(
            (MAPS / ("stage-%d.json" % index)).read_text(encoding="utf-8"))
        w, h = doc["width"], doc["height"]
        types = [[CHAR_TYPES[c] for c in row] for row in doc["types"]]

        checks = [
            ("map-%d.dat" % index,
             pack_grid(w, h, doc["tiles"], doc["groups"], lambda c: c[2])),
            ("types-%d.dat" % index,
             pack_grid(w, h, types, doc["groups"], lambda c: CHAR_TYPES[c[3]])),
            ("enemies-%d.dat" % index,
             pack_triggers(doc["triggers"]["normal"], names)),
            ("enemies-hard-%d.dat" % index,
             pack_triggers(doc["triggers"]["hard"], names)),
        ]
        for filename, rebuilt in checks:
            original = (MAPS / filename).read_bytes()
            if rebuilt == original:
                print("  ok   %-20s %6d bytes" % (filename, len(original)))
            else:
                ok = False
                shared = min(len(rebuilt), len(original))
                where = next((i for i in range(shared)
                              if rebuilt[i] != original[i]), shared)
                print("  FAIL %-20s %d vs %d bytes, first difference at %d"
                      % (filename, len(rebuilt), len(original), where))
    return ok


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "verify"
    names = trigger_names()

    if action == "export":
        for index in range(6):
            doc = export_stage(index, names)
            path = MAPS / ("stage-%d.json" % index)
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(dumps_stage(doc))
            print("wrote %s (%d KB)" % (path.name, path.stat().st_size // 1024))
        path = MAPS / "trigger-sizes.json"
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(export_sizes(names), f, indent=2)
            f.write("\n")
        print("wrote %s" % path.name)
    elif action == "verify":
        raise SystemExit(0 if verify(names) else 1)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
