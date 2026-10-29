#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "sky130_bmlabs_reram__cim32x32wb"
RAW_NAME = "sky130_bmlabs_reram__cim32x32"
NVM_NAME = "sky130_bmlabs_reram__nvm32x32wb"
LEGACY_NAMES = {
    "sky130_bmlabs_reram__nvm32x32",
}
WIDTH = 1910.0
HEIGHT = 2010.14

required = [
    ROOT / "ip_manifest.json",
    ROOT / "gds" / f"{NAME}.gds",
    ROOT / "lef" / f"{NAME}.lef",
    ROOT / "lib" / f"{NAME}.lib",
    ROOT / "verilog" / f"{NAME}.v",
    ROOT / "verilog" / "behavioral" / f"{NAME}.sv",
    ROOT / "verilog" / "behavioral" / f"{NAME}_tb.sv",
]

errors = []
for path in required:
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")

if not errors:
    manifest = json.loads((ROOT / "ip_manifest.json").read_text())
    cells = manifest.get("cells", {})
    if set(cells) != {NAME}:
        errors.append(f"released manifest cells must contain only {NAME}")
    expected_power_connections = {
        "VDDC1": "vccd1",
        "VDDC2": "vccd2",
        "VDDA1": "vdda1",
        "VDDA2": "vdda2",
        "VSS": "vssd1",
    }
    if cells.get(NAME, {}).get("power_connections") != expected_power_connections:
        errors.append("released power connections do not match the required domains")
    expected_power_voltage = {
        "VDDC1": 1.8,
        "VDDC2": 1.8,
        "VDDA1": 3.3,
        "VDDA2": 3.3,
        "VSS": 0,
    }
    if cells.get(NAME, {}).get("power_voltage_v") != expected_power_voltage:
        errors.append("released power voltages do not match the macro specification")

    planned = {cell.get("name") for cell in manifest.get("planned_cells", [])}
    if planned != {RAW_NAME, NVM_NAME}:
        errors.append(
            "planned manifest cells must be exactly "
            f"{RAW_NAME} and {NVM_NAME}"
        )

    lef = (ROOT / "lef" / f"{NAME}.lef").read_text(errors="replace")
    if not re.search(rf"^MACRO\s+{re.escape(NAME)}\s*$", lef, re.M):
        errors.append("LEF macro name mismatch")
    size = re.search(r"^\s*SIZE\s+([0-9.]+)\s+BY\s+([0-9.]+)\s*;", lef, re.M)
    if not size:
        errors.append("LEF SIZE statement missing")
    elif (
        abs(float(size.group(1)) - WIDTH) > 1e-6
        or abs(float(size.group(2)) - HEIGHT) > 1e-6
    ):
        errors.append(f"LEF boundary changed: {size.group(1)} x {size.group(2)} um")
    pin_count = len(re.findall(r"^\s+PIN\s+\S+", lef, re.M))
    if pin_count != 128:
        errors.append(f"qualified Wishbone LEF expected 128 pins, found {pin_count}")

    text_views = [
        ROOT / "lef" / f"{NAME}.lef",
        ROOT / "lib" / f"{NAME}.lib",
        ROOT / "verilog" / f"{NAME}.v",
        ROOT / "verilog" / "behavioral" / f"{NAME}.sv",
        ROOT / "verilog" / "behavioral" / f"{NAME}_tb.sv",
    ]
    for path in text_views:
        text = path.read_text(errors="replace")
        for legacy in LEGACY_NAMES:
            if legacy in text:
                errors.append(
                    f"legacy name {legacy} remains in {path.relative_to(ROOT)}"
                )

    stub = (ROOT / "verilog" / f"{NAME}.v").read_text(errors="replace")
    if not re.search(rf"\bmodule\s+{re.escape(NAME)}\b", stub):
        errors.append("Verilog black-box module name mismatch")

    gds = (ROOT / "gds" / f"{NAME}.gds").read_bytes()
    if NAME.encode() not in gds:
        errors.append("GDS structure name mismatch")
    for legacy in LEGACY_NAMES | {RAW_NAME}:
        encoded = legacy.encode() + (b"\0" if len(legacy) % 2 else b"")
        if encoded in gds:
            errors.append(f"legacy or reserved structure name {legacy} remains in GDS")

if errors:
    print("IP view validation FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print(f"PASS: {NAME}")
print(f"PASS: fixed boundary {WIDTH} x {HEIGHT} um")
print("PASS: GDS/LEF/Liberty/Verilog naming is consistent")
print("PASS: qualified Wishbone LEF contains 128 pins")
print("PASS: VDDC1/VDDC2 use separate 1.8 V vccd1/vccd2 domains")
print("PASS: VDDA1/VDDA2 use separate 3.3 V vdda1/vdda2 domains")
print("PASS: digital and analog domains share vssd1 ground")
print(f"PASS: planned names are {RAW_NAME} and {NVM_NAME}")
