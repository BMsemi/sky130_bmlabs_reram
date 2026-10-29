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

The released stream structure, LEF macro, Liberty cell and Verilog module are
all named `sky130_bmlabs_reram__cim32x32wb`. Its boundary remains
1910 x 2010.14 um.

`sky130_bmlabs_reram__cim32x32` is reserved for the raw signal interface and is
not a released physical macro. See `POWER_PINS.md` before connecting the
released macro's supply pins.
