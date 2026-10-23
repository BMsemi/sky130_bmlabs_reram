# sky130_bmlabs_reram

Reusable SKY130 ReRAM hard-macro library from BM Labs.

This repository is the **IP source repository**. Chip projects consume a pinned
revision of it as a Git submodule; project-specific wrappers, placement, PDN and
routing constraints stay in the chip project repository.

## Released cell

| Cell | Function | Physical size | Qualified interface |
|---|---|---:|---|
| `sky130_bmlabs_reram__cim32x32` | 32 x 32 ReRAM compute-in-memory accelerator (program, read and dot-product compute) | 1910 x 2010.14 um | 32-bit Wishbone wrapper plus analog/test pins |

The cell name follows the open-PDK convention:

`<node>_<vendor>_<library>__<cell>`

Therefore this X2 compute-in-memory macro is named `sky130_bmlabs_reram__cim32x32`.
The X1 storage-only macro will use `sky130_bmlabs_reram__nvm32x32` when its
verified cross-view release is added.

## Repository layout

- `gds/`: stream layout
- `lef/`: abstract physical view
- `lib/`: timing/library view
- `verilog/`: black-box and behavioral simulation views
- `doc/`: integration and interface notes
- `scripts/check_views.py`: cross-view consistency validation
- `ip_manifest.json`: machine-readable IP catalog

## FPGA compact interface

Leo approved an X2 raw compact interface of **156 wires**. The original
`X2_FPGA_raw_compact.zip` is not present in the Git repositories, so this
repository does not invent that pinout. The qualified physical release here
retains the verified Wishbone/analog/test pin interface. See
`doc/FPGA_COMPACT_INTERFACE.md` for the exact completion gate.

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

The check enforces cell-name consistency, the fixed 1910 x 2010.14 um boundary,
required views, the expected LEF macro and the GDS structure name.

## Status

- X2/CIM Wishbone physical views: available
- X2/CIM 156-wire FPGA raw compact view: awaiting the approved source archive
- X1/NVM views: awaiting a separately verified X1 release

See `CHANGELOG.md` for repository changes.
