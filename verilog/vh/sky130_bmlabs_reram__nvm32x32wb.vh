`timescale 1ns/1ps

module sky130_bmlabs_reram__nvm32x32wb (

`ifdef USE_POWER_PINS
  inout         VDDC1,            // 1.8 V digital supply; connect to vccd1
  inout         VDDC2,            // 1.8 V digital supply; connect to vccd2
  inout         VDDA1,            // 3.3 V analog supply; connect to vdda1
  inout         VDDA2,            // 3.3 V analog supply; connect to vdda2
  inout         VSS,              // common ground; connect to vssd1
`endif

  // Clocks and resets
  input         user_clk,
  input         user_rst,
  input         wb_clk_i,
  input         wb_rst_i,

  // Wishbone inputs
  input         wbs_stb_i,
  input         wbs_cyc_i,
  input         wbs_we_i,
  input  [3:0]  wbs_sel_i,
  input  [31:0] wbs_dat_i,
  input  [31:0] wbs_adr_i,

  // Wishbone outputs
  output [31:0] wbs_dat_o,
  output        wbs_ack_o,

  // Scan and test pins
  input         ScanInCC,
  input         ScanInDL,
  input         ScanInDR,
  input         TM,
  output        ScanOutCC,

  // Analog and programming pins
  inout         Iref,
  inout         Vcc_read,
  inout         Vcomp,
  inout         Bias_comp2,
  inout         Vcc_wl_read,
  inout         Vcc_wl_set,
  inout         Vbias,
  inout         Vcc_wl_reset,
  inout         Vcc_set,
  inout         dc_bias
);

endmodule
