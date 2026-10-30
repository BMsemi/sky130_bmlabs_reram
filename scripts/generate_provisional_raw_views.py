#!/usr/bin/env python3
"""Generate non-signoff physical placeholders for the raw-interface X2 macro.

The generated views are intentionally marked provisional. They preserve the
released Wishbone macro boundary but use synthetic perimeter pin placement and
an uncharacterized Liberty shell. They are only for floorplanning and file-flow
testing; they are not valid for LVS, timing signoff, fabrication or tapeout.
"""

import re
import struct
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NAME = "sky130_bmlabs_reram__cim32x32"
SOURCE = ROOT / "verilog" / "behavioral" / f"{NAME}.sv"
WIDTH = 1910.0
HEIGHT = 2010.14
POWER_PINS = {"VDDC1", "VDDC2", "VDDA1", "VDDA2", "VSS"}
PROVISIONAL = "PROVISIONAL - NOT FOR LVS, TIMING SIGNOFF, FABRICATION OR TAPEOUT"


def module_ports():
    text = SOURCE.read_text(errors="replace")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    match = re.search(
        rf"\bmodule\s+{re.escape(NAME)}\s*(?:#\s*\(.*?\)\s*)?\((.*?)\)\s*;",
        text,
        re.S,
    )
    if not match:
        raise RuntimeError(f"could not find module {NAME}")

    declaration = re.compile(
        r"\b(input|output|inout)\b"
        r"(?:\s+(?:wire|reg|logic|signed))*"
        r"\s*(\[[^]]+\])?\s*([A-Za-z_]\w*)"
    )
    ports = []
    for direction, bus, name in declaration.findall(match.group(1)):
        if bus:
            indexes = [int(value) for value in re.findall(r"\d+", bus)]
            if len(indexes) != 2:
                raise RuntimeError(f"unsupported bus declaration for {name}: {bus}")
            first, last = indexes
            step = 1 if last >= first else -1
            ports.extend(
                (f"{name}[{index}]", direction)
                for index in range(first, last + step, step)
            )
        else:
            ports.append((name, direction))
    return ports


def pin_geometry(ports):
    """Place pins deterministically around the macro perimeter."""
    side_groups = [[], [], [], []]
    for index, port in enumerate(ports):
        side_groups[index % 4].append(port)

    geometry = {}
    margin = 20.0
    depth = 2.91
    width = 0.30
    for side, group in enumerate(side_groups):
        span = (WIDTH if side in {0, 2} else HEIGHT) - 2 * margin
        pitch = span / (len(group) + 1)
        for index, (name, direction) in enumerate(group, 1):
            position = margin + index * pitch
            if side == 0:  # bottom
                rect = (position - width / 2, 0.0, position + width / 2, depth)
            elif side == 1:  # right
                rect = (WIDTH - depth, position - width / 2, WIDTH, position + width / 2)
            elif side == 2:  # top
                rect = (
                    position - width / 2,
                    HEIGHT - depth,
                    position + width / 2,
                    HEIGHT,
                )
            else:  # left
                rect = (0.0, position - width / 2, depth, position + width / 2)
            geometry[name] = {"direction": direction, "rect": rect}
    return geometry


def number(value):
    return f"{value:.3f}".rstrip("0").rstrip(".")


def write_lef(ports, geometry):
    lines = [
        f"# {PROVISIONAL}",
        "# Synthetic met2 pin placement derived from the behavioral interface.",
        "VERSION 5.7 ;",
        'BUSBITCHARS "[]" ;',
        'DIVIDERCHAR "/" ;',
        f"MACRO {NAME}",
        "  CLASS BLOCK ;",
        "  ORIGIN 0 0 ;",
        f"  FOREIGN {NAME} 0 0 ;",
        f"  SIZE {number(WIDTH)} BY {number(HEIGHT)} ;",
    ]
    for name, direction in ports:
        x1, y1, x2, y2 = geometry[name]["rect"]
        use = "GROUND" if name == "VSS" else "POWER" if name in POWER_PINS else "SIGNAL"
        lines.extend(
            [
                f"  PIN {name}",
                f"    DIRECTION {direction.upper()} ;",
                f"    USE {use} ;",
                "    PORT",
                "      LAYER met2 ;",
                f"        RECT {number(x1)} {number(y1)} {number(x2)} {number(y2)} ;",
                "    END",
                f"  END {name}",
            ]
        )
    lines.extend(
        [
            "  OBS",
            "    LAYER li1 ;",
            f"      RECT 0 0 {number(WIDTH)} {number(HEIGHT)} ;",
            "    LAYER met1 ;",
            f"      RECT 0 0 {number(WIDTH)} {number(HEIGHT)} ;",
            "  END",
            f"END {NAME}",
            "",
            "END LIBRARY",
            "",
        ]
    )
    (ROOT / "lef" / f"{NAME}.lef").write_text("\n".join(lines), newline="\n")


def write_liberty(ports):
    area = WIDTH * HEIGHT
    lines = [
        f"library ({NAME}) {{",
        "  delay_model : table_lookup;",
        '  time_unit : "1ns";',
        '  voltage_unit : "1V";',
        '  current_unit : "1mA";',
        '  capacitive_load_unit (1, pf);',
        '  leakage_power_unit : "1nW";',
        '  bus_naming_style : "%s[%d]";',
        f'  comment : "{PROVISIONAL}; no characterized timing arcs";',
        "  nom_process : 1.0;",
        "  nom_temperature : 25.0;",
        "  nom_voltage : 1.8;",
        f"  cell ({NAME}) {{",
        f"    area : {area:.4f};",
        "    dont_use : true;",
    ]
    for name, direction in ports:
        lines.extend([f"    pin ({name}) {{", f"      direction : {direction};"])
        if name in POWER_PINS:
            signal_type = "GROUND" if name == "VSS" else "POWER"
            lines.append(f"      signal_type : {signal_type};")
        elif direction == "input":
            lines.extend(["      capacitance : 0.01;", "      max_transition : 0.50;"])
        elif direction == "output":
            lines.append("      max_capacitance : 0.10;")
        lines.append("    }")
        if name in POWER_PINS:
            pg_type = "primary_ground" if name == "VSS" else "primary_power"
            lines.extend([f"    pg_pin ({name}) {{", f"      pg_type : {pg_type};", "    }"])
    lines.extend(["  }", "}", ""])
    (ROOT / "lib" / f"{NAME}.lib").write_text("\n".join(lines), newline="\n")


def record(record_type, data_type=0, payload=b""):
    if len(payload) % 2:
        payload += b"\0"
    return struct.pack(">HBB", len(payload) + 4, record_type, data_type) + payload


def int2(*values):
    return struct.pack(">" + "h" * len(values), *values)


def int4(*values):
    return struct.pack(">" + "i" * len(values), *values)


def boundary(layer, datatype, rect):
    x1, y1, x2, y2 = (round(value * 1000) for value in rect)
    xy = (x1, y1, x2, y1, x2, y2, x1, y2, x1, y1)
    return b"".join(
        [
            record(0x08),
            record(0x0D, 0x02, int2(layer)),
            record(0x0E, 0x02, int2(datatype)),
            record(0x10, 0x03, int4(*xy)),
            record(0x11),
        ]
    )


def text_label(layer, texttype, name, rect):
    x1, y1, x2, y2 = rect
    x = round(((x1 + x2) / 2) * 1000)
    y = round(((y1 + y2) / 2) * 1000)
    return b"".join(
        [
            record(0x0C),
            record(0x0D, 0x02, int2(layer)),
            record(0x16, 0x02, int2(texttype)),
            record(0x10, 0x03, int4(x, y)),
            record(0x19, 0x06, name.encode("ascii")),
            record(0x11),
        ]
    )


def write_gds(ports, geometry):
    # Fixed metadata keeps the generated binary reproducible across machines.
    now = datetime(2026, 10, 30, 0, 0, 0)
    date_values = (now.year, now.month, now.day, now.hour, now.minute, now.second) * 2
    # GDSII real8 encodings for 1e-3 user units per database unit and 1e-9 m/DBU.
    units = bytes.fromhex("3e4189374bc6a7f03944b82fa09b5a54")
    chunks = [
        record(0x00, 0x02, int2(600)),
        record(0x01, 0x02, int2(*date_values)),
        record(0x02, 0x06, b"PROVISIONAL_RAW_INTERFACE"),
        record(0x03, 0x05, units),
        record(0x05, 0x02, int2(*date_values)),
        record(0x06, 0x06, NAME.encode("ascii")),
        boundary(235, 4, (0.0, 0.0, WIDTH, HEIGHT)),
    ]
    for name, _direction in ports:
        rect = geometry[name]["rect"]
        chunks.append(boundary(69, 20, rect))
        chunks.append(text_label(69, 5, name, rect))
    chunks.extend([record(0x07), record(0x04)])
    (ROOT / "gds" / f"{NAME}.gds").write_bytes(b"".join(chunks))


def main():
    ports = module_ports()
    names = [name for name, _direction in ports]
    if len(names) != 172 or len(set(names)) != 172:
        raise RuntimeError(f"expected 172 unique expanded pins, found {len(set(names))}")
    if not POWER_PINS.issubset(names):
        raise RuntimeError("the expected reference-derived power pins are missing")
    geometry = pin_geometry(ports)
    write_lef(ports, geometry)
    write_liberty(ports)
    write_gds(ports, geometry)
    print(f"Generated provisional GDS/LEF/Liberty for {NAME} with {len(ports)} pins")


if __name__ == "__main__":
    main()
