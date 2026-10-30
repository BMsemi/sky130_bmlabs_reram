# Integration guide

## Dependency direction

The chip project depends on this repository:

```text
chip project
└── ip/sky130_bmlabs_reram  (Git submodule)
    ├── gds
    ├── lef
    ├── lib
    └── verilog
        ├── vh
        └── behavioral
```

This IP repository must never point back to a chip project.

## OpenLane / LibreLane

Reference the files beneath the submodule directly from the project's
`MACROS` configuration. Keep these project-specific items outside this
repository:

- macro instance names, locations and orientations;
- PDN connections and voltage-domain selection;
- non-default-routing rules;
- wrapper RTL and external bus bridges;
- foundry-fixed pin templates.

Use LibreLane's supported configuration fields for NDR. Do not patch files in
an installed LibreLane or Nix store.

## Cell identity

The released stream structure, LEF macro, Liberty cell and Verilog module names
are:

- `sky130_bmlabs_reram__cim32x32wb` for the X2 compute-in-memory Wishbone macro;
- `sky130_bmlabs_reram__nvm32x32wb` for the X1 non-volatile-memory Wishbone
  macro.

Both boundaries are 1910 x 2010.14 um.

`sky130_bmlabs_reram__cim32x32` provides behavioral simulation and interface
views for the raw signal interface. Its approximate GDS, LEF and Liberty files
may be referenced only for early floorplanning and file-flow testing. They are
synthetic, uncharacterized and unsuitable for LVS, signoff or tapeout. See
`RAW_INTERFACE.md` for its release gate and `POWER_PINS.md` before connecting
the supply pins. Its analog and scan/test boundary names match the released X2
Wishbone reference, but the raw behavioral model does not simulate analog
electrical behavior. Every analog bias pin requires an analog-pad connection
and a matching-or-wider NDR as described in `ANALOG_ROUTING.md`. See
`NVM_BEHAVIORAL_MODEL.md` for the X1 command format and the limits of its
functional simulation model.
