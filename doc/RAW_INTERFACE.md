# Raw signal interface release gate

`sky130_bmlabs_reram__cim32x32` is the reserved name for the X2 macro with a
raw signal interface. It is a reusable IP name and does not identify a
particular consuming project.

The repository does not currently contain a verified raw-interface source and
matching physical views. The released Wishbone macro is
`sky130_bmlabs_reram__cim32x32wb`; it must not be relabeled as the raw-interface
cell.

## Required work before release

1. Preserve the approved raw module and testbench without changing port
   meaning.
2. Record every port, direction and width in a machine-readable interface
   description.
3. Confirm the approved aggregate signal count with the same counting rule used
   during interface review.
4. Generate or obtain matching GDS, LEF, Liberty and Verilog black-box views.
5. Confirm that the module/cell name and every digital, analog, test and supply
   pin match across all views.
6. Add behavioral tests for the raw-interface protocol.
7. Run the repository validator and chip-level DRC/LVS integration.

Until those checks pass, consumers must use the qualified
`sky130_bmlabs_reram__cim32x32wb` release. No guessed raw pin mapping should be
committed.
