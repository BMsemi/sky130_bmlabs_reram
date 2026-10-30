#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CIM_NAME = "sky130_bmlabs_reram__cim32x32wb"
NVM_NAME = "sky130_bmlabs_reram__nvm32x32wb"
RAW_NAME = "sky130_bmlabs_reram__cim32x32"
RELEASED_NAMES = {CIM_NAME, NVM_NAME}
LEGACY_NAME_PATTERNS = {
    "Neuromorphic_X1_wb": r"Neuromorphic_X1_wb",
    "Neuromorphic_X1_beh": r"Neuromorphic_X1_beh",
    "sky130_bmlabs_reram__nvm32x32": (
        r"sky130_bmlabs_reram__nvm32x32(?!wb)"
    ),
}
WIDTH = 1910.0
HEIGHT = 2010.14
PIN_COUNT = 128
RAW_PORT_COUNT = 49
RAW_WIRE_COUNT = 172
RAW_FUNCTIONAL_PORT_COUNT = 44
RAW_FUNCTIONAL_WIRE_COUNT = 167
RAW_SCAN_PORT_COUNT = 5
RAW_ANALOG_PORT_COUNT = 10
RAW_POWER_PINS = {"VDDC1", "VDDC2", "VDDA1", "VDDA2", "VSS"}
RAW_SCAN_PINS = {"ScanInCC", "ScanInDL", "ScanInDR", "TM", "ScanOutCC"}
RAW_ANALOG_PINS = {
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
RAW_STATUS = "provisional-integration-only-awaiting-signoff-views"
MET2_GDS_LAYER = 69
MET3_GDS_LAYER = 70
PIN_GDS_DATATYPE = 20
LABEL_GDS_TEXTTYPE = 5
MET2_TRACK_ORIGIN = 0.23
MET2_TRACK_PITCH = 0.46
MET3_TRACK_ORIGIN = 0.34
MET3_TRACK_PITCH = 0.68
RAW_ANALOG_PIN_WIDTH = 1.30
RAW_POWER_SHAPE_COUNTS = {
    "VDDC1": 27,
    "VDDC2": 78,
    "VDDA1": 74,
    "VDDA2": 3,
    "VSS": 133,
}
EXPECTED_OBSTRUCTION_LAYERS = ["li1", "met1", "met2", "met3", "met4"]

EXPECTED_POWER_CONNECTIONS = {
    "VDDC1": "vccd1",
    "VDDC2": "vccd2",
    "VDDA1": "vdda1",
    "VDDA2": "vdda2",
    "VSS": "vssd1",
}
EXPECTED_POWER_VOLTAGE = {
    "VDDC1": 1.8,
    "VDDC2": 1.8,
    "VDDA1": 3.3,
    "VDDA2": 3.3,
    "VSS": 0,
}
EXPECTED_RAW_ROUTING_CONSTRAINTS = {
    "analog_pad_connection_required": True,
    "analog_layer": "met3",
    "analog_min_width_um": RAW_ANALOG_PIN_WIDTH,
    "power_geometry_reference": NVM_NAME,
    "power_geometry_source_view": "gds",
    "power_access_layer": "met3",
    "power_access_shape_counts": RAW_POWER_SHAPE_COUNTS,
    "obstruction_reference": NVM_NAME,
    "obstruction_source_view": "lef",
    "obstruction_layers": EXPECTED_OBSTRUCTION_LAYERS,
}


def expected_views(name):
    return {
        "gds": f"gds/{name}.gds",
        "lef": f"lef/{name}.lef",
        "liberty": f"lib/{name}.lib",
        "verilog_header": f"verilog/vh/{name}.vh",
        "verilog_behavioral": f"verilog/behavioral/{name}.sv",
        "testbench": f"verilog/behavioral/{name}_tb.sv",
    }


def expand_bus(name, bus):
    if not bus:
        return {name}
    numbers = [int(value) for value in re.findall(r"\d+", bus)]
    if len(numbers) != 2:
        return {name}
    low, high = sorted(numbers)
    return {f"{name}[{index}]" for index in range(low, high + 1)}


def verilog_port_declarations(path, module_name):
    text = path.read_text(errors="replace")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    match = re.search(
        rf"\bmodule\s+{re.escape(module_name)}\s*"
        rf"(?:#\s*\(.*?\)\s*)?\((.*?)\)\s*;",
        text,
        re.S,
    )
    if not match:
        return None

    declaration = re.compile(
        r"\b(?:input|output|inout)\b"
        r"(?:\s+(?:wire|reg|logic|signed))*"
        r"\s*(\[[^]]+\])?\s*([A-Za-z_]\w*)"
    )
    return list(declaration.finditer(match.group(1)))


def verilog_ports(path, module_name):
    declarations = verilog_port_declarations(path, module_name)
    if declarations is None:
        return None

    ports = set()
    for port in declarations:
        bus, name = port.groups()
        ports.update(expand_bus(name, bus))
    return ports


def verilog_port_directions(path, module_name):
    text = path.read_text(errors="replace")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    match = re.search(
        rf"\bmodule\s+{re.escape(module_name)}\s*"
        rf"(?:#\s*\(.*?\)\s*)?\((.*?)\)\s*;",
        text,
        re.S,
    )
    if not match:
        return None
    declaration = re.compile(
        r"\b(input|output|inout)\b"
        r"(?:\s+(?:wire|reg|logic|signed))*"
        r"\s*(\[[^]]+\])?\s*([A-Za-z_]\w*)"
    )
    directions = {}
    for direction, bus, name in declaration.findall(match.group(1)):
        for expanded_name in expand_bus(name, bus):
            directions[expanded_name] = direction
    return directions


def lef_pins(text):
    return set(re.findall(r"^\s*PIN\s+(\S+)", text, re.M))


def liberty_pins(text):
    return set(re.findall(r"^\s*pin\s*\(\s*([^\s)]+)", text, re.M))


def liberty_pin_directions(text):
    directions = {}
    for match in re.finditer(
        r"^\s*pin\s*\(\s*([^\s)]+)\s*\)\s*\{(.*?)^\s*\}",
        text,
        re.M | re.S,
    ):
        direction = re.search(r"\bdirection\s*:\s*(input|output|inout)\s*;", match.group(2))
        if direction:
            directions[match.group(1)] = direction.group(1)
    return directions


def lef_pin_details(text):
    details = {}
    current = None
    current_layer = None
    for line in text.splitlines():
        pin = re.match(r"^\s*PIN\s+(\S+)\s*$", line)
        if pin:
            current = pin.group(1)
            details[current] = {"direction": None, "shapes": []}
            current_layer = None
            continue
        if current is None:
            continue
        direction = re.match(r"^\s*DIRECTION\s+(\S+)\s*;", line)
        if direction:
            details[current]["direction"] = direction.group(1).lower()
            continue
        layer = re.match(r"^\s*LAYER\s+(\S+)\s*;", line)
        if layer:
            current_layer = layer.group(1)
            continue
        rect = re.match(
            r"^\s*RECT\s+([0-9.+-]+)\s+([0-9.+-]+)\s+"
            r"([0-9.+-]+)\s+([0-9.+-]+)\s*;",
            line,
        )
        if rect and current_layer:
            details[current]["shapes"].append(
                (current_layer, tuple(float(value) for value in rect.groups()))
            )
            continue
        if re.match(rf"^\s*END\s+{re.escape(current)}\s*$", line):
            current = None
            current_layer = None
    return details


def lef_obstructions(text):
    match = re.search(r"^\s*OBS\s*$\n(.*?)^\s*END\s*$", text, re.M | re.S)
    if not match:
        return []
    obstructions = []
    current_layer = None
    for line in match.group(1).splitlines():
        layer = re.match(r"^\s*LAYER\s+(\S+)\s*;", line)
        if layer:
            current_layer = layer.group(1)
            continue
        rect = re.match(
            r"^\s*RECT\s+([0-9.+-]+)\s+([0-9.+-]+)\s+"
            r"([0-9.+-]+)\s+([0-9.+-]+)\s*;",
            line,
        )
        if rect and current_layer:
            obstructions.append(
                (current_layer, tuple(float(value) for value in rect.groups()))
            )
    return obstructions


def is_on_track(position, origin, pitch, tolerance=1e-6):
    track = round((position - origin) / pitch)
    return abs(position - (origin + track * pitch)) <= tolerance


def validate_perimeter_shapes(errors, view_name, layer, rectangles, scale=1.0):
    width = WIDTH * scale
    height = HEIGHT * scale
    tolerance = 1e-6 if scale == 1.0 else 0
    if layer == "met2":
        origin = MET2_TRACK_ORIGIN * scale
        pitch = MET2_TRACK_PITCH * scale
        for rect in rectangles:
            x1, y1, x2, y2 = rect
            if not (abs(y1) <= tolerance or abs(y2 - height) <= tolerance):
                errors.append(f"{view_name} met2 pin does not touch north/south boundary: {rect}")
            if not is_on_track((x1 + x2) / 2, origin, pitch, tolerance):
                errors.append(f"{view_name} met2 pin center is off the X routing grid: {rect}")
    elif layer == "met3":
        origin = MET3_TRACK_ORIGIN * scale
        pitch = MET3_TRACK_PITCH * scale
        for rect in rectangles:
            x1, y1, x2, y2 = rect
            if not (abs(x1) <= tolerance or abs(x2 - width) <= tolerance):
                errors.append(f"{view_name} met3 pin does not touch west/east boundary: {rect}")
            if not is_on_track((y1 + y2) / 2, origin, pitch, tolerance):
                errors.append(f"{view_name} met3 pin center is off the Y routing grid: {rect}")


def read_gds(path):
    data = path.read_bytes()
    offset = 0
    structures = []
    labels = set()
    while offset < len(data):
        if offset + 4 > len(data):
            raise ValueError(f"truncated GDS record at byte {offset}")
        length = int.from_bytes(data[offset : offset + 2], "big")
        if length < 4 or offset + length > len(data):
            raise ValueError(f"invalid GDS record at byte {offset}")
        record_type = data[offset + 2]
        payload = data[offset + 4 : offset + length].rstrip(b"\0")
        if record_type in {6, 25}:
            value = payload.decode("ascii", errors="replace")
            if record_type == 6:
                structures.append(value)
            else:
                value = re.sub(r"<([0-9]+)>$", r"[\1]", value)
                labels.add(value)
        offset += length
    return structures, labels


def gds_rectangles(path, wanted_layer, wanted_datatype):
    data = path.read_bytes()
    offset = 0
    active = False
    layer = None
    datatype = None
    coordinates = []
    rectangles = set()
    while offset < len(data):
        length = int.from_bytes(data[offset : offset + 2], "big")
        record_type = data[offset + 2]
        payload = data[offset + 4 : offset + length]
        if record_type == 8:
            active = True
            layer = None
            datatype = None
            coordinates = []
        elif active and record_type == 13:
            layer = int.from_bytes(payload, "big", signed=True)
        elif active and record_type == 14:
            datatype = int.from_bytes(payload, "big", signed=True)
        elif active and record_type == 16:
            values = [
                int.from_bytes(payload[index : index + 4], "big", signed=True)
                for index in range(0, len(payload), 4)
            ]
            coordinates = list(zip(values[0::2], values[1::2]))
        elif active and record_type == 17:
            if layer == wanted_layer and datatype == wanted_datatype and coordinates:
                xs = [point[0] for point in coordinates]
                ys = [point[1] for point in coordinates]
                rectangles.add((min(xs), min(ys), max(xs), max(ys)))
            active = False
        offset += length
    return rectangles


def gds_labeled_rectangles(
    path, wanted_layer, wanted_datatype, wanted_texttype
):
    data = path.read_bytes()
    offset = 0
    active = None
    rectangles = []
    labels = []
    while offset < len(data):
        length = int.from_bytes(data[offset : offset + 2], "big")
        record_type = data[offset + 2]
        payload = data[offset + 4 : offset + length]
        if record_type in {8, 12}:
            active = {
                "type": record_type,
                "layer": None,
                "datatype": None,
                "coordinates": [],
                "text": None,
            }
        elif active is not None and record_type == 13:
            active["layer"] = int.from_bytes(payload, "big", signed=True)
        elif active is not None and record_type in {14, 22}:
            active["datatype"] = int.from_bytes(payload, "big", signed=True)
        elif active is not None and record_type == 16:
            values = [
                int.from_bytes(payload[index : index + 4], "big", signed=True)
                for index in range(0, len(payload), 4)
            ]
            active["coordinates"] = list(zip(values[0::2], values[1::2]))
        elif active is not None and record_type == 25:
            active["text"] = payload.rstrip(b"\0").decode("ascii", errors="replace")
        elif active is not None and record_type == 17:
            if (
                active["type"] == 8
                and active["layer"] == wanted_layer
                and active["datatype"] == wanted_datatype
            ):
                xs = [point[0] for point in active["coordinates"]]
                ys = [point[1] for point in active["coordinates"]]
                rectangles.append((min(xs), min(ys), max(xs), max(ys)))
            elif (
                active["type"] == 12
                and active["layer"] == wanted_layer
                and active["datatype"] == wanted_texttype
            ):
                labels.append((active["text"], active["coordinates"][0]))
            active = None
        offset += length

    result = {}
    for name, (x, y) in labels:
        containing = [
            rect
            for rect in rectangles
            if rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]
        ]
        if len(containing) != 1:
            raise ValueError(
                f"GDS label {name} at {(x, y)} maps to {len(containing)} shapes"
            )
        result.setdefault(name, []).append(containing[0])
    return result


def report_pin_difference(
    errors, name, view_name, reference, actual, allow_extra=False
):
    missing = sorted(reference - actual)
    extra = [] if allow_extra else sorted(actual - reference)
    if missing or extra:
        details = []
        if missing:
            details.append(f"missing {missing}")
        if extra:
            details.append(f"extra {extra}")
        errors.append(f"{name} {view_name} pin mismatch: " + "; ".join(details))


errors = []
for header_name in RELEASED_NAMES | {RAW_NAME}:
    legacy_header = ROOT / "verilog" / f"{header_name}.v"
    if legacy_header.exists():
        errors.append(
            f"legacy .v interface file must be moved to verilog/vh/: "
            f"{legacy_header.relative_to(ROOT)}"
        )
manifest_path = ROOT / "ip_manifest.json"
if not manifest_path.is_file():
    errors.append("missing required file: ip_manifest.json")
    manifest = {}
else:
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"invalid ip_manifest.json: {error}")
        manifest = {}

cells = manifest.get("cells", {})
if set(cells) != RELEASED_NAMES:
    errors.append(
        "released manifest cells must be exactly "
        f"{', '.join(sorted(RELEASED_NAMES))}"
    )

planned = {cell.get("name") for cell in manifest.get("planned_cells", [])}
if planned != {RAW_NAME}:
    errors.append(f"planned manifest cells must contain only {RAW_NAME}")

raw_entries = [
    cell for cell in manifest.get("planned_cells", []) if cell.get("name") == RAW_NAME
]
if len(raw_entries) == 1:
    raw_entry = raw_entries[0]
    expected_raw_views = {
        "verilog_header": f"verilog/vh/{RAW_NAME}.vh",
        "verilog_behavioral": f"verilog/behavioral/{RAW_NAME}.sv",
        "testbench": f"verilog/behavioral/{RAW_NAME}_tb.sv",
    }
    if raw_entry.get("status") != RAW_STATUS:
        errors.append(f"{RAW_NAME} status must be {RAW_STATUS}")
    if raw_entry.get("interface_ports") != RAW_PORT_COUNT:
        errors.append(f"{RAW_NAME} manifest interface port count must be {RAW_PORT_COUNT}")
    if raw_entry.get("interface_wires") != RAW_WIRE_COUNT:
        errors.append(f"{RAW_NAME} manifest interface wire count must be {RAW_WIRE_COUNT}")
    if raw_entry.get("functional_ports") != RAW_FUNCTIONAL_PORT_COUNT:
        errors.append(
            f"{RAW_NAME} manifest functional port count must be "
            f"{RAW_FUNCTIONAL_PORT_COUNT}"
        )
    if raw_entry.get("functional_wires") != RAW_FUNCTIONAL_WIRE_COUNT:
        errors.append(
            f"{RAW_NAME} manifest functional wire count must be "
            f"{RAW_FUNCTIONAL_WIRE_COUNT}"
        )
    if raw_entry.get("reference_scan_ports") != RAW_SCAN_PORT_COUNT:
        errors.append(f"{RAW_NAME} manifest must record five reference scan ports")
    if raw_entry.get("reference_analog_ports") != RAW_ANALOG_PORT_COUNT:
        errors.append(f"{RAW_NAME} manifest must record ten reference analog ports")
    if raw_entry.get("optional_power_ports") != len(RAW_POWER_PINS):
        errors.append(f"{RAW_NAME} manifest must record five optional power ports")
    if raw_entry.get("physical_routing_constraints") != EXPECTED_RAW_ROUTING_CONSTRAINTS:
        errors.append(f"{RAW_NAME} physical routing constraints are incorrect")
    if raw_entry.get("power_connections") != EXPECTED_POWER_CONNECTIONS:
        errors.append(f"{RAW_NAME} power connections do not match the reference")
    if raw_entry.get("power_voltage_v") != EXPECTED_POWER_VOLTAGE:
        errors.append(f"{RAW_NAME} power voltages do not match the reference")
    if raw_entry.get("simulation_views") != expected_raw_views:
        errors.append(f"{RAW_NAME} simulation view paths do not follow the release layout")

    expected_raw_physical = {
        "gds": f"gds/{RAW_NAME}.gds",
        "lef": f"lef/{RAW_NAME}.lef",
        "liberty": f"lib/{RAW_NAME}.lib",
    }
    if raw_entry.get("provisional_physical_views") != expected_raw_physical:
        errors.append(f"{RAW_NAME} provisional physical view paths are incorrect")

    raw_paths = {key: ROOT / relative for key, relative in expected_raw_views.items()}
    raw_missing = [path for path in raw_paths.values() if not path.is_file()]
    for path in raw_missing:
        errors.append(f"missing required file: {path.relative_to(ROOT)}")

    if not raw_missing:
        raw_header_text = raw_paths["verilog_header"].read_text(errors="replace")
        raw_header_ports = verilog_ports(raw_paths["verilog_header"], RAW_NAME)
        raw_behavioral_ports = verilog_ports(raw_paths["verilog_behavioral"], RAW_NAME)
        raw_header_directions = verilog_port_directions(
            raw_paths["verilog_header"], RAW_NAME
        )
        raw_behavioral_directions = verilog_port_directions(
            raw_paths["verilog_behavioral"], RAW_NAME
        )
        raw_header_declarations = verilog_port_declarations(
            raw_paths["verilog_header"], RAW_NAME
        )
        raw_behavioral_declarations = verilog_port_declarations(
            raw_paths["verilog_behavioral"], RAW_NAME
        )

        if raw_header_ports is None:
            errors.append(f"{RAW_NAME} Verilog header module name mismatch")
        if raw_behavioral_ports is None:
            errors.append(f"{RAW_NAME} behavioral module name mismatch")
        if raw_header_ports is not None and raw_behavioral_ports is not None:
            report_pin_difference(
                errors,
                RAW_NAME,
                "behavioral Verilog",
                raw_header_ports,
                raw_behavioral_ports,
            )
            if len(raw_header_ports) != RAW_WIRE_COUNT:
                errors.append(
                    f"{RAW_NAME} expected {RAW_WIRE_COUNT} signal wires, "
                    f"found {len(raw_header_ports)}"
                )
            if not RAW_SCAN_PINS.issubset(raw_header_ports):
                errors.append(f"{RAW_NAME} is missing reference scan/test pins")
            if not RAW_ANALOG_PINS.issubset(raw_header_ports):
                errors.append(f"{RAW_NAME} is missing reference analog pins")
            legacy_raw_scan = {"i_scan_si1", "i_scan_se1", "i_TM", "o_TM"}
            if legacy_raw_scan & raw_header_ports:
                errors.append(f"{RAW_NAME} still exposes legacy raw scan names")
        if (
            raw_header_directions is not None
            and raw_behavioral_directions is not None
            and raw_header_directions != raw_behavioral_directions
        ):
            errors.append(f"{RAW_NAME} header and behavioral port directions differ")
        for pin in sorted(RAW_ANALOG_PINS):
            if raw_header_directions and raw_header_directions.get(pin) != "inout":
                errors.append(f"{RAW_NAME} header analog pin {pin} must be inout")
            if raw_behavioral_directions and raw_behavioral_directions.get(pin) != "inout":
                errors.append(f"{RAW_NAME} behavioral analog pin {pin} must be inout")
        if re.search(rf"\bmodule\s+{re.escape(RAW_NAME)}\s*#", raw_header_text):
            errors.append(f"{RAW_NAME} Verilog header must not declare parameters")
        obsolete_missing_view_comment = (
            "This file does not imply that matching "
            + "GDS, LEF or Liberty views exist"
        )
        if obsolete_missing_view_comment in raw_header_text:
            errors.append(f"{RAW_NAME} Verilog header contains the obsolete missing-view comment")
        power_index = raw_header_text.find("`ifdef USE_POWER_PINS")
        clock_index = raw_header_text.find("clk_i")
        if power_index < 0 or clock_index < 0 or power_index > clock_index:
            errors.append(f"{RAW_NAME} power-pin section must be first in the header port list")
        scan_order = [
            raw_header_text.find(pin)
            for pin in ("ScanInCC", "ScanInDL", "ScanInDR", "ScanOutCC", "TM")
        ]
        if any(index < 0 for index in scan_order) or scan_order != sorted(scan_order):
            errors.append(f"{RAW_NAME} scan/test pin order is not synchronized")
        for view_name, declarations in {
            "Verilog header": raw_header_declarations,
            "behavioral model": raw_behavioral_declarations,
        }.items():
            if declarations is not None and len(declarations) != RAW_PORT_COUNT:
                errors.append(
                    f"{RAW_NAME} {view_name} expected {RAW_PORT_COUNT} declared "
                    f"ports, found {len(declarations)}"
                )

        raw_testbench = raw_paths["testbench"].read_text(errors="replace")
        if not re.search(rf"\bmodule\s+{re.escape(RAW_NAME)}_tb\b", raw_testbench):
            errors.append(f"{RAW_NAME} testbench module name mismatch")

        for path in raw_paths.values():
            text = path.read_text(errors="replace")
            forbidden_pattern = (
                r"\b"
                + "FP"
                + r"GA\b|Neuromorphic_"
                + "X2|compact"
                + "-interface"
            )
            if re.search(forbidden_pattern, text, re.I):
                errors.append(
                    f"project-specific or legacy naming remains in "
                    f"{path.relative_to(ROOT)}"
                )

        provisional_paths = {
            key: ROOT / relative for key, relative in expected_raw_physical.items()
        }
        provisional_missing = [
            path for path in provisional_paths.values() if not path.is_file()
        ]
        for path in provisional_missing:
            errors.append(f"missing required provisional file: {path.relative_to(ROOT)}")

        if not provisional_missing and raw_header_ports is not None:
            raw_lef_text = provisional_paths["lef"].read_text(errors="replace")
            raw_liberty_text = provisional_paths["liberty"].read_text(errors="replace")
            raw_lef_details = lef_pin_details(raw_lef_text)
            raw_liberty_directions = liberty_pin_directions(raw_liberty_text)
            if "PROVISIONAL" not in raw_lef_text:
                errors.append(f"{RAW_NAME} LEF lacks its provisional warning")
            if "PROVISIONAL" not in raw_liberty_text:
                errors.append(f"{RAW_NAME} Liberty lacks its provisional warning")
            if not re.search(r"\bdont_use\s*:\s*true\s*;", raw_liberty_text):
                errors.append(f"{RAW_NAME} provisional Liberty must set dont_use")
            if not re.search(rf"^MACRO\s+{re.escape(RAW_NAME)}\s*$", raw_lef_text, re.M):
                errors.append(f"{RAW_NAME} provisional LEF macro name mismatch")
            if not re.search(
                rf"^\s*FOREIGN\s+{re.escape(RAW_NAME)}\b", raw_lef_text, re.M
            ):
                errors.append(f"{RAW_NAME} provisional LEF FOREIGN name mismatch")
            raw_size = re.search(
                r"^\s*SIZE\s+([0-9.]+)\s+BY\s+([0-9.]+)\s*;",
                raw_lef_text,
                re.M,
            )
            if not raw_size or (
                abs(float(raw_size.group(1)) - WIDTH) > 1e-6
                or abs(float(raw_size.group(2)) - HEIGHT) > 1e-6
            ):
                errors.append(f"{RAW_NAME} provisional LEF boundary is incorrect")
            if not re.search(
                rf"^library\s*\(\s*{re.escape(RAW_NAME)}\s*\)",
                raw_liberty_text,
                re.M,
            ):
                errors.append(f"{RAW_NAME} provisional Liberty library name mismatch")
            if not re.search(
                rf"^\s*cell\s*\(\s*{re.escape(RAW_NAME)}\s*\)",
                raw_liberty_text,
                re.M,
            ):
                errors.append(f"{RAW_NAME} provisional Liberty cell name mismatch")

            if raw_header_directions is not None:
                for pin, direction in raw_header_directions.items():
                    if raw_lef_details.get(pin, {}).get("direction") != direction:
                        errors.append(
                            f"{RAW_NAME} provisional LEF direction mismatch for {pin}"
                        )
                    if raw_liberty_directions.get(pin) != direction:
                        errors.append(
                            f"{RAW_NAME} provisional Liberty direction mismatch for {pin}"
                        )

            reference_lef_text = (ROOT / expected_views(NVM_NAME)["lef"]).read_text(
                errors="replace"
            )
            reference_gds_path = ROOT / expected_views(NVM_NAME)["gds"]
            try:
                reference_gds_pins = gds_labeled_rectangles(
                    reference_gds_path,
                    MET3_GDS_LAYER,
                    PIN_GDS_DATATYPE,
                    LABEL_GDS_TEXTTYPE,
                )
            except ValueError as error:
                errors.append(f"{NVM_NAME} GDS pin mapping failed: {error}")
                reference_gds_pins = {}
            reference_obstructions = lef_obstructions(reference_lef_text)
            raw_obstructions = lef_obstructions(raw_lef_text)
            if raw_obstructions != reference_obstructions:
                errors.append(
                    f"{RAW_NAME} obstruction geometry must match the released X1 reference"
                )
            if [layer for layer, _rect in raw_obstructions] != EXPECTED_OBSTRUCTION_LAYERS:
                errors.append(f"{RAW_NAME} obstruction layers are incomplete")

            signal_lef_met2_rectangles = []
            signal_lef_met3_rectangles = []
            all_lef_met2_rectangles = []
            all_lef_met3_rectangles = []
            for pin, detail in raw_lef_details.items():
                if not detail["shapes"]:
                    errors.append(f"{RAW_NAME} provisional LEF pin {pin} has no shapes")
                    continue
                if pin in RAW_POWER_PINS:
                    reference_shapes = [
                        (
                            "met3",
                            tuple(value / 1000 for value in rectangle),
                        )
                        for rectangle in reference_gds_pins.get(pin, [])
                    ]
                    if set(detail["shapes"]) != set(reference_shapes):
                        errors.append(
                            f"{RAW_NAME} supply pin {pin} geometry differs from "
                            f"the released X1 reference"
                        )
                    if len(detail["shapes"]) != RAW_POWER_SHAPE_COUNTS[pin]:
                        errors.append(
                            f"{RAW_NAME} supply pin {pin} has the wrong number "
                            f"of distributed access shapes"
                        )
                elif len(detail["shapes"]) != 1:
                    errors.append(
                        f"{RAW_NAME} provisional LEF pin {pin} must have one perimeter shape"
                    )
                    continue
                for layer, rect in detail["shapes"]:
                    _x1, y1, _x2, y2 = rect
                    if pin in RAW_ANALOG_PINS:
                        if layer != "met3":
                            errors.append(f"{RAW_NAME} analog pin {pin} must use met3")
                        if y2 - y1 + 1e-6 < RAW_ANALOG_PIN_WIDTH:
                            errors.append(
                                f"{RAW_NAME} analog pin {pin} is narrower than "
                                f"{RAW_ANALOG_PIN_WIDTH} um"
                            )
                    if pin in RAW_POWER_PINS and layer != "met3":
                        errors.append(f"{RAW_NAME} supply pin {pin} must use met3")
                    if layer == "met2":
                        all_lef_met2_rectangles.append(rect)
                        if pin not in RAW_POWER_PINS:
                            signal_lef_met2_rectangles.append(rect)
                    elif layer == "met3":
                        all_lef_met3_rectangles.append(rect)
                        if pin not in RAW_POWER_PINS:
                            signal_lef_met3_rectangles.append(rect)
                    else:
                        errors.append(
                            f"{RAW_NAME} provisional LEF pin {pin} uses "
                            f"unexpected layer {layer}"
                        )
            validate_perimeter_shapes(
                errors,
                f"{RAW_NAME} provisional LEF",
                "met2",
                signal_lef_met2_rectangles,
            )
            validate_perimeter_shapes(
                errors,
                f"{RAW_NAME} provisional LEF",
                "met3",
                signal_lef_met3_rectangles,
            )
            if len(raw_lef_details) != RAW_WIRE_COUNT:
                errors.append(f"{RAW_NAME} provisional LEF pin count is incorrect")

            try:
                raw_structures, raw_gds_pins = read_gds(provisional_paths["gds"])
            except ValueError as error:
                errors.append(f"{RAW_NAME} provisional GDS parse failed: {error}")
                raw_structures, raw_gds_pins = [], set()
            if raw_structures != [RAW_NAME]:
                errors.append(
                    f"{RAW_NAME} provisional GDS structure names are {raw_structures}"
                )
            raw_gds_data = provisional_paths["gds"].read_bytes()
            if b"PROVISIONAL_RAW_INTERFACE" not in raw_gds_data:
                errors.append(f"{RAW_NAME} GDS lacks its provisional library marker")
            raw_boundary = (0, 0, round(WIDTH * 1000), round(HEIGHT * 1000))
            if raw_boundary not in gds_rectangles(provisional_paths["gds"], 235, 4):
                errors.append(f"{RAW_NAME} provisional GDS boundary is incorrect")
            gds_met2_rectangles = gds_rectangles(
                provisional_paths["gds"], MET2_GDS_LAYER, PIN_GDS_DATATYPE
            )
            gds_met3_rectangles = gds_rectangles(
                provisional_paths["gds"], MET3_GDS_LAYER, PIN_GDS_DATATYPE
            )
            expected_gds_met2 = {
                tuple(round(value * 1000) for value in rect)
                for rect in all_lef_met2_rectangles
            }
            expected_gds_met3 = {
                tuple(round(value * 1000) for value in rect)
                for rect in all_lef_met3_rectangles
            }
            power_gds_met3 = {
                tuple(round(value * 1000) for value in rect)
                for pin in RAW_POWER_PINS
                for layer, rect in raw_lef_details[pin]["shapes"]
                if layer == "met3"
            }
            validate_perimeter_shapes(
                errors,
                f"{RAW_NAME} provisional GDS",
                "met2",
                gds_met2_rectangles,
                scale=1000.0,
            )
            validate_perimeter_shapes(
                errors,
                f"{RAW_NAME} provisional GDS",
                "met3",
                gds_met3_rectangles - power_gds_met3,
                scale=1000.0,
            )
            if gds_met2_rectangles != expected_gds_met2:
                errors.append(f"{RAW_NAME} met2 pin geometry differs between LEF and GDS")
            if gds_met3_rectangles != expected_gds_met3:
                errors.append(f"{RAW_NAME} met3 pin geometry differs between LEF and GDS")
            for view_name, pins in {
                "provisional LEF": lef_pins(raw_lef_text),
                "provisional Liberty": liberty_pins(raw_liberty_text),
                "provisional GDS": raw_gds_pins,
            }.items():
                report_pin_difference(
                    errors, RAW_NAME, view_name, raw_header_ports, pins
                )

for name in sorted(RELEASED_NAMES):
    cell = cells.get(name)
    if not cell:
        continue

    if cell.get("power_connections") != EXPECTED_POWER_CONNECTIONS:
        errors.append(f"{name} power connections do not match the required domains")
    if cell.get("power_voltage_v") != EXPECTED_POWER_VOLTAGE:
        errors.append(f"{name} power voltages do not match the macro specification")
    if abs(float(cell.get("width_um", -1)) - WIDTH) > 1e-6:
        errors.append(f"{name} manifest width is not {WIDTH} um")
    if abs(float(cell.get("height_um", -1)) - HEIGHT) > 1e-6:
        errors.append(f"{name} manifest height is not {HEIGHT} um")

    views = cell.get("views", {})
    expected = expected_views(name)
    if views != expected:
        errors.append(f"{name} manifest view paths do not follow the release layout")

    paths = {key: ROOT / relative for key, relative in expected.items()}
    missing_paths = [path for path in paths.values() if not path.is_file()]
    for path in missing_paths:
        errors.append(f"missing required file: {path.relative_to(ROOT)}")
    if missing_paths:
        continue

    lef_text = paths["lef"].read_text(errors="replace")
    liberty_text = paths["liberty"].read_text(errors="replace")
    header_text = paths["verilog_header"].read_text(errors="replace")
    behavioral_text = paths["verilog_behavioral"].read_text(errors="replace")
    testbench_text = paths["testbench"].read_text(errors="replace")

    if not re.search(rf"^MACRO\s+{re.escape(name)}\s*$", lef_text, re.M):
        errors.append(f"{name} LEF macro name mismatch")
    if not re.search(rf"^\s*FOREIGN\s+{re.escape(name)}\b", lef_text, re.M):
        errors.append(f"{name} LEF FOREIGN name mismatch")
    size = re.search(r"^\s*SIZE\s+([0-9.]+)\s+BY\s+([0-9.]+)\s*;", lef_text, re.M)
    if not size:
        errors.append(f"{name} LEF SIZE statement missing")
    elif (
        abs(float(size.group(1)) - WIDTH) > 1e-6
        or abs(float(size.group(2)) - HEIGHT) > 1e-6
    ):
        errors.append(f"{name} LEF boundary changed: {size.group(1)} x {size.group(2)} um")

    if not re.search(rf"^library\s*\(\s*{re.escape(name)}\s*\)", liberty_text, re.M):
        errors.append(f"{name} Liberty library name mismatch")
    if not re.search(rf"^\s*cell\s*\(\s*{re.escape(name)}\s*\)", liberty_text, re.M):
        errors.append(f"{name} Liberty cell name mismatch")

    header_pin_set = verilog_ports(paths["verilog_header"], name)
    behavioral_pin_set = verilog_ports(paths["verilog_behavioral"], name)
    header_directions = verilog_port_directions(paths["verilog_header"], name)
    behavioral_directions = verilog_port_directions(
        paths["verilog_behavioral"], name
    )
    released_lef_details = lef_pin_details(lef_text)
    released_liberty_directions = liberty_pin_directions(liberty_text)
    if header_pin_set is None:
        errors.append(f"{name} Verilog header module name mismatch")
    if behavioral_pin_set is None:
        errors.append(f"{name} behavioral module name mismatch")
    if not re.search(rf"\bmodule\s+{re.escape(name)}_tb\b", testbench_text):
        errors.append(f"{name} testbench module name mismatch")

    try:
        structures, gds_pin_set = read_gds(paths["gds"])
    except ValueError as error:
        errors.append(f"{name} GDS parse failed: {error}")
        structures, gds_pin_set = [], set()
    if structures != [name]:
        errors.append(f"{name} GDS structure names are {structures}")

    for pin in sorted(RAW_ANALOG_PINS):
        analog_directions = {
            "Verilog header": (header_directions or {}).get(pin),
            "behavioral Verilog": (behavioral_directions or {}).get(pin),
            "LEF": released_lef_details.get(pin, {}).get("direction"),
            "Liberty": released_liberty_directions.get(pin),
        }
        for view_name, direction in analog_directions.items():
            if direction != "inout":
                errors.append(
                    f"{name} {view_name} analog pin {pin} must be inout"
                )

    reference_pins = lef_pins(lef_text)
    if len(reference_pins) != PIN_COUNT:
        errors.append(f"{name} LEF expected {PIN_COUNT} pins, found {len(reference_pins)}")

    exact_pin_views = {
        "Liberty": liberty_pins(liberty_text),
        "GDS": gds_pin_set,
    }
    if header_pin_set is not None:
        exact_pin_views["Verilog header"] = header_pin_set
    for view_name, actual_pins in exact_pin_views.items():
        report_pin_difference(errors, name, view_name, reference_pins, actual_pins)
    if behavioral_pin_set is not None:
        report_pin_difference(
            errors,
            name,
            "behavioral Verilog",
            reference_pins,
            behavioral_pin_set,
            allow_extra=(name == CIM_NAME),
        )

    for path, text in {
        paths["lef"]: lef_text,
        paths["liberty"]: liberty_text,
        paths["verilog_header"]: header_text,
        paths["verilog_behavioral"]: behavioral_text,
        paths["testbench"]: testbench_text,
    }.items():
        for legacy, pattern in LEGACY_NAME_PATTERNS.items():
            if re.search(pattern, text):
                errors.append(
                    f"legacy name {legacy} remains in {path.relative_to(ROOT)}"
                )

if errors:
    print("IP view validation FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

for name in sorted(RELEASED_NAMES):
    print(f"PASS: {name}")
    print(f"PASS: {name} boundary {WIDTH} x {HEIGHT} um")
    print(f"PASS: {name} has {PIN_COUNT} consistent physical-interface pins")
    print(f"PASS: {name} analog pins are inout in Verilog, LEF and Liberty")
print("PASS: separate 1.8 V vccd1/vccd2 digital domains")
print("PASS: separate 3.3 V vdda1/vdda2 analog domains")
print("PASS: digital and analog domains share vssd1 ground")
print(
    f"PASS: {RAW_NAME} simulation interface has "
    f"{RAW_FUNCTIONAL_WIRE_COUNT} non-power wires including "
    f"{RAW_SCAN_PORT_COUNT} reference scan/test and "
    f"{RAW_ANALOG_PORT_COUNT} reference analog pins, plus "
    f"{len(RAW_POWER_PINS)} power pins"
)
print(
    f"PASS: {RAW_NAME} provisional GDS/LEF/Liberty have "
    f"{RAW_WIRE_COUNT} consistent pins and remain outside the signoff release"
)
print(
    f"PASS: {RAW_NAME} north/south pins are met2 X-grid aligned and "
    "west/east pins are met3 Y-grid aligned"
)
print(
    f"PASS: {RAW_NAME} analog pins use {RAW_ANALOG_PIN_WIDTH:.2f} um met3 access "
    "and supplies use the released X1 distributed met3 access geometry"
)
print(
    f"PASS: {RAW_NAME} LEF obstructions match the released X1 reference on "
    + ", ".join(EXPECTED_OBSTRUCTION_LAYERS)
)
