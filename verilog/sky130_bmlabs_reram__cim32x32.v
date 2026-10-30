`timescale 1ns/1ps
`default_nettype none

// Raw-signal interface shell for compilation and integration checks.
// This file does not imply that matching GDS, LEF or Liberty views exist.
`celldefine
module sky130_bmlabs_reram__cim32x32 #(
  parameter integer      READ_DELAY         = 160,
  parameter integer      PROGRAM_DELAY      = 360,
  parameter integer      COMPUTE_DELAY      = 450,
  parameter [13:0]       INITIAL_CELL_LEVEL = 14'h0E23
)(
  input  wire         clk_i,
  input  wire         rst_i,

  input  wire         i_cmd_valid,
  output wire         o_cmd_ready,
  input  wire [1:0]   i_mode,
  input  wire [4:0]   i_row_index,
  input  wire [4:0]   i_col_index,
  input  wire [7:0]   i_pwm_data,
  input  wire         i_compute_last,
  input  wire         i_compute_all_columns,

  input  wire [15:0]  i_target_set1,
  input  wire [15:0]  i_target_set2,
  input  wire [15:0]  i_target_reset1,
  input  wire [15:0]  i_target_reset2,
  input  wire [9:0]   i_no_of_clk_cycles,
  input  wire [9:0]   i_counter_value,
  input  wire [6:0]   i_tdc_time_out,
  input  wire [1:0]   i_tdc_dead_time,

  output wire         o_busy,
  output wire         o_command_accepted,
  output wire         o_compute_pending,
  output wire [2:0]   o_error,
  output wire         o_error_valid,
  output wire         o_operation_done,
  output wire         o_program_readback_active,

  output wire         o_result_valid,
  input  wire         i_result_ready,
  output wire [20:0]  o_result_data,
  output wire         o_result_last,

  input  wire         ScanInCC,
  input  wire         ScanInDL,
  input  wire         ScanInDR,
  input  wire         TM,

  input  wire         Iref,
  input  wire         Vcc_read,
  input  wire         Vcomp,
  input  wire         Bias_comp2,
  input  wire         Vcc_wl_read,
  input  wire         Vcc_wl_set,
  input  wire         Vbias,
  input  wire         Vcc_wl_reset,
  input  wire         Vcc_set,
  input  wire         dc_bias,
`ifdef USE_POWER_PINS
  inout  wire         VDDC1,
  inout  wire         VDDC2,
  inout  wire         VDDA1,
  inout  wire         VDDA2,
  inout  wire         VSS,
`endif
  output wire         ScanOutCC
);
endmodule
`endcelldefine

`default_nettype wire
