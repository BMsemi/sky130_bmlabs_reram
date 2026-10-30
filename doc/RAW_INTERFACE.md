# Raw signal interface release gate

`sky130_bmlabs_reram__cim32x32` is the reserved name for the X2 macro with a
raw signal interface. It is a reusable IP name and does not identify a
particular consuming project.

The repository contains the supplied behavioral model, its testbench and a
matching Verilog header. Its external boundary uses the same scan/test names
and ten analog pin names as the released X2 Wishbone macro. After expanding
buses, the cell has 167 non-power wires and five optional supply ports under
`USE_POWER_PINS` (`VDDC1`, `VDDC2`, `VDDA1`, `VDDA2` and `VSS`), for 49 port
declarations and 172 physical pins in total.

The shared scan/test boundary is `ScanInCC`, `ScanInDL`, `ScanInDR`, `TM` and
`ScanOutCC`. The shared analog boundary is `Iref`, `Vcc_read`, `Vcomp`,
`Bias_comp2`, `Vcc_wl_read`, `Vcc_wl_set`, `Vbias`, `Vcc_wl_reset`, `Vcc_set`
and `dc_bias`. These analog inouts are interface-only in the digital behavioral
model; their electrical effects are not simulated.

Signoff physical views have not been supplied. The released Wishbone macro is
`sky130_bmlabs_reram__cim32x32wb`; its 128-pin GDS, LEF and Liberty views have a
different interface and were not copied or relabeled as this raw-interface
cell.

## Available simulation views

- `verilog/vh/sky130_bmlabs_reram__cim32x32.vh`: LibreLane Verilog header;
- `verilog/behavioral/sky130_bmlabs_reram__cim32x32.sv`: behavioral model;
- `verilog/behavioral/sky130_bmlabs_reram__cim32x32_tb.sv`: supplied
  self-checking testbench.

## Provisional physical placeholders

Approximate GDS, LEF and Liberty files are provided to support early
floorplanning and file-flow testing. They use the released X2 boundary of
1910 x 2010.14 um, 167 non-power wires and the five reference-derived supply
pins.

- The GDS contains only a macro boundary and synthetic perimeter pin shapes and
  labels. It does not contain the real internal device or routing geometry.
- The LEF uses the same boundary and synthetic, routing-grid-aligned perimeter
  pins. North/south pins are on vertical met2 tracks (`X = 0.23 + N*0.46 um`),
  while west/east pins are on horizontal met3 tracks
  (`Y = 0.34 + N*0.68 um`). All ten analog pins have 1.30 um-wide met3 access
  for matching-or-wider NDR routes to analog pads. Each supply has a separate,
  full-width 1.80 um met3 strap. These locations are not approved signoff pin
  coordinates; see `ANALOG_ROUTING.md` and `POWER_PINS.md` for integration
  requirements.
- The Liberty file is an uncharacterized interface shell with no timing arcs
  and `dont_use : true`.

All three files are marked provisional. They must not be used for LVS, timing
signoff, fabrication or tapeout. Regenerate them deterministically with
`python3 scripts/generate_provisional_raw_views.py`.

## Required work before release

1. Provide the physical raw-interface implementation and its approved power-pin
   specification.
2. Generate GDS and LEF from that implementation with approved pin placement.
3. Characterize a matching Liberty view rather than copying the Wishbone view.
4. Confirm that the module/cell name and every signal, test and supply pin match
   across all views.
5. Run timing checks, repository validation and chip-level DRC/LVS integration.

Until those checks pass, the physical placeholders are for early integration
only. Consumers that require a qualified physical macro must use the
`sky130_bmlabs_reram__cim32x32wb` release. The provisional files must be
replaced, not promoted, when extracted and characterized raw-interface views
become available.
