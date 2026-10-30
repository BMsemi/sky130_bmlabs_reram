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
SOURCE = ROOT / "verilog" / "vh" / f"{NAME}.vh"
WIDTH = 1910.0
HEIGHT = 2010.14
POWER_PINS = {"VDDC1", "VDDC2", "VDDA1", "VDDA2", "VSS"}
ANALOG_PINS = {
    "Iref",
    "Vcc_read",
    "Vcomp",
    "Bias_comp2",
    "Vcc_wl_read",
    "Vcc_wl_set",
    "Vbias",
    "Vcc_wl_reset",
    "Vcc_set",
    "dc_bias",
}
PROVISIONAL = "PROVISIONAL - NOT FOR LVS, TIMING SIGNOFF, FABRICATION OR TAPEOUT"

# SKY130/OpenLane routing tracks. North/south pins use vertical met2, so their
# X centers follow the met2 X grid. West/east pins use horizontal met3, so
# their Y centers follow the met3 Y grid.
MET2_TRACK_ORIGIN = 0.23
MET2_TRACK_PITCH = 0.46
MET3_TRACK_ORIGIN = 0.34
MET3_TRACK_PITCH = 0.68
MET2_GDS_LAYER = 69
MET3_GDS_LAYER = 70
PIN_GDS_DATATYPE = 20
LABEL_GDS_TEXTTYPE = 5
SIGNAL_PIN_WIDTH = 0.30
ANALOG_PIN_WIDTH = 1.30
POWER_STRAP_WIDTH = 1.80
PIN_DEPTH = 2.91
ANALOG_PIN_DEPTH = 20.0
MET3_PIN_CLEARANCE = 0.30


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
    """Place pins deterministically on direction-correct routing tracks."""
    geometry = {}
    port_directions = dict(ports)

    def snap_to_track(position, origin, pitch):
        track = round((position - origin) / pitch)
        return round(origin + track * pitch, 3)

    # Use the same kind of wide met3 power access provided by the released
    # Wishbone macros. Each rail remains electrically separate.
    power_track_indices = {
        "VSS": 29,
        "VDDC1": 176,
        "VDDC2": 323,
        "VDDA1": 470,
        "VDDA2": 617,
    }
    occupied_met3 = {"left": [], "right": []}
    for name, track in power_track_indices.items():
        center = MET3_TRACK_ORIGIN + track * MET3_TRACK_PITCH
        rect = (0.0, center - POWER_STRAP_WIDTH / 2, WIDTH, center + POWER_STRAP_WIDTH / 2)
        geometry[name] = {
            "direction": port_directions[name],
            "layer": "met3",
            "gds_layer": MET3_GDS_LAYER,
            "rect": rect,
            "kind": "power_strap",
        }
        interval = (rect[1], rect[3])
        occupied_met3["left"].append(interval)
        occupied_met3["right"].append(interval)

    # All externally driven analog biases use wide, on-grid met3 access. The
    # 1.30 um width matches the widest analog access used by the released
    # Wishbone reference and is intended to meet a matching-or-wider NDR.
    analog_ports = [(name, direction) for name, direction in ports if name in ANALOG_PINS]
    for index, (name, direction) in enumerate(analog_ports):
        side = "left" if index % 2 == 0 else "right"
        track = 2100 + index * 60
        center = MET3_TRACK_ORIGIN + track * MET3_TRACK_PITCH
        if side == "left":
            rect = (
                0.0,
                center - ANALOG_PIN_WIDTH / 2,
                ANALOG_PIN_DEPTH,
                center + ANALOG_PIN_WIDTH / 2,
            )
        else:
            rect = (
                WIDTH - ANALOG_PIN_DEPTH,
                center - ANALOG_PIN_WIDTH / 2,
                WIDTH,
                center + ANALOG_PIN_WIDTH / 2,
            )
        geometry[name] = {
            "direction": direction,
            "layer": "met3",
            "gds_layer": MET3_GDS_LAYER,
            "rect": rect,
            "kind": "analog",
        }
        occupied_met3[side].append((rect[1], rect[3]))

    digital_ports = [
        port for port in ports if port[0] not in POWER_PINS and port[0] not in ANALOG_PINS
    ]
    side_groups = [[], [], [], []]
    for index, port in enumerate(digital_ports):
        side_groups[index % 4].append(port)

    margin = 20.0

    def available_met3_center(ideal_position, side):
        base_track = round((ideal_position - MET3_TRACK_ORIGIN) / MET3_TRACK_PITCH)
        offsets = [0]
        for offset in range(1, 100):
            offsets.extend((offset, -offset))
        for offset in offsets:
            center = round(MET3_TRACK_ORIGIN + (base_track + offset) * MET3_TRACK_PITCH, 3)
            low = center - SIGNAL_PIN_WIDTH / 2
            high = center + SIGNAL_PIN_WIDTH / 2
            if low < margin or high > HEIGHT - margin:
                continue
            if all(
                high + MET3_PIN_CLEARANCE <= used_low
                or low - MET3_PIN_CLEARANCE >= used_high
                for used_low, used_high in occupied_met3[side]
            ):
                occupied_met3[side].append((low, high))
                return center
        raise RuntimeError(f"could not place a met3 pin near Y={ideal_position}")

    for side, group in enumerate(side_groups):
        span = (WIDTH if side in {0, 2} else HEIGHT) - 2 * margin
        pitch = span / (len(group) + 1)
        for index, (name, direction) in enumerate(group, 1):
            ideal_position = margin + index * pitch
            if side == 0:  # bottom
                layer = "met2"
                gds_layer = MET2_GDS_LAYER
                position = snap_to_track(
                    ideal_position, MET2_TRACK_ORIGIN, MET2_TRACK_PITCH
                )
                rect = (
                    position - SIGNAL_PIN_WIDTH / 2,
                    0.0,
                    position + SIGNAL_PIN_WIDTH / 2,
                    PIN_DEPTH,
                )
            elif side == 1:  # right
                layer = "met3"
                gds_layer = MET3_GDS_LAYER
                position = available_met3_center(ideal_position, "right")
                rect = (
                    WIDTH - PIN_DEPTH,
                    position - SIGNAL_PIN_WIDTH / 2,
                    WIDTH,
                    position + SIGNAL_PIN_WIDTH / 2,
                )
            elif side == 2:  # top
                layer = "met2"
                gds_layer = MET2_GDS_LAYER
                position = snap_to_track(
                    ideal_position, MET2_TRACK_ORIGIN, MET2_TRACK_PITCH
                )
                rect = (
                    position - SIGNAL_PIN_WIDTH / 2,
                    HEIGHT - PIN_DEPTH,
                    position + SIGNAL_PIN_WIDTH / 2,
                    HEIGHT,
                )
            else:  # left
                layer = "met3"
                gds_layer = MET3_GDS_LAYER
                position = available_met3_center(ideal_position, "left")
                rect = (
                    0.0,
                    position - SIGNAL_PIN_WIDTH / 2,
                    PIN_DEPTH,
                    position + SIGNAL_PIN_WIDTH / 2,
                )
            geometry[name] = {
                "direction": direction,
                "layer": layer,
                "gds_layer": gds_layer,
                "rect": rect,
                "kind": "signal",
            }
    return geometry


def number(value):
    return f"{value:.3f}".rstrip("0").rstrip(".")


def write_lef(ports, geometry):
    lines = [
        f"# {PROVISIONAL}",
        "# Synthetic pin placement derived from the Verilog header.",
        "# North/south pins: met2 X grid 0.23 + N*0.46 um.",
        "# West/east pins: met3 Y grid 0.34 + N*0.68 um.",
        "# Analog pins: 1.30 um wide met3 access for matching-or-wider NDR.",
        "# Supply pins: separate 1.80 um full-width met3 straps.",
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
        layer = geometry[name]["layer"]
        use = "GROUND" if name == "VSS" else "POWER" if name in POWER_PINS else "SIGNAL"
        lines.extend(
            [
                f"  PIN {name}",
                f"    DIRECTION {direction.upper()} ;",
                f"    USE {use} ;",
                "    PORT",
                f"      LAYER {layer} ;",
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
        layer = geometry[name]["gds_layer"]
        chunks.append(boundary(layer, PIN_GDS_DATATYPE, rect))
        chunks.append(text_label(layer, LABEL_GDS_TEXTTYPE, name, rect))
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
