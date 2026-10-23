# X2 FPGA compact-interface completion gate

The Teams review records an approved compact raw X2 interface with 156 wires.
That archive was named `X2_FPGA_raw_compact.zip`, but it is not present in the
Git repositories currently available to this project.

The repository therefore separates two facts:

1. `sky130_bmlabs_reram__cim32x32` contains the currently verifiable physical GDS/LEF/Liberty and
   Wishbone-facing simulation views.
2. The FABulous supertile interface must not be declared complete until the
   approved compact archive is recovered and matched to physical views.

## Required work when the archive is available

1. Preserve the raw compact module and testbench without changing port meaning.
2. Record every port, direction and width in a machine-readable interface file.
3. Confirm the aggregate signal count is exactly 156 using the same counting
   rule used during Leo's review.
4. Generate or obtain matching GDS, LEF, Liberty and Verilog black-box views.
5. Confirm the module/cell name and every digital, analog, test and supply pin
   match across all views.
6. Add an FPGA primitive wrapper and a cocotb handshake example.
7. Run the repository validator and chip-level DRC/LVS integration.

Until those checks pass, a project must use the qualified Wishbone release or
treat the compact interface as simulation-only. No guessed compact pin mapping
should be committed.
