# Changelog

## Unreleased

- Replaced the ten shared raw-X2 analog pin placeholders with the exact met3
  access rectangles from the released `Neuromorphic_X1_wb.gds` reference
  (stored locally as `sky130_bmlabs_reram__nvm32x32wb.gds`). The X2-only
  `VCC_SNEAK` pin retains its provisional met3 access.
- Moved all five scan/test pins to the bottom met2 boundary while preserving
  the existing 290 ordinary digital-pin rectangles.
- Expanded `sky130_bmlabs_reram__cim32x32` to a 311-pin selectable-interface
  boundary matching the complete behavioral module: direct/raw signals,
  `interface_sel`, `i_Levelsh_enable`, the 104-wire Wishbone interface and
  `stop_bit_i[31:0]`. All 290 ordinary digital signals are now placed on met2
  along the bottom boundary. The distributed power-access geometry remains
  unchanged.
- Added the raw-interface `VCC_SNEAK` analog inout consistently to the Verilog
  header, behavioral model, provisional GDS/LEF/Liberty views, manifest,
  documentation and validators. Its 1.30 um-wide met3 access uses the next free
  routing-grid-aligned analog slot without moving any existing pin.
- Clarified all four CIM command encodings and the synthesizable controller's
  SET-readback-RESET-readback sequence.
- Changed all ten analog pins to `inout` consistently in the Verilog header,
  behavioral model, LEF and Liberty views of both released Wishbone IPs.
- Replaced the raw macro's one-strap-per-net power geometry with the released
  X1 Wishbone GDS reference's 315 distributed met3 power-access shapes, and
  copied the matching X1 LEF's li1/met1/met2/met3/met4 obstruction pattern into
  the provisional raw LEF.
- Retained 1.30 um-wide met3 access for the raw-only `VCC_SNEAK` pin; the ten
  shared analog pins now use their released X1 reference rectangles.
- Documented that every analog bias pin connects to an analog pad or approved
  external source and requires a matching-or-wider NDR, including guidance for
  shared trunks when multiple macro instances are used.
- Moved the three LibreLane interface-only Verilog views into `verilog/vh/`
  and changed their extension from `.v` to `.vh`.
- Updated the raw-interface Verilog header and behavioral model with power pins
  first, section comments, aligned scan-pin ordering and bidirectional analog
  pins; removed header-only behavioral parameters and the obsolete missing-view
  comment.
- Regenerated the provisional raw-interface LEF and GDS so all ordinary digital
  and scan/test pins use bottom-boundary met2 tracks snapped to the SKY130 grid.
- Removed the behavioral-only `TM_o` output from
  `sky130_bmlabs_reram__cim32x32wb`; it is absent from the released physical
  and Verilog-header interfaces. The common scan/test interface retains `TM` and
  `ScanOutCC`.
- Added the supplied `sky130_bmlabs_reram__cim32x32` raw-interface behavioral
  model, self-checking testbench and matching integration shell.
- Added reproducible provisional GDS, LEF and Liberty placeholders using the
  released X2 boundary, synthetic digital pin placement, reference-derived
  analog and power access, and an
  uncharacterized `dont_use` Liberty shell. These views are explicitly limited
  to floorplanning and file-flow testing and are not signoff or tapeout views.
- Aligned the raw cell's external scan/test names and ten shared analog boundary
  pins with the released X2 Wishbone reference, plus the raw-only `VCC_SNEAK`
  analog pin. The resulting interface originally had 168 non-power wires; the
  selectable dual interface now has 306 non-power wires plus five
  reference-derived power pins. Qualified physical
  views remain gated because the released
  Wishbone GDS/LEF/Liberty has a different 128-pin interface and must not be
  copied or relabeled.
- Added the complete `sky130_bmlabs_reram__nvm32x32wb` X1 release: GDS, LEF,
  Liberty, Verilog header, behavioral model and self-checking testbench.
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
