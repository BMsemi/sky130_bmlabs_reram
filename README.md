# sky130_bmlabs_reram

Reusable SKY130 ReRAM hard-macro library from BM Labs.

This repository is the **IP source repository**. Chip projects consume a pinned
revision of it as a Git submodule; project-specific wrappers, placement, PDN and
routing constraints stay in the chip project repository.

## Cell catalog

| Cell | Function | Interface | Release state |
|---|---|---|---|
| `sky130_bmlabs_reram__cim32x32` | 32 x 32 ReRAM compute-in-memory accelerator | Raw signals | Reserved name; verified views not yet available |
| `sky130_bmlabs_reram__cim32x32wb` | 32 x 32 ReRAM compute-in-memory accelerator | 32-bit Wishbone plus analog/test pins | Released; 1910 x 2010.14 um |
| `sky130_bmlabs_reram__nvm32x32wb` | 32 x 32 ReRAM non-volatile memory | 32-bit Wishbone plus analog/test pins | Planned; verified views not yet available |

Cell names follow the open-PDK convention:

`<node>_<vendor>_<library>__<cell>`

The `cim` and `nvm` portions identify the macro capability. The `wb` suffix
identifies the Wishbone interface. A cell name is not tied to the project that
consumes the IP.

Only `sky130_bmlabs_reram__cim32x32wb` currently has a complete, cross-checked
GDS/LEF/Liberty/Verilog release in this repository. The reserved raw-interface
and planned NVM names must not be used as physical macros until matching,
verified view sets are published. See `doc/RAW_INTERFACE.md` and
`doc/IP_CATALOG.md`.

## Repository layout

- `gds/`: stream layout
- `lef/`: abstract physical view
- `lib/`: timing/library view
- `verilog/`: black-box and behavioral simulation views
- `doc/`: integration, interface and power-pin notes
- `scripts/check_views.py`: cross-view consistency validation
- `ip_manifest.json`: machine-readable IP catalog

## Power pins

The released macro requires four separate supply connections:
`VDDC1 -> vccd1`, `VDDC2 -> vccd2`, `VDDA1 -> vdda1` and `VDDA2 -> vdda2`.
Digital and analog circuitry share the macro's single `VSS` ground. Do not
merge the four supply domains or split the ground in any IP view. See
`doc/POWER_PINS.md` for the integration rules.

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

The check enforces the released cell name, fixed 1910 x 2010.14 um boundary,
required views, expected LEF macro and GDS structure name, and the documented
planned-cell names.

See `CHANGELOG.md` for repository changes.
