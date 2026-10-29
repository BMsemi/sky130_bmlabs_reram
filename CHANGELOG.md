# Changelog

## Unreleased

- Renamed the released X2 Wishbone macro to
  `sky130_bmlabs_reram__cim32x32wb` across GDS, LEF, Liberty and Verilog views.
- Reserved `sky130_bmlabs_reram__cim32x32` for the X2 raw signal interface and
  `sky130_bmlabs_reram__nvm32x32wb` for the X1 Wishbone macro; neither planned
  cell is presented as a released physical view.
- Removed project-specific interface naming from the reusable IP catalog and
  documentation.
- Documented the required separate `vccd1`, `vccd2`, `vdda1` and `vdda2`
  supply domains and the common digital/analog `VSS` ground.
- Removed the reversed submodule dependency on the chip project.
- Added a machine-readable catalog, integration guidance and automated
  cross-view validation.
