`timescale 1ns/1ps

// Self-contained raw-signal behavioral model.
//
// The wide decoder, PWM, TDC-start, and analog-macro control signals remain
// inside this module.  The consumer sees a decoded command stream, static-capable
// configuration inputs, a result stream, and a small status interface.
//
// READ, SET, and RESET use one command beat.  COMPUTE uses one beat per row.
// The adapter accumulates COMPUTE rows, PWM values, and result columns until
// i_compute_last is accepted, then launches one operation in the raw core.

module sky130_bmlabs_reram__cim32x32 #(
  parameter integer      READ_DELAY         = 160,
  parameter integer      PROGRAM_DELAY      = 360,
  parameter integer      COMPUTE_DELAY      = 450,
  parameter logic [13:0] INITIAL_CELL_LEVEL = 14'h0E23
)(
`ifdef USE_POWER_PINS
  // Power pins.
  inout  wire         VDDC1,
  inout  wire         VDDC2,
  inout  wire         VDDA1,
  inout  wire         VDDA2,
  inout  wire         VSS,
`endif

  // Clock and reset.
  input  logic        clk_i,
  input  logic        rst_i,

  // Decoded command stream.
  input  logic        i_cmd_valid,
  output wire         o_cmd_ready,
  input  logic [1:0]  i_mode,
  input  logic [4:0]  i_row_index,
  input  logic [4:0]  i_col_index,
  input  logic [7:0]  i_pwm_data,
  input  logic        i_compute_last,
  input  logic        i_compute_all_columns,

  // Configuration may be tied to constants or control registers.
  // Keep these values stable while o_busy is high.
  input  logic [15:0] i_target_set1,
  input  logic [15:0] i_target_set2,
  input  logic [15:0] i_target_reset1,
  input  logic [15:0] i_target_reset2,
  input  logic [9:0]  i_no_of_clk_cycles,
  input  logic [9:0]  i_counter_value,
  input  logic [6:0]  i_tdc_time_out,
  input  logic [1:0]  i_tdc_dead_time,

  // Consumer-visible status.
  output wire         o_busy,
  output logic        o_command_accepted,
  output wire         o_compute_pending,
  output wire [2:0]   o_error,
  output wire         o_error_valid,
  output wire         o_operation_done,
  output wire         o_program_readback_active,

  // Result stream.  Data format is {mode[1:0], column[4:0], count[13:0]}.
  output wire         o_result_valid,
  input  logic        i_result_ready,
  output wire [20:0]  o_result_data,
  output wire         o_result_last,

  // Scan/test names match the released Wishbone macro.
  input  logic        ScanInCC,
  input  logic        ScanInDL,
  input  logic        ScanInDR,
  output wire         ScanOutCC,
  input  logic        TM,

  // Reference-derived analog boundary pins.  The functional model does not
  // model their electrical behavior.
  inout  wire         Iref,
  inout  wire         Vcc_read,
  inout  wire         Vcomp,
  inout  wire         Bias_comp2,
  inout  wire         Vcc_wl_read,
  inout  wire         Vcc_wl_set,
  inout  wire         Vbias,
  inout  wire         Vcc_wl_reset,
  inout  wire         Vcc_set,
  inout  wire         dc_bias
);

  localparam logic [1:0] MODE_RESET   = 2'b00;
  localparam logic [1:0] MODE_READ    = 2'b01;
  localparam logic [1:0] MODE_COMPUTE = 2'b10;

  integer row;

  logic        launch_pending;
  logic [1:0]  launch_mode;
  logic [31:0] launch_row_mask;
  logic [31:0] launch_col_mask;
  logic [7:0]  launch_pwm;
  logic [7:0]  launch_previous_pwm;
  logic [7:0]  launch_compute_pwm [0:31];
  logic        launch_full_row;

  logic [31:0] compute_row_mask;
  logic [31:0] compute_col_mask;
  logic [7:0]  compute_pwm [0:31];
  logic        compute_full_row;
  logic [7:0]  previous_read_pwm;

  wire         core_ready;
  wire         core_busy;
  wire         core_command_accepted;
  wire [2:0]   core_error;
  wire         core_error_valid;
  wire         core_read_done;
  wire         core_compute_done;
  wire         core_pgm_set_done;
  wire         core_pgm_reset_done;
  wire         core_pgm_set_read_mode;
  wire         core_pgm_reset_read_mode;
  wire         core_result_valid;
  wire [20:0]  core_result_data;
  wire         core_result_last;
  wire         core_tm_status;

  // Analog-side and detailed debug signals are intentionally internal.
  wire [1:0]   core_mux_sel;
  wire [31:0]  core_sl_float;
  wire [31:0]  core_sl_addr;
  wire [31:0]  core_sl_data;
  wire [31:0]  core_bl_addr;
  wire [31:0]  core_bl_data;
  wire [31:0]  core_bl_float;
  wire [31:0]  core_wl_float;
  wire [31:0]  core_wl_addr;
  wire [31:0]  core_wl_data;
  wire [31:0]  core_pwm_en;
  wire [7:0]   core_pwm_dac_outp [0:31];
  wire [31:0]  core_tdc_start;
  wire         core_tdc_valid;
  wire [20:0]  core_tdc_count;
  wire         core_fsm_start;
  wire         core_ramp;
  wire         core_precharge;
  wire         core_v_count;
  wire         core_hold;
  wire         core_start_phase;

  assign o_cmd_ready = core_ready && !launch_pending && !rst_i;
  assign o_compute_pending = (compute_row_mask != 32'b0);
  assign o_busy = core_busy || launch_pending || o_compute_pending;

  assign o_error       = core_error;
  assign o_error_valid = core_error_valid;
  assign o_operation_done = core_read_done || core_compute_done ||
                            core_pgm_set_done || core_pgm_reset_done;
  assign o_program_readback_active = core_pgm_set_read_mode ||
                                     core_pgm_reset_read_mode;

  assign o_result_valid = core_result_valid;
  assign o_result_data  = core_result_data;
  assign o_result_last  = core_result_last;

  // Match the released Wishbone behavioral boundary. ScanInDL drives the raw
  // serial input; ScanInCC is the active-high scan enable at this boundary.
  assign ScanOutCC = ScanInCC;
  wire unused_reference_boundary_inputs = ScanInDR ^ Iref ^ Vcc_read ^ Vcomp ^
      Bias_comp2 ^ Vcc_wl_read ^ Vcc_wl_set ^ Vbias ^ Vcc_wl_reset ^
      Vcc_set ^ dc_bias ^ core_tm_status;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      launch_pending        <= 1'b0;
      launch_mode           <= MODE_RESET;
      launch_row_mask       <= 32'b0;
      launch_col_mask       <= 32'b0;
      launch_pwm            <= 8'b0;
      launch_previous_pwm   <= 8'b0;
      launch_full_row       <= 1'b0;
      compute_row_mask      <= 32'b0;
      compute_col_mask      <= 32'b0;
      compute_full_row      <= 1'b0;
      previous_read_pwm     <= 8'b0;
      o_command_accepted    <= 1'b0;

      for (row = 0; row < 32; row = row + 1) begin
        launch_compute_pwm[row] <= 8'b0;
        compute_pwm[row]        <= 8'b0;
      end
    end else begin
      o_command_accepted <= 1'b0;

      if (launch_pending && core_command_accepted) begin
        launch_pending <= 1'b0;
        if (launch_mode == MODE_COMPUTE) begin
          compute_row_mask <= 32'b0;
          compute_col_mask <= 32'b0;
          compute_full_row <= 1'b0;
          for (row = 0; row < 32; row = row + 1)
            compute_pwm[row] <= 8'b0;
        end
      end

      if (i_cmd_valid && o_cmd_ready) begin
        o_command_accepted <= 1'b1;

        if (i_mode == MODE_COMPUTE) begin
          compute_row_mask[i_row_index] <= 1'b1;
          compute_col_mask[i_col_index] <= 1'b1;
          compute_pwm[i_row_index]      <= i_pwm_data;
          compute_full_row <= compute_full_row || i_compute_all_columns;

          if (i_compute_last) begin
            launch_mode         <= MODE_COMPUTE;
            launch_row_mask     <= compute_row_mask |
                                   (32'b1 << i_row_index);
            launch_col_mask     <= compute_col_mask |
                                   (32'b1 << i_col_index);
            launch_pwm          <= i_pwm_data;
            launch_previous_pwm <= previous_read_pwm;
            launch_full_row     <= compute_full_row ||
                                   i_compute_all_columns;
            launch_pending      <= 1'b1;

            for (row = 0; row < 32; row = row + 1) begin
              if (row == i_row_index)
                launch_compute_pwm[row] <= i_pwm_data;
              else
                launch_compute_pwm[row] <= compute_pwm[row];
            end
          end
        end else begin
          // A non-COMPUTE command cancels an unfinished COMPUTE stream.
          compute_row_mask <= 32'b0;
          compute_col_mask <= 32'b0;
          compute_full_row <= 1'b0;
          for (row = 0; row < 32; row = row + 1) begin
            compute_pwm[row]        <= 8'b0;
            launch_compute_pwm[row] <= 8'b0;
          end

          launch_mode         <= i_mode;
          launch_row_mask     <= (32'b1 << i_row_index);
          launch_col_mask     <= (32'b1 << i_col_index);
          launch_pwm          <= i_pwm_data;
          launch_previous_pwm <= previous_read_pwm;
          launch_full_row     <= 1'b0;
          launch_pending      <= 1'b1;

          if (i_mode == MODE_READ)
            previous_read_pwm <= i_pwm_data;
        end
      end
    end
  end

  sky130_bmlabs_reram__cim32x32_internal_core #(
    .READ_DELAY         (READ_DELAY),
    .PROGRAM_DELAY      (PROGRAM_DELAY),
    .COMPUTE_DELAY      (COMPUTE_DELAY),
    .INITIAL_CELL_LEVEL (INITIAL_CELL_LEVEL)
  ) u_raw_core (
    .clk_i                    (clk_i),
    .rst_i                    (rst_i),
    .i_start                  (launch_pending),
    .i_mode                   (launch_mode),
    .i_row_addr               (launch_row_mask),
    .i_col_addr               (launch_col_mask),
    .i_pwm_data               (launch_pwm),
    .i_previous_read_pwm      (launch_previous_pwm),
    .i_compute_pwm_by_row     (launch_compute_pwm),
    .i_read_full_row          (launch_full_row),
    .i_target_set1            (i_target_set1),
    .i_target_set2            (i_target_set2),
    .i_target_reset1          (i_target_reset1),
    .i_target_reset2          (i_target_reset2),
    .i_no_of_clk_cycles       (i_no_of_clk_cycles),
    .i_counter_value          (i_counter_value),
    .i_tdc_time_out           (i_tdc_time_out),
    .i_tdc_dead_time          (i_tdc_dead_time),
    .o_ready                  (core_ready),
    .o_busy                   (core_busy),
    .o_command_accepted       (core_command_accepted),
    .o_error                  (core_error),
    .o_error_valid            (core_error_valid),
    .o_read_done              (core_read_done),
    .o_compute_done           (core_compute_done),
    .o_pgm_set_done           (core_pgm_set_done),
    .o_pgm_reset_done         (core_pgm_reset_done),
    .o_pgm_set_read_mode      (core_pgm_set_read_mode),
    .o_pgm_reset_read_mode    (core_pgm_reset_read_mode),
    .o_result_valid           (core_result_valid),
    .i_result_ready           (i_result_ready),
    .o_result_data            (core_result_data),
    .o_result_last            (core_result_last),
    .o_result_mode            (),
    .o_result_column          (),
    .o_result_count           (),
    .i_stop_bit               (32'b0),
    .o_tdc_valid              (core_tdc_valid),
    .o_tdc_count              (core_tdc_count),
    .o_tdc_start              (core_tdc_start),
    .i_scan_si1               (ScanInDL),
    .i_scan_se1               (~ScanInCC),
    .i_TM                     (TM),
    .o_TM                     (core_tm_status),
    .o_mux_sel                (core_mux_sel),
    .o_sl_float               (core_sl_float),
    .o_sl_addr                (core_sl_addr),
    .o_sl_data                (core_sl_data),
    .o_bl_addr                (core_bl_addr),
    .o_bl_data                (core_bl_data),
    .o_bl_float               (core_bl_float),
    .o_wl_float               (core_wl_float),
    .o_wl_addr                (core_wl_addr),
    .o_wl_data                (core_wl_data),
    .o_pwm_en                 (core_pwm_en),
    .o_pwm_dac_outp           (core_pwm_dac_outp),
    .o_fsm_start              (core_fsm_start),
    .o_ramp                   (core_ramp),
    .o_precharge              (core_precharge),
    .o_v_count                (core_v_count),
    .o_hold                   (core_hold),
    .o_start                  (core_start_phase)
  );

endmodule

//------------------------------------------------------------------------------
// Private implementation module.
//
// Customer designs instantiate sky130_bmlabs_reram__cim32x32 only. This engine
// is included in the same source file so no second behavioral-model source
// file is required.
//------------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Direct/raw-interface behavioral model for the September 2026 V2 ReRAM IP.
//
// This module intentionally contains no Wishbone slave, address decoder,
// command FIFO, packet decoder, or configuration-write sequence. The consumer is
// expected to implement whichever bus/protocol it requires and to drive the
// decoded control fields below directly.
//
// Command handshake:
//   * Present all i_* command fields with i_start = 1.
//   * A command is accepted on a rising edge when i_start && o_ready.
//   * o_command_accepted pulses for one clock after acceptance.
//   * Hold/deassert i_start according to normal ready/valid rules.
//   * o_busy remains asserted through the operation and any result backpressure.
//
// Modes:
//       2'b00 = RESET/program-reset
//       2'b01 = READ
//       2'b10 = COMPUTE
//       2'b11 = SET/program-set
//
// Addressing:
//   * READ, SET, and RESET require one-hot i_row_addr and i_col_addr.
//   * COMPUTE accepts any nonzero row mask and column mask.
//   * i_read_full_row changes a COMPUTE result mask to all 32 columns.
//   * i_compute_pwm_by_row supplies one PWM value for every selected row.
//
// Result handshake:
//   * o_result_valid and o_result_data remain stable until i_result_ready = 1.
//   * o_result_last marks the last result of the accepted operation.
//   * o_result_data is the exact 21-bit cnt_top result format used by V2 RTL:
//         [20:19] operation mode
//         [18:14] column/channel
//         [13:0]  coarse/fine TDC count
//   * SET and RESET each return one automatic readback result.
//   * COMPUTE results are returned in ascending selected-column order.
//
// The decoder, PWM, scan, subtractor, and TDC-side observability signals are
// exposed so that a consumer can perform all protocol, queueing, and handshaking.
// The analog memory/TDC response is deterministic in this behavioral model.
// PVT, extracted parasitics, jitter, and metastability require the physical
// macro/extracted simulation and are intentionally not modeled here.
// -----------------------------------------------------------------------------

module sky130_bmlabs_reram__cim32x32_internal_core #(
  parameter integer      READ_DELAY         = 160,
  parameter integer      PROGRAM_DELAY      = 360,
  parameter integer      COMPUTE_DELAY      = 450,
  parameter logic [13:0] INITIAL_CELL_LEVEL = 14'h0E23
)(
  input  logic        clk_i,
  input  logic        rst_i,

  // Direct command interface.  These are the decoded signals that were
  // formerly generated inside Wb_slave.sv.
  input  logic        i_start,
  input  logic [1:0]  i_mode,
  input  logic [31:0] i_row_addr,
  input  logic [31:0] i_col_addr,
  input  logic [7:0]  i_pwm_data,
  input  logic [7:0]  i_previous_read_pwm,
  input  logic [7:0]  i_compute_pwm_by_row [0:31],
  input  logic        i_read_full_row,

  // Direct configuration interface.  Keep these stable while o_busy is high.
  input  logic [15:0] i_target_set1,
  input  logic [15:0] i_target_set2,
  input  logic [15:0] i_target_reset1,
  input  logic [15:0] i_target_reset2,
  input  logic [9:0]  i_no_of_clk_cycles,
  input  logic [9:0]  i_counter_value,
  input  logic [6:0]  i_tdc_time_out,
  input  logic [1:0]  i_tdc_dead_time,

  // Consumer-visible command and operation status.
  output wire         o_ready,
  output logic        o_busy,
  output logic        o_command_accepted,
  output logic [2:0]  o_error,
  output wire         o_error_valid,
  output logic        o_read_done,
  output logic        o_compute_done,
  output logic        o_pgm_set_done,
  output logic        o_pgm_reset_done,
  output logic        o_pgm_set_read_mode,
  output logic        o_pgm_reset_read_mode,

  // Direct result stream. The consumer may connect this to its own FIFO or bus.
  output logic        o_result_valid,
  input  logic        i_result_ready,
  output logic [20:0] o_result_data,
  output logic        o_result_last,
  output wire [1:0]   o_result_mode,
  output wire [4:0]   o_result_column,
  output wire [13:0]  o_result_count,

  // Raw TDC aliases and stop inputs retained at the low-level IP boundary.
  input  logic [31:0] i_stop_bit,
  output wire         o_tdc_valid,
  output wire [20:0]  o_tdc_count,
  output logic [31:0] o_tdc_start,

  // Scan/debug interface from the latest RTL.
  input  logic        i_scan_si1,
  input  logic        i_scan_se1,
  input  logic        i_TM,
  output wire         o_TM,

  // ReRAM macro / analog-side digital controls.
  output logic [1:0]  o_mux_sel,
  output logic [31:0] o_sl_float,
  output logic [31:0] o_sl_addr,
  output logic [31:0] o_sl_data,
  output logic [31:0] o_bl_addr,
  output logic [31:0] o_bl_data,
  output logic [31:0] o_bl_float,
  output logic [31:0] o_wl_float,
  output logic [31:0] o_wl_addr,
  output logic [31:0] o_wl_data,
  output logic [31:0] o_pwm_en,
  output logic [7:0]  o_pwm_dac_outp [0:31],

  // Subtractor/FSM phase observability.
  output wire         o_fsm_start,
  output logic        o_ramp,
  output logic        o_precharge,
  output logic        o_v_count,
  output logic        o_hold,
  output logic        o_start
);

  localparam logic [1:0] MODE_RESET   = 2'b00;
  localparam logic [1:0] MODE_READ    = 2'b01;
  localparam logic [1:0] MODE_COMPUTE = 2'b10;
  localparam logic [1:0] MODE_SET     = 2'b11;

  localparam logic [2:0] STATUS_OK              = 3'b000;
  localparam logic [2:0] STATUS_READ_TIMEOUT    = 3'b001;
  localparam logic [2:0] STATUS_SET_FAILED      = 3'b011;
  localparam logic [2:0] STATUS_COMPUTE_TIMEOUT = 3'b100;
  localparam logic [2:0] STATUS_RESET_FAILED    = 3'b101;

  integer row;
  integer col;
  integer scan_i;

  // Deterministic abstract 32x32 ReRAM state.
  logic [31:0] array_state [0:31];
  logic [13:0] cell_level  [0:1023];

  // Accepted-command registers. Inputs may change after acceptance.
  logic [1:0]  command_mode;
  logic [31:0] command_row_mask;
  logic [31:0] command_col_mask;
  logic [7:0]  command_pwm;
  logic [7:0]  command_previous_pwm;
  logic [7:0]  command_compute_pwm [0:31];
  logic        command_full_row;

  logic [15:0] cfg_target_set1;
  logic [15:0] cfg_target_set2;
  logic [15:0] cfg_target_reset1;
  logic [15:0] cfg_target_reset2;
  logic [9:0]  cfg_no_of_clk_cycles;
  logic [9:0]  cfg_counter_value;
  logic [6:0]  cfg_tdc_time_out;
  logic [1:0]  cfg_tdc_dead_time;

  // Active functional pins used by the decoder-control abstraction.
  logic        functional_active;
  logic [1:0]  functional_mode;
  logic [31:0] functional_row_mask;
  logic [31:0] functional_col_mask;

  // Scan/debug state follows the V2 top_module.sv/ScanDebug.v data format.
  logic [15:0] scan_shift;
  logic [15:0] scan_word;
  logic        scan_word_valid;
  logic        scan_in_progress;
  logic [4:0]  scan_bit_count;
  logic        scan_op_set;
  logic [4:0]  scan_sl_sel;
  logic [4:0]  scan_bl_sel;
  logic [4:0]  scan_wl_sel;
  logic        scan_op_set_d;
  logic [4:0]  scan_sl_sel_d;
  logic [4:0]  scan_bl_sel_d;
  logic [4:0]  scan_wl_sel_d;

  wire scan_test_mode;

  assign scan_test_mode = (i_TM === 1'b1);
  assign o_TM           = scan_test_mode;

  // A new command is accepted only after the preceding result has been
  // consumed.  This keeps the boundary FIFO-free and protocol-independent.
  assign o_ready       = !o_busy && !o_result_valid && !scan_test_mode;
  assign o_error_valid = (o_error != STATUS_OK);

  assign o_result_mode   = o_result_data[20:19];
  assign o_result_column = o_result_data[18:14];
  assign o_result_count  = o_result_data[13:0];

  assign o_tdc_valid = o_result_valid;
  assign o_tdc_count = o_result_data;
  assign o_fsm_start = o_command_accepted;

  function automatic [9:0] cell_index;
    input logic [4:0] row_index;
    input logic [4:0] col_index;
    begin
      cell_index = {row_index, col_index};
    end
  endfunction

  function automatic logic is_onehot32;
    input logic [31:0] value;
    begin
      is_onehot32 = (value != 32'b0) &&
                    ((value & (value - 32'd1)) == 32'b0);
    end
  endfunction

  function automatic [4:0] lowest_selected_index;
    input logic [31:0] value;
    integer index;
    logic found;
    begin
      lowest_selected_index = 5'd0;
      found = 1'b0;
      for (index = 0; index < 32; index = index + 1) begin
        if (value[index] && !found) begin
          lowest_selected_index = index[4:0];
          found = 1'b1;
        end
      end
    end
  endfunction

  function automatic [4:0] highest_selected_index;
    input logic [31:0] value;
    integer index;
    begin
      highest_selected_index = 5'd0;
      for (index = 0; index < 32; index = index + 1) begin
        if (value[index])
          highest_selected_index = index[4:0];
      end
    end
  endfunction

  function automatic [13:0] target_midpoint;
    input logic [15:0] target_a;
    input logic [15:0] target_b;
    logic [16:0] sum;
    begin
      sum = {1'b0, target_a} + {1'b0, target_b};
      target_midpoint = sum[14:1];
    end
  endfunction

  function automatic [13:0] programmed_level;
    input logic       set_cell;
    input logic [7:0] program_value;
    logic [14:0] value;
    begin
      if (set_cell)
        value = {1'b0, target_midpoint(cfg_target_set1, cfg_target_set2)} +
                {7'd0, program_value};
      else
        value = {1'b0, target_midpoint(cfg_target_reset1,
                                      cfg_target_reset2)} +
                {7'd0, program_value};

      programmed_level = value[13:0];
    end
  endfunction

  function automatic [13:0] timeout_ceiling;
    begin
      timeout_ceiling = {cfg_tdc_time_out[5:0], 8'hFF};
    end
  endfunction

  function automatic [13:0] clamp_count;
    input logic [16:0] raw_count;
    logic [13:0] ceiling;
    begin
      ceiling = timeout_ceiling();
      if (raw_count > {3'b0, ceiling})
        clamp_count = ceiling;
      else
        clamp_count = raw_count[13:0];
    end
  endfunction

  function automatic [13:0] read_cell_value;
    input logic [4:0] row_index;
    input logic [4:0] col_index;
    input logic [7:0] pwm_value;
    logic [16:0] raw_count;
    begin
      raw_count = {3'b0, cell_level[cell_index(row_index, col_index)]} +
                  {9'b0, pwm_value};
      read_cell_value = clamp_count(raw_count);
    end
  endfunction

  function automatic [20:0] make_result;
    input logic [1:0]  mode;
    input logic [4:0]  col_index;
    input logic [13:0] count;
    begin
      make_result = {mode, col_index, count};
    end
  endfunction

  task automatic clear_done_flags;
    begin
      o_read_done      = 1'b0;
      o_compute_done   = 1'b0;
      o_pgm_set_done   = 1'b0;
      o_pgm_reset_done = 1'b0;
    end
  endtask

  task automatic wait_cycles_or_reset;
    input integer cycles;
    integer cycle_count;
    begin
      cycle_count = 0;
      while ((cycle_count < cycles) && !rst_i) begin
        @(posedge clk_i or posedge rst_i);
        if (!rst_i)
          cycle_count = cycle_count + 1;
      end
    end
  endtask

  // Present a result until the consumer accepts it. Completion flags are cleared
  // after their one-cycle pulse, independently of result backpressure.
  task automatic emit_result;
    input logic [20:0] result_value;
    input logic        result_is_last;
    begin
      if (!rst_i) begin
        o_result_data  = result_value;
        o_result_last  = result_is_last;
        o_result_valid = 1'b1;

        @(posedge clk_i or posedge rst_i);
        clear_done_flags();

        while (!rst_i && (i_result_ready !== 1'b1))
          @(posedge clk_i or posedge rst_i);

        if (!rst_i) begin
          o_result_valid = 1'b0;
          o_result_last  = 1'b0;
        end
      end
    end
  endtask

  task automatic pulse_done_without_result;
    begin
      @(posedge clk_i or posedge rst_i);
      if (!rst_i)
        clear_done_flags();
    end
  endtask

  task automatic pulse_tdc_start;
    input logic [31:0] channel_mask;
    begin
      if (!rst_i) begin
        o_tdc_start = channel_mask;
        @(posedge clk_i or posedge rst_i);
        if (!rst_i)
          o_tdc_start = 32'b0;
      end
    end
  endtask

  task automatic capture_command;
    integer capture_row;
    begin
      command_mode         = i_mode;
      command_row_mask     = i_row_addr;
      command_col_mask     = i_col_addr;
      command_pwm          = i_pwm_data;
      command_previous_pwm = i_previous_read_pwm;
      command_full_row     = i_read_full_row;

      cfg_target_set1       = i_target_set1;
      cfg_target_set2       = i_target_set2;
      cfg_target_reset1     = i_target_reset1;
      cfg_target_reset2     = i_target_reset2;
      cfg_no_of_clk_cycles  = i_no_of_clk_cycles;
      cfg_counter_value     = i_counter_value;
      cfg_tdc_time_out      = i_tdc_time_out;
      cfg_tdc_dead_time     = i_tdc_dead_time;

      for (capture_row = 0; capture_row < 32;
           capture_row = capture_row + 1)
        command_compute_pwm[capture_row] =
            i_compute_pwm_by_row[capture_row];
    end
  endtask

  task automatic execute_read;
    logic [4:0] row_index;
    logic [4:0] col_index;
    begin
      if (!is_onehot32(command_row_mask) ||
          !is_onehot32(command_col_mask)) begin
        o_error     = STATUS_READ_TIMEOUT;
        o_read_done = 1'b1;
        pulse_done_without_result();
      end else begin
        row_index = lowest_selected_index(command_row_mask);
        col_index = lowest_selected_index(command_col_mask);

        wait_cycles_or_reset(READ_DELAY);
        if (!rst_i) begin
          pulse_tdc_start(command_col_mask);
          if (!rst_i) begin
            o_error     = STATUS_OK;
            o_read_done = 1'b1;
            emit_result(make_result(MODE_READ,
                                    col_index,
                                    read_cell_value(row_index,
                                                    col_index,
                                                    command_pwm)),
                        1'b1);
          end
        end
      end
    end
  endtask

  task automatic execute_program;
    input logic set_cell;
    logic [4:0] row_index;
    logic [4:0] col_index;
    logic [1:0] response_mode;
    integer program_wait;
    begin
      response_mode = set_cell ? MODE_SET : MODE_RESET;

      if (!is_onehot32(command_row_mask) ||
          !is_onehot32(command_col_mask)) begin
        o_error = set_cell ? STATUS_SET_FAILED : STATUS_RESET_FAILED;
        if (set_cell)
          o_pgm_set_done = 1'b1;
        else
          o_pgm_reset_done = 1'b1;
        pulse_done_without_result();
      end else begin
        row_index   = lowest_selected_index(command_row_mask);
        col_index   = lowest_selected_index(command_col_mask);
        program_wait = PROGRAM_DELAY + int'(cfg_no_of_clk_cycles);

        wait_cycles_or_reset(program_wait);
        if (!rst_i) begin
          array_state[row_index][col_index] = set_cell;
          cell_level[cell_index(row_index, col_index)] =
              programmed_level(set_cell, command_pwm);

          // V2 automatically changes to READ after SET/RESET.  The previous
          // READ PWM is a separate raw input, exactly as in Wb_slave.sv.
          if (set_cell)
            o_pgm_set_read_mode = 1'b1;
          else
            o_pgm_reset_read_mode = 1'b1;

          pulse_tdc_start(command_col_mask);
          if (!rst_i) begin
            o_error = STATUS_OK;
            if (set_cell)
              o_pgm_set_done = 1'b1;
            else
              o_pgm_reset_done = 1'b1;

            emit_result(make_result(response_mode,
                                    col_index,
                                    read_cell_value(row_index,
                                                    col_index,
                                                    command_previous_pwm)),
                        1'b1);

            o_pgm_set_read_mode   = 1'b0;
            o_pgm_reset_read_mode = 1'b0;
          end
        end
      end
    end
  endtask

  task automatic emit_compute_column;
    input logic [4:0] col_index;
    input logic       last_column;
    integer compute_row;
    logic [16:0] accumulated_value;
    begin
      accumulated_value = 17'b0;

      for (compute_row = 0; compute_row < 32;
           compute_row = compute_row + 1) begin
        if (command_row_mask[compute_row] &&
            array_state[compute_row][col_index])
          accumulated_value = accumulated_value +
                              {9'b0, command_compute_pwm[compute_row]};
      end

      emit_result(make_result(MODE_COMPUTE,
                              col_index,
                              clamp_count(accumulated_value)),
                  last_column);
    end
  endtask

  task automatic execute_compute;
    integer compute_col;
    logic [31:0] result_mask;
    logic [4:0] last_column;
    begin
      result_mask = command_full_row ? 32'hFFFF_FFFF : command_col_mask;

      if ((command_row_mask == 32'b0) || (result_mask == 32'b0)) begin
        o_error        = STATUS_COMPUTE_TIMEOUT;
        o_compute_done = 1'b1;
        pulse_done_without_result();
      end else begin
        functional_col_mask = result_mask;
        wait_cycles_or_reset(COMPUTE_DELAY);

        if (!rst_i) begin
          pulse_tdc_start(result_mask);
          if (!rst_i) begin
            o_error        = STATUS_OK;
            o_compute_done = 1'b1;
            last_column    = highest_selected_index(result_mask);

            for (compute_col = 0; compute_col < 32;
                 compute_col = compute_col + 1) begin
              if (result_mask[compute_col] && !rst_i) begin
                emit_compute_column(compute_col[4:0],
                                    compute_col[4:0] == last_column);

                if ((compute_col[4:0] != last_column) && !rst_i)
                  wait_cycles_or_reset(int'(cfg_tdc_dead_time));
              end
            end
          end
        end
      end
    end
  endtask

  task automatic reset_core_state;
    integer reset_row;
    integer reset_col;
    begin
      o_busy                  = 1'b0;
      o_command_accepted      = 1'b0;
      o_error                 = STATUS_OK;
      o_result_valid          = 1'b0;
      o_result_data           = 21'b0;
      o_result_last           = 1'b0;
      o_tdc_start             = 32'b0;
      o_pgm_set_read_mode     = 1'b0;
      o_pgm_reset_read_mode   = 1'b0;
      functional_active       = 1'b0;
      functional_mode         = MODE_RESET;
      functional_row_mask     = 32'b0;
      functional_col_mask     = 32'b0;
      command_mode            = MODE_RESET;
      command_row_mask        = 32'b0;
      command_col_mask        = 32'b0;
      command_pwm             = 8'b0;
      command_previous_pwm    = 8'b0;
      command_full_row        = 1'b0;
      cfg_target_set1         = 16'hC40F;
      cfg_target_set2         = 16'hA203;
      cfg_target_reset1       = 16'h0D43;
      cfg_target_reset2       = 16'h0F03;
      cfg_no_of_clk_cycles    = 10'd3;
      cfg_counter_value       = 10'd3;
      cfg_tdc_time_out        = 7'd32;
      cfg_tdc_dead_time       = 2'b01;
      clear_done_flags();

      for (reset_row = 0; reset_row < 32; reset_row = reset_row + 1) begin
        array_state[reset_row] = 32'b0;
        command_compute_pwm[reset_row] = 8'b0;
        for (reset_col = 0; reset_col < 32;
             reset_col = reset_col + 1)
          cell_level[cell_index(reset_row[4:0], reset_col[4:0])] =
              INITIAL_CELL_LEVEL;
      end
    end
  endtask

  // One-operation-at-a-time raw controller.  No bus or command FIFO is hidden
  // here; queueing and protocol conversion belong in the consuming design.
  initial begin
    reset_core_state();

    forever begin
      @(posedge clk_i or posedge rst_i);

      if (rst_i) begin
        reset_core_state();
      end else if (i_start && o_ready) begin
        capture_command();

        o_busy             = 1'b1;
        o_command_accepted = 1'b1;
        o_error            = STATUS_OK;
        clear_done_flags();

        functional_active   = 1'b1;
        functional_mode     = i_mode;
        functional_row_mask = i_row_addr;
        functional_col_mask =
            ((i_mode == MODE_COMPUTE) && i_read_full_row) ?
            32'hFFFF_FFFF : i_col_addr;

        // Keep command_accepted / fsm_start as a one-clock pulse.
        @(posedge clk_i or posedge rst_i);
        if (!rst_i) begin
          o_command_accepted = 1'b0;

          case (command_mode)
            MODE_READ:    execute_read();
            MODE_COMPUTE: execute_compute();
            MODE_SET:     execute_program(1'b1);
            MODE_RESET:   execute_program(1'b0);
            default: begin
              o_error = STATUS_READ_TIMEOUT;
            end
          endcase

          if (!rst_i) begin
            o_busy              = 1'b0;
            functional_active   = 1'b0;
            functional_row_mask = 32'b0;
            functional_col_mask = 32'b0;
            o_tdc_start          = 32'b0;
            o_pgm_set_read_mode  = 1'b0;
            o_pgm_reset_read_mode = 1'b0;
          end else begin
            reset_core_state();
          end
        end else begin
          reset_core_state();
        end
      end
    end
  end

  // Scan shift/capture behavior retained from the current V2 top-level flow.
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      scan_shift       <= 16'b0;
      scan_word        <= 16'b0;
      scan_word_valid  <= 1'b0;
      scan_in_progress <= 1'b0;
      scan_bit_count   <= 5'd0;
    end else begin
      scan_word_valid <= 1'b0;

      if ((i_scan_se1 === 1'b0) && !scan_test_mode) begin
        scan_in_progress <= 1'b0;
        scan_bit_count   <= 5'd0;
      end else if ((i_scan_se1 === 1'b0) && scan_test_mode) begin
        scan_shift <= {i_scan_si1, scan_shift[15:1]};

        if (!scan_in_progress) begin
          scan_in_progress <= 1'b1;
          scan_bit_count   <= 5'd0;
        end else begin
          scan_bit_count <= scan_bit_count + 5'd1;
        end

        if (scan_bit_count == 5'd16) begin
          scan_word        <= scan_shift;
          scan_word_valid  <= 1'b1;
          scan_in_progress <= 1'b0;
          scan_bit_count   <= 5'd0;
        end
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      scan_op_set   <= 1'b0;
      scan_sl_sel   <= 5'd0;
      scan_bl_sel   <= 5'd0;
      scan_wl_sel   <= 5'd0;
      scan_op_set_d <= 1'b0;
      scan_sl_sel_d <= 5'd0;
      scan_bl_sel_d <= 5'd0;
      scan_wl_sel_d <= 5'd0;
    end else begin
      if (scan_word_valid) begin
        scan_op_set <= scan_word[15];
        scan_sl_sel <= scan_word[14:10];
        scan_bl_sel <= scan_word[9:5];
        scan_wl_sel <= scan_word[4:0];
      end

      scan_op_set_d <= scan_op_set;
      scan_sl_sel_d <= scan_sl_sel;
      scan_bl_sel_d <= scan_bl_sel;
      scan_wl_sel_d <= scan_wl_sel;
    end
  end

  // Decoder, PWM, and analog-side control abstraction.  Scan mode overrides
  // all functional decoder outputs as it does in the latest RTL.
  always_comb begin
    o_wl_float = 32'hFFFF_FFFF;
    o_bl_float = 32'hFFFF_FFFF;
    o_sl_float = 32'hFFFF_FFFF;
    o_wl_data  = 32'b0;
    o_bl_data  = 32'b0;
    o_sl_data  = 32'b0;
    o_wl_addr  = 32'b0;
    o_bl_addr  = 32'b0;
    o_sl_addr  = 32'b0;
    o_mux_sel  = 2'b00;
    o_pwm_en   = 32'b0;

    o_ramp      = 1'b0;
    o_precharge = 1'b0;
    o_v_count   = 1'b1;
    o_hold      = 1'b0;
    o_start     = 1'b0;

    for (row = 0; row < 32; row = row + 1)
      o_pwm_dac_outp[row] = 8'b0;

    if (scan_test_mode) begin
      for (scan_i = 0; scan_i < 32; scan_i = scan_i + 1) begin
        o_wl_addr[scan_i]  = (scan_i == int'(scan_wl_sel_d));
        o_wl_float[scan_i] = ~o_wl_addr[scan_i];
        o_wl_data[scan_i]  = o_wl_addr[scan_i];

        o_bl_addr[scan_i]  = (scan_i == int'(scan_bl_sel_d));
        o_bl_float[scan_i] = ~o_bl_addr[scan_i];
        o_bl_data[scan_i]  =
            o_bl_addr[scan_i] ? scan_op_set_d : 1'b0;

        o_sl_addr[scan_i]  = (scan_i == int'(scan_sl_sel_d));
        o_sl_float[scan_i] = ~o_sl_addr[scan_i];
        o_sl_data[scan_i]  =
            o_sl_addr[scan_i] ? ~scan_op_set_d : 1'b0;
      end
    end else if (functional_active) begin
      o_wl_addr  = functional_row_mask;
      o_sl_addr  = functional_row_mask;
      o_bl_addr  = functional_col_mask;
      o_wl_float = ~functional_row_mask;
      o_sl_float = ~functional_row_mask;
      o_bl_float = ~functional_col_mask;
      o_pwm_en   = functional_row_mask;

      for (row = 0; row < 32; row = row + 1) begin
        if (functional_mode == MODE_COMPUTE)
          o_pwm_dac_outp[row] = command_compute_pwm[row];
        else
          o_pwm_dac_outp[row] = command_pwm;
      end

      case (functional_mode)
        MODE_READ,
        MODE_COMPUTE: begin
          o_mux_sel   = 2'b11;
          o_sl_data   = functional_row_mask;
          o_bl_data   = functional_col_mask;
          o_precharge = 1'b1;
          o_ramp      = !o_result_valid;
          o_hold      = o_result_valid;
          o_start     = |o_tdc_start;
          o_v_count   = ~(|o_tdc_start);
        end

        MODE_SET: begin
          o_mux_sel = 2'b01;
          o_wl_data = functional_row_mask;
          o_bl_data = functional_col_mask;
        end

        MODE_RESET: begin
          o_mux_sel = 2'b10;
          o_wl_data = functional_row_mask;
          o_sl_data = functional_row_mask;
        end

        default: begin
          o_mux_sel = 2'b00;
        end
      endcase
    end
  end

  // i_stop_bit is intentionally present at the raw physical boundary.  The
  // deterministic behavioral TDC does not derive delay from stop-edge timing;
  // that timing belongs to AMS or extracted post-layout verification.

endmodule


