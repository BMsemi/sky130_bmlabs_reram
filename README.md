# sky130_bmlabs_reram

Reusable SKY130 ReRAM hard-macro library from BM Labs.

This repository is the **IP source repository**. Chip projects consume a pinned
revision of it as a Git submodule; project-specific wrappers, placement, PDN and
routing constraints stay in the chip project repository.

## Cell catalog

| Cell | Function | Interface | Release state |
|---|---|---|---|
| `sky130_bmlabs_reram__cim32x32` | 32 x 32 ReRAM compute-in-memory accelerator | Raw signals plus reference analog/test pins | Provisional floorplanning views; not for signoff or tapeout |
| `sky130_bmlabs_reram__cim32x32wb` | 32 x 32 ReRAM compute-in-memory accelerator | 32-bit Wishbone plus analog/test pins | Released; 1910 x 2010.14 um |
| `sky130_bmlabs_reram__nvm32x32wb` | 32 x 32 ReRAM non-volatile memory | 32-bit Wishbone plus analog/test pins | Released; 1910 x 2010.14 um |

Cell names follow the open-PDK convention:

`<node>_<vendor>_<library>__<cell>`

The `cim` and `nvm` portions identify the macro capability. The `wb` suffix
identifies the Wishbone interface. A cell name is not tied to the project that
consumes the IP.

`sky130_bmlabs_reram__cim32x32wb` and
`sky130_bmlabs_reram__nvm32x32wb` have complete, cross-checked
GDS/LEF/Liberty/Verilog releases in this repository. The reserved raw-interface
cell has a behavioral model, testbench and Verilog header. Approximate GDS,
LEF and Liberty placeholders are also provided for early floorplanning and
file-flow testing only. They are not extracted or characterized views and must
not be used for LVS, timing signoff, fabrication or tapeout. See
`doc/RAW_INTERFACE.md` and `doc/IP_CATALOG.md`.
The X1 command encoding, modeled behavior and simulation limitations are
documented in `doc/NVM_BEHAVIORAL_MODEL.md`.
Analog bias pins must connect to analog pads using thick NDR routes; pin widths,
nominal values and verification requirements are in `doc/ANALOG_ROUTING.md`.

## Repository layout

- `gds/`: stream layout
- `lef/`: abstract physical view
- `lib/`: timing/library view
- `verilog/vh/`: LibreLane Verilog headers (`.vh`)
- `verilog/behavioral/`: behavioral models and self-checking testbenches
- `doc/`: integration, interface and power-pin notes
- `scripts/check_views.py`: cross-view consistency validation
- `ip_manifest.json`: machine-readable IP catalog

## Power pins

The released Wishbone macros use separate 1.8 V digital connections and
separate 3.3 V analog connections. For Caravel integration, connect
`VDDC1 -> vccd1`, `VDDC2 -> vccd2`, `VDDA1 -> vdda1`, `VDDA2 -> vdda2`, and
the common `VSS` pin to `vssd1`. Do not short either numbered supply pair. See
`doc/POWER_PINS.md` for the supply rules and `doc/ANALOG_ROUTING.md` for the
separate analog-bias routing requirements.

## Using from a chip project

```sh
git submodule add https://github.com/BMsemi/sky130_bmlabs_reram.git ip/sky130_bmlabs_reram
git submodule update --init --recursive
python3 ip/sky130_bmlabs_reram/scripts/check_views.py
```

Pin the submodule to a reviewed commit or release tag. Do not copy the IP views
into the project because that allows GDS, LEF, Liberty and Verilog to drift.

## Validation

Run:

```sh
python3 scripts/check_views.py
```

The check enforces each released cell name, fixed 1910 x 2010.14 um boundary,
required views, cross-view pin sets, LEF macro and GDS structure names. It also
checks the raw-interface simulation views, their 167 non-power wires, five
reference-derived supply pins and the explicit provisional markings on the
approximate physical placeholders. The scan/test and analog boundary names are
also checked against the released Wishbone reference. The cell remains outside
the qualified physical release set.

See `CHANGELOG.md` for repository changes.
