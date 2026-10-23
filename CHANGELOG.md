# Changelog

## Unreleased

- Restructured the repository as the reusable `sky130_bmlabs_reram` IP library.
- Corrected the X2 capability name from `nvm32x32` to `cim32x32` across GDS,
  LEF, Liberty and Verilog views while preserving the fixed macro boundary.
- Removed the reversed submodule dependency on the chip project.
- Added machine-readable catalog, integration guidance and automated cross-view
  validation.
- Recorded the approved 156-wire FPGA interface as a gated follow-up because its
  source archive is not present in Git.
