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
REFERENCE_GDS = ROOT / "gds" / "sky130_bmlabs_reram__nvm32x32wb.gds"
REFERENCE_LEF = ROOT / "lef" / "sky130_bmlabs_reram__nvm32x32wb.lef"
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
PIN_DEPTH = 2.91
ANALOG_PIN_DEPTH = 20.0
MET3_PIN_CLEARANCE = 0.30
GDS_LAYER_BY_LEF_LAYER = {"met2": MET2_GDS_LAYER, "met3": MET3_GDS_LAYER}
EXPECTED_POWER_SHAPE_COUNTS = {
    "VDDC1": 27,
    "VDDC2": 78,
    "VDDA1": 74,
    "VDDA2": 3,
    "VSS": 133,
}


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


def reference_pin_shapes(pin_names):
    """Read labeled met3 power geometry from the released X1 Wishbone GDS."""
    data = REFERENCE_GDS.read_bytes()
    offset = 0
    active = None
    shapes = []
    labels = []
    while offset < len(data):
        length = int.from_bytes(data[offset : offset + 2], "big")
        if length < 4 or offset + length > len(data):
            raise RuntimeError(f"invalid reference GDS record at byte {offset}")
        record_type = data[offset + 2]
        payload = data[offset + 4 : offset + length]
        if record_type in {8, 12}:  # BOUNDARY or TEXT
            active = {
                "type": record_type,
                "layer": None,
                "datatype": None,
                "coordinates": [],
                "text": None,
            }
        elif active is not None and record_type == 13:  # LAYER
            active["layer"] = int.from_bytes(payload, "big", signed=True)
        elif active is not None and record_type in {14, 22}:  # DATATYPE/TEXTTYPE
            active["datatype"] = int.from_bytes(payload, "big", signed=True)
        elif active is not None and record_type == 16:  # XY
            values = [
                int.from_bytes(payload[index : index + 4], "big", signed=True)
                for index in range(0, len(payload), 4)
            ]
            active["coordinates"] = list(zip(values[0::2], values[1::2]))
        elif active is not None and record_type == 25:  # STRING
            active["text"] = payload.rstrip(b"\0").decode("ascii", errors="replace")
        elif active is not None and record_type == 17:  # ENDEL
            if (
                active["type"] == 8
                and active["layer"] == MET3_GDS_LAYER
                and active["datatype"] == PIN_GDS_DATATYPE
            ):
                xs = [point[0] for point in active["coordinates"]]
                ys = [point[1] for point in active["coordinates"]]
                shapes.append((min(xs), min(ys), max(xs), max(ys)))
            elif (
                active["type"] == 12
                and active["layer"] == MET3_GDS_LAYER
                and active["datatype"] == LABEL_GDS_TEXTTYPE
                and active["text"] in pin_names
            ):
                labels.append((active["text"], active["coordinates"][0]))
            active = None
        offset += length

    result = {name: [] for name in pin_names}
    for name, (x, y) in labels:
        containing = [
            rect
            for rect in shapes
            if rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]
        ]
        if len(containing) != 1:
            raise RuntimeError(
                f"reference GDS label {name} at {(x, y)} maps to "
                f"{len(containing)} pin shapes"
            )
        rect_um = tuple(value / 1000 for value in containing[0])
        result[name].append(("met3", rect_um))

    for name, pin_shapes in result.items():
        expected = EXPECTED_POWER_SHAPE_COUNTS[name]
        if len(pin_shapes) != expected:
            raise RuntimeError(
                f"reference GDS pin {name} expected {expected} shapes, "
                f"found {len(pin_shapes)}"
            )
    return result


def reference_obstructions():
    """Read routing obstructions from the matching released X1 Wishbone LEF."""
    text = REFERENCE_LEF.read_text(errors="replace")
    match = re.search(r"^\s*OBS\s*$\n(.*?)^\s*END\s*$", text, re.M | re.S)
    if not match:
        raise RuntimeError("reference LEF does not contain an OBS section")
    layer = None
    shapes = []
    for line in match.group(1).splitlines():
        layer_match = re.match(r"^\s*LAYER\s+(\S+)\s*;", line)
        if layer_match:
            layer = layer_match.group(1)
            continue
        rect_match = re.match(
            r"^\s*RECT\s+([0-9.+-]+)\s+([0-9.+-]+)\s+"
            r"([0-9.+-]+)\s+([0-9.+-]+)\s*;",
            line,
        )
        if rect_match and layer:
            shapes.append(
                (layer, tuple(float(value) for value in rect_match.groups()))
            )
    expected_layers = ["li1", "met1", "met2", "met3", "met4"]
    if [layer for layer, _rect in shapes] != expected_layers:
        raise RuntimeError("reference LEF obstruction pattern changed")
    return shapes


def pin_geometry(ports, power_shapes):
    """Place pins deterministically on direction-correct routing tracks."""
    geometry = {}
    port_directions = dict(ports)

    def snap_to_track(position, origin, pitch):
        track = round((position - origin) / pitch)
        return round(origin + track * pitch, 3)

    # Reuse the distributed power-access geometry from the released X1
    # Wishbone GDS instead of inventing a synthetic one-strap network.
    occupied_met3 = {"left": [], "right": []}
    for name in POWER_PINS:
        shapes = []
        for layer, rect in power_shapes[name]:
            shapes.append(
                {
                    "layer": layer,
                    "gds_layer": GDS_LAYER_BY_LEF_LAYER[layer],
                    "rect": rect,
                }
            )
            x1, y1, x2, y2 = rect
            if x1 < ANALOG_PIN_DEPTH:
                occupied_met3["left"].append((y1, y2))
            if x2 > WIDTH - ANALOG_PIN_DEPTH:
                occupied_met3["right"].append((y1, y2))
        geometry[name] = {
            "direction": port_directions[name],
            "shapes": shapes,
            "kind": "power",
        }

    margin = 20.0

    def available_met3_center(ideal_position, side, pin_width):
        base_track = round((ideal_position - MET3_TRACK_ORIGIN) / MET3_TRACK_PITCH)
        offsets = [0]
        for offset in range(1, 300):
            offsets.extend((offset, -offset))
        for offset in offsets:
            center = round(MET3_TRACK_ORIGIN + (base_track + offset) * MET3_TRACK_PITCH, 3)
            low = center - pin_width / 2
            high = center + pin_width / 2
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

    # All externally driven analog biases use wide, on-grid met3 access. The
    # 1.30 um width matches the widest analog access used by the released
    # Wishbone reference and is intended to meet a matching-or-wider NDR.
    analog_ports = [(name, direction) for name, direction in ports if name in ANALOG_PINS]
    for index, (name, direction) in enumerate(analog_ports):
        side = "left" if index % 2 == 0 else "right"
        track = 2100 + index * 60
        ideal_center = MET3_TRACK_ORIGIN + track * MET3_TRACK_PITCH
        center = available_met3_center(ideal_center, side, ANALOG_PIN_WIDTH)
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
            "shapes": [
                {"layer": "met3", "gds_layer": MET3_GDS_LAYER, "rect": rect}
            ],
            "kind": "analog",
        }

    digital_ports = [
        port for port in ports if port[0] not in POWER_PINS and port[0] not in ANALOG_PINS
    ]
    side_groups = [[], [], [], []]
    for index, port in enumerate(digital_ports):
        side_groups[index % 4].append(port)

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
                position = available_met3_center(
                    ideal_position, "right", SIGNAL_PIN_WIDTH
                )
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
                position = available_met3_center(
                    ideal_position, "left", SIGNAL_PIN_WIDTH
                )
                rect = (
                    0.0,
                    position - SIGNAL_PIN_WIDTH / 2,
                    PIN_DEPTH,
                    position + SIGNAL_PIN_WIDTH / 2,
                )
            geometry[name] = {
                "direction": direction,
                "shapes": [{"layer": layer, "gds_layer": gds_layer, "rect": rect}],
                "kind": "signal",
            }
    return geometry


def number(value):
    return f"{value:.3f}".rstrip("0").rstrip(".")


def write_lef(ports, geometry, obstructions):
    lines = [
        f"# {PROVISIONAL}",
        "# Synthetic pin placement derived from the Verilog header.",
        "# North/south pins: met2 X grid 0.23 + N*0.46 um.",
        "# West/east pins: met3 Y grid 0.34 + N*0.68 um.",
        "# Analog pins: 1.30 um wide met3 access for matching-or-wider NDR.",
        "# Supply pins: distributed met3 access copied from the released X1 GDS.",
        "# OBS geometry: copied from the matching released X1 LEF.",
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
        use = "GROUND" if name == "VSS" else "POWER" if name in POWER_PINS else "SIGNAL"
        lines.extend(
            [
                f"  PIN {name}",
                f"    DIRECTION {direction.upper()} ;",
                f"    USE {use} ;",
            ]
        )
        for shape in geometry[name]["shapes"]:
            x1, y1, x2, y2 = shape["rect"]
            lines.extend(
                [
                    "    PORT",
                    f"      LAYER {shape['layer']} ;",
                    f"        RECT {number(x1)} {number(y1)} {number(x2)} {number(y2)} ;",
                    "    END",
                ]
            )
        lines.append(f"  END {name}")
    lines.append("  OBS")
    for layer, rect in obstructions:
        x1, y1, x2, y2 = rect
        lines.extend(
            [
                f"    LAYER {layer} ;",
                f"      RECT {number(x1)} {number(y1)} {number(x2)} {number(y2)} ;",
            ]
        )
    lines.extend(["  END", f"END {NAME}", "", "END LIBRARY", ""])
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
        shapes = geometry[name]["shapes"]
        for shape in shapes:
            chunks.append(
                boundary(shape["gds_layer"], PIN_GDS_DATATYPE, shape["rect"])
            )
        label_shape = shapes[0]
        chunks.append(
            text_label(
                label_shape["gds_layer"],
                LABEL_GDS_TEXTTYPE,
                name,
                label_shape["rect"],
            )
        )
    chunks.extend([record(0x07), record(0x04)])
    (ROOT / "gds" / f"{NAME}.gds").write_bytes(b"".join(chunks))


def main():
    ports = module_ports()
    names = [name for name, _direction in ports]
    if len(names) != 172 or len(set(names)) != 172:
        raise RuntimeError(f"expected 172 unique expanded pins, found {len(set(names))}")
    if not POWER_PINS.issubset(names):
        raise RuntimeError("the expected reference-derived power pins are missing")
    power_shapes = reference_pin_shapes(POWER_PINS)
    obstructions = reference_obstructions()
    geometry = pin_geometry(ports, power_shapes)
    write_lef(ports, geometry, obstructions)
    write_liberty(ports)
    write_gds(ports, geometry)
    power_shape_count = sum(len(shapes) for shapes in power_shapes.values())
    print(
        f"Generated provisional GDS/LEF/Liberty for {NAME} with "
        f"{len(ports)} pins and {power_shape_count} distributed power shapes"
    )


if __name__ == "__main__":
    main()
