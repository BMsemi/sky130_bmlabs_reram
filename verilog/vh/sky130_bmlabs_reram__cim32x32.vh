`timescale 1ns/1ps
`default_nettype none

// Raw-signal Verilog header for compilation and integration checks.
`celldefine
module sky130_bmlabs_reram__cim32x32 (
`ifdef USE_POWER_PINS
  // Power pins
  inout  wire         VDDC1,
  inout  wire         VDDC2,
  inout  wire         VDDA1,
  inout  wire         VDDA2,
  inout  wire         VSS,
`endif

  // Interface ownership and level-shifter control
  input  wire         interface_sel,
  input  wire         i_Levelsh_enable,

  // Clock and reset
  input  wire         clk_i,
  input  wire         rst_i,

  // Command interface
  input  wire         i_cmd_valid,
  output wire         o_cmd_ready,
  input  wire [1:0]   i_mode,
  input  wire [4:0]   i_row_index,
  input  wire [4:0]   i_col_index,
  input  wire [7:0]   i_pwm_data,
  input  wire         i_compute_last,
  input  wire         i_compute_all_columns,

  // Configuration inputs
  input  wire [15:0]  i_target_set1,
  input  wire [15:0]  i_target_set2,
  input  wire [15:0]  i_target_reset1,
  input  wire [15:0]  i_target_reset2,
  input  wire [9:0]   i_no_of_clk_cycles,
  input  wire [9:0]   i_counter_value,
  input  wire [6:0]   i_tdc_time_out,
  input  wire [1:0]   i_tdc_dead_time,

  // Status outputs
  output wire         o_busy,
  output wire         o_command_accepted,
  output wire         o_compute_pending,
  output wire [2:0]   o_error,
  output wire         o_error_valid,
  output wire         o_operation_done,
  output wire         o_program_readback_active,

  // Result interface
  output wire         o_result_valid,
  input  wire         i_result_ready,
  output wire [20:0]  o_result_data,
  output wire         o_result_last,

  // Wishbone packet interface; active when interface_sel is high
  input  wire         wbs_stb_i,
  input  wire         wbs_cyc_i,
  input  wire         wbs_we_i,
  input  wire [3:0]   wbs_sel_i,
  input  wire [31:0]  wbs_dat_i,
  input  wire [31:0]  wbs_adr_i,
  output wire [31:0]  wbs_dat_o,
  output wire         wbs_ack_o,

  // Physical TDC stop inputs
  input  wire [31:0]  stop_bit_i,

  // Scan and test pins
  input  wire         ScanInCC,
  input  wire         ScanInDL,
  input  wire         ScanInDR,
  output wire         ScanOutCC,
  input  wire         TM,

  // Analog-pad pins; route on met3 with a matching-or-wider 1.30 um NDR
  inout  wire         Iref,           // 100 uA current reference
  inout  wire         Vcc_read,       // 0.3 V read rail
  inout  wire         Vcomp,          // 0.6 V comparator/reference bias
  inout  wire         Bias_comp2,     // 0.6 V comparator bias
  inout  wire         Vcc_wl_read,    // 0.7 V wordline read rail
  inout  wire         Vcc_wl_set,     // 1.8 V wordline set rail
  inout  wire         Vbias,          // 1.8 V analog bias
  inout  wire         Vcc_wl_reset,   // 2.6 V wordline reset rail
  inout  wire         Vcc_set,        // 3.3 V array set rail
  inout  wire         VCC_SNEAK,      // external analog sneak-path supply/bias
  inout  wire         dc_bias         // externally driven; value is design-specific
);
endmodule
`endcelldefine

`default_nettype wire
