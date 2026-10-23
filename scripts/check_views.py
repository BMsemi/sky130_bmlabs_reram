#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "sky130_bmlabs_reram__cim32x32"
OLD = "sky130_bmlabs_reram__nvm32x32"
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
    if NAME not in manifest.get("cells", {}):
        errors.append(f"{NAME} absent from ip_manifest.json")

    lef = (ROOT / "lef" / f"{NAME}.lef").read_text(errors="replace")
    if not re.search(rf"^MACRO\s+{re.escape(NAME)}\s*$", lef, re.M):
        errors.append("LEF macro name mismatch")
    size = re.search(r"^\s*SIZE\s+([0-9.]+)\s+BY\s+([0-9.]+)\s*;", lef, re.M)
    if not size:
        errors.append("LEF SIZE statement missing")
    elif abs(float(size.group(1)) - WIDTH) > 1e-6 or abs(float(size.group(2)) - HEIGHT) > 1e-6:
        errors.append(f"LEF boundary changed: {size.group(1)} x {size.group(2)} um")
    pin_count = len(re.findall(r"^\s+PIN\s+\S+", lef, re.M))
    if pin_count != 128:
        errors.append(f"qualified Wishbone LEF expected 128 pins, found {pin_count}")

    for rel in [f"lib/{NAME}.lib", f"verilog/{NAME}.v",
                f"verilog/behavioral/{NAME}.sv",
                f"verilog/behavioral/{NAME}_tb.sv"]:
        text = (ROOT / rel).read_text(errors="replace")
        if OLD in text:
            errors.append(f"legacy X2-as-NVM name remains in {rel}")

    stub = (ROOT / "verilog" / f"{NAME}.v").read_text(errors="replace")
    if not re.search(rf"\bmodule\s+{re.escape(NAME)}\b", stub):
        errors.append("Verilog black-box module name mismatch")

    gds = (ROOT / "gds" / f"{NAME}.gds").read_bytes()
    if NAME.encode() not in gds:
        errors.append("GDS structure name mismatch")
    if OLD.encode() in gds:
        errors.append("legacy X2-as-NVM structure name remains in GDS")

if errors:
    print("IP view validation FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print(f"PASS: {NAME}")
print(f"PASS: fixed boundary {WIDTH} x {HEIGHT} um")
print("PASS: GDS/LEF/Liberty/Verilog naming is consistent")
print("PASS: qualified Wishbone LEF contains 128 pins")
