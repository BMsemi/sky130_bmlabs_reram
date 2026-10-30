# Changelog

## Unreleased

- Removed the behavioral-only `TM_o` output from
  `sky130_bmlabs_reram__cim32x32wb`; it is absent from the released physical
  and black-box interfaces. The common scan/test interface retains `TM` and
  `ScanOutCC`.
- Added the supplied `sky130_bmlabs_reram__cim32x32` raw-interface behavioral
  model, self-checking testbench and matching integration shell.
- Added reproducible provisional GDS, LEF and Liberty placeholders using the
  released X2 boundary, synthetic perimeter pin placement and an
  uncharacterized `dont_use` Liberty shell. These views are explicitly limited
  to floorplanning and file-flow testing and are not signoff or tapeout views.
- Aligned the raw cell's external scan/test names and ten analog boundary pins
  with the released X2 Wishbone reference. The resulting interface has 167
  non-power wires plus five reference-derived power pins. Qualified physical
  views remain gated because the released
  Wishbone GDS/LEF/Liberty has a different 128-pin interface and must not be
  copied or relabeled.
- Added the complete `sky130_bmlabs_reram__nvm32x32wb` X1 release: GDS, LEF,
  Liberty, black-box Verilog, behavioral model and self-checking testbench.
- Aligned the X1 behavioral interface to the 128 verified physical pins; the
  source-only `Vcc_reset`, `Vcc_L` and `Vcc_Body` ports were omitted because
  they are absent from the supplied GDS, LEF and Liberty views.
- Documented the X1 Wishbone command format and behavioral-model limits,
  prevented unsupported modes from blocking the input FIFO, and expanded the
  self-checking testbench to cover SET, RESET, READ and reset persistence.
- Renamed the released X2 Wishbone macro to
  `sky130_bmlabs_reram__cim32x32wb` across GDS, LEF, Liberty and Verilog views.
- Reserved `sky130_bmlabs_reram__cim32x32` for the X2 raw signal interface and
  `sky130_bmlabs_reram__nvm32x32wb` for the X1 Wishbone macro; the raw-interface
  cell is not presented as a released physical view.
- Removed project-specific interface naming from the reusable IP catalog and
  documentation.
- Corrected the analog supply specification to 3.3 V and documented the final
  Caravel mapping: `VDDC1 -> vccd1`, `VDDC2 -> vccd2`, `VDDA1 -> vdda1`,
  `VDDA2 -> vdda2`, and the common digital/analog `VSS -> vssd1` ground.
- Removed the reversed submodule dependency on the chip project.
- Added a machine-readable catalog, integration guidance and automated
  cross-view validation.
