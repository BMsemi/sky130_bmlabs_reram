# Selectable raw/Wishbone interface release gate

`sky130_bmlabs_reram__cim32x32` is the reserved name for the X2 macro with a
selectable direct/raw and Wishbone interface. Drive `interface_sel` low for the
decoded direct stream or high for the Wishbone packet interface. It is a
reusable IP name and does not identify a particular consuming project.

The repository contains the supplied behavioral model, its testbench and a
matching Verilog header. Its external boundary uses the same scan/test names
and ten analog pin names as the released X2 Wishbone macro, plus the raw-macro
`VCC_SNEAK` analog pin. The physical boundary also includes `interface_sel`,
`i_Levelsh_enable` and the complete Wishbone bus. The analog/TDC stop bus is
internal to the macro and is not customer-visible. After expanding buses, the
cell has 274 non-power wires
and five optional supply ports under `USE_POWER_PINS` (`VDDC1`, `VDDC2`,
`VDDA1`, `VDDA2` and `VSS`), for 60 port declarations and 279 physical pins in
total.

The behavioral model includes a digital surrogate for the internal analog stop
response used by the RTL testbenches. While the internal ramp is active, the
selected bitline stop mask is asserted after 240 ns and is cleared immediately
when the ramp ends or reset is asserted. The stop event is therefore generated
inside the model; customers do not drive a `stop_bit_i` port. Result values are
still derived from the deterministic modeled ReRAM state. Comparator-level and
stop-edge accuracy requires AMS or extracted post-layout verification.

The shared scan/test boundary is `ScanInCC`, `ScanInDL`, `ScanInDR`, `TM` and
`ScanOutCC`. The shared analog boundary is `Iref`, `Vcc_read`, `Vcomp`,
`Bias_comp2`, `Vcc_wl_read`, `Vcc_wl_set`, `Vbias`, `Vcc_wl_reset`, `Vcc_set`,
`VCC_SNEAK` and `dc_bias`. These analog inouts are interface-only in the
digital behavioral model; their electrical effects are not simulated.

Signoff physical views have not been supplied. The released Wishbone macro is
`sky130_bmlabs_reram__cim32x32wb`; its 128-pin GDS, LEF and Liberty views have a
different interface and was not copied or relabeled as this selectable-interface
cell. The ten shared analog access geometries instead come from the released X1
`Neuromorphic_X1_wb.gds` reference.

## Available simulation views

- `verilog/vh/sky130_bmlabs_reram__cim32x32.vh`: LibreLane Verilog header;
- `verilog/behavioral/sky130_bmlabs_reram__cim32x32.sv`: behavioral model;
- `verilog/behavioral/sky130_bmlabs_reram__cim32x32_tb.sv`: supplied
  self-checking testbench.

## Provisional physical placeholders

Approximate GDS, LEF and Liberty files are provided to support early
floorplanning and file-flow testing. They use the released X2 boundary of
1910 x 2010.14 um, 274 non-power wires and the five reference-derived supply
pins.

- The GDS contains the macro boundary, synthetic bottom signal access, copied
  X1 analog and power access, and labels. It does not contain the real internal
  device or routing geometry.
- The LEF places all 258 ordinary digital signals and all five scan/test signals
  on vertical met2 tracks along the bottom boundary
  (`X = 0.23 + N*0.46 um`). The ten shared analog pins use the exact met3
  rectangles from the supplied `Neuromorphic_X1_wb.gds`; pins with multiple
  access rectangles preserve every reference shape. `VCC_SNEAK` has a separate
  provisional 1.30 um-wide met3 access because it is absent from the X1
  reference. The five supplies reuse that X1 GDS's distributed met3
  power-access geometry rather than a single synthetic strap per net. The
  source GDS and the checked-in `sky130_bmlabs_reram__nvm32x32wb.gds` have
  identical pin geometry; only the top structure is renamed. The matching
  released X1 LEF provides the reference
  obstruction pattern: full-macro obstructions on li1 through met3 and the
  internal met4 obstruction. This prevents the detailed router from crossing
  the macro on layers that may contain internal wiring. These shapes are not
  an electrical-sufficiency guarantee or approved signoff geometry; see
  `ANALOG_ROUTING.md` and `POWER_PINS.md` for integration requirements.
  The three scan/test pins that were previously on other sides are moved to
  free bottom tracks after the 258 ordinary digital pins.
- The Liberty file is an uncharacterized interface shell with no timing arcs
  and `dont_use : true`.

All three files are marked provisional. They must not be used for LVS, timing
signoff, fabrication or tapeout. Regenerate them deterministically with
`python3 scripts/generate_provisional_raw_views.py`.

The supplied X1 GDS is an abstract pin view: it has met2/met3 pin shapes,
labels and boundaries but no internal li1/met1/met4 routing geometry. It can
therefore provide the shared analog and distributed power-pin shapes, but it
cannot by itself generate the required internal routing obstructions. Those
are copied from the matching released X1 LEF and checked for exact agreement by
the validator.

## Required work before release

1. Provide the physical selectable-interface implementation and its approved power-pin
   specification.
2. Generate GDS and LEF from that implementation with approved pin placement.
3. Characterize a matching Liberty view rather than copying the Wishbone view.
4. Confirm that the module/cell name and every signal, test and supply pin match
   across all views.
5. Run timing checks, repository validation and chip-level DRC/LVS integration.

Until those checks pass, the physical placeholders are for early integration
only. Consumers that require a qualified physical macro must use the
`sky130_bmlabs_reram__cim32x32wb` release. The provisional files must be
replaced, not promoted, when extracted and characterized selectable-interface views
become available.
