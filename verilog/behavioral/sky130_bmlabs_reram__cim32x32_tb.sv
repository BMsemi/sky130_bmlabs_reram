`timescale 1ns/1ps

//------------------------------------------------------------------------------
// Self-checking testbench for sky130_bmlabs_reram__cim32x32
//
// This bench follows the supplied focused-testbench style:
//   * 10 MHz clock
//   * named, independently selectable testcases
//   * command/result handshakes instead of fixed command timing
//   * accumulated PASS/FAIL counters and a fatal exit on any failure
//
// Run all tests:
//   vvp simv
// Run one test:
//   vvp simv +CASE=<1..12>
// Optional interface monitor:
//   vvp simv +MONITOR
//------------------------------------------------------------------------------

module sky130_bmlabs_reram__cim32x32_tb;

  localparam logic [1:0] MODE_RESET   = 2'b00;
  localparam logic [1:0] MODE_READ    = 2'b01;
  localparam logic [1:0] MODE_COMPUTE = 2'b10;
  localparam logic [1:0] MODE_SET     = 2'b11;

  localparam integer READ_DELAY    = 160;
  localparam integer PROGRAM_DELAY = 360;
  localparam integer COMPUTE_DELAY = 450;
  localparam integer MAX_WAIT      = 2000;

  localparam logic [13:0] INITIAL_CELL_LEVEL = 14'h0E23;

  // Configuration values are derived from the three configuration words in
  // the supplied reference testbench.
  localparam logic [15:0] CFG_TARGET_SET1   = 16'h6472;
  localparam logic [15:0] CFG_TARGET_SET2   = 16'h0003;
  localparam logic [15:0] CFG_TARGET_RESET1 = 16'h000B;
  localparam logic [15:0] CFG_TARGET_RESET2 = 16'h462B;
  localparam logic [9:0]  CFG_CLK_CYCLES    = 10'd5;
  localparam logic [9:0]  CFG_COUNTER       = 10'd5;
  localparam logic [6:0]  CFG_TIMEOUT       = 7'd62;
  localparam logic [1:0]  CFG_DEAD_TIME     = 2'b10;

  logic clk_i;
  logic rst_i;

  logic        i_cmd_valid;
  wire         o_cmd_ready;
  logic [1:0]  i_mode;
  logic [4:0]  i_row_index;
  logic [4:0]  i_col_index;
  logic [7:0]  i_pwm_data;
  logic        i_compute_last;
  logic        i_compute_all_columns;

  logic [15:0] i_target_set1;
  logic [15:0] i_target_set2;
  logic [15:0] i_target_reset1;
  logic [15:0] i_target_reset2;
  logic [9:0]  i_no_of_clk_cycles;
  logic [9:0]  i_counter_value;
  logic [6:0]  i_tdc_time_out;
  logic [1:0]  i_tdc_dead_time;

  wire         o_busy;
  wire         o_command_accepted;
  wire         o_compute_pending;
  wire [2:0]   o_error;
  wire         o_error_valid;
  wire         o_operation_done;
  wire         o_program_readback_active;

  wire         o_result_valid;
  logic        i_result_ready;
  wire [20:0]  o_result_data;
  wire         o_result_last;

  logic        ScanInCC;
  logic        ScanInDL;
  logic        ScanInDR;
  logic        TM;
  wire         ScanOutCC;

  logic        Iref;
  logic        Vcc_read;
  logic        Vcomp;
  logic        Bias_comp2;
  logic        Vcc_wl_read;
  logic        Vcc_wl_set;
  logic        Vbias;
  logic        Vcc_wl_reset;
  logic        Vcc_set;
  logic        dc_bias;

  integer selected_case;
  integer total_tests;
  integer passed_tests;
  integer failed_tests;
  integer failed_checks;
  integer monitor_enabled;

  // 10 MHz clock, matching the supplied reference testbench.
  initial clk_i = 1'b0;
  always #50 clk_i = ~clk_i;

  sky130_bmlabs_reram__cim32x32 #(
    .READ_DELAY         (READ_DELAY),
    .PROGRAM_DELAY      (PROGRAM_DELAY),
    .COMPUTE_DELAY      (COMPUTE_DELAY),
    .INITIAL_CELL_LEVEL (INITIAL_CELL_LEVEL)
  ) dut (
    .clk_i                      (clk_i),
    .rst_i                      (rst_i),
    .i_cmd_valid                (i_cmd_valid),
    .o_cmd_ready                (o_cmd_ready),
    .i_mode                     (i_mode),
    .i_row_index                (i_row_index),
    .i_col_index                (i_col_index),
    .i_pwm_data                 (i_pwm_data),
    .i_compute_last             (i_compute_last),
    .i_compute_all_columns      (i_compute_all_columns),
    .i_target_set1              (i_target_set1),
    .i_target_set2              (i_target_set2),
    .i_target_reset1            (i_target_reset1),
    .i_target_reset2            (i_target_reset2),
    .i_no_of_clk_cycles         (i_no_of_clk_cycles),
    .i_counter_value            (i_counter_value),
    .i_tdc_time_out             (i_tdc_time_out),
    .i_tdc_dead_time            (i_tdc_dead_time),
    .o_busy                     (o_busy),
    .o_command_accepted         (o_command_accepted),
    .o_compute_pending          (o_compute_pending),
    .o_error                    (o_error),
    .o_error_valid              (o_error_valid),
    .o_operation_done           (o_operation_done),
    .o_program_readback_active  (o_program_readback_active),
    .o_result_valid             (o_result_valid),
    .i_result_ready             (i_result_ready),
    .o_result_data              (o_result_data),
    .o_result_last              (o_result_last),
    .ScanInCC                   (ScanInCC),
    .ScanInDL                   (ScanInDL),
    .ScanInDR                   (ScanInDR),
    .TM                         (TM),
    .ScanOutCC                  (ScanOutCC),
    .Iref                       (Iref),
    .Vcc_read                   (Vcc_read),
    .Vcomp                      (Vcomp),
    .Bias_comp2                 (Bias_comp2),
    .Vcc_wl_read                (Vcc_wl_read),
    .Vcc_wl_set                 (Vcc_wl_set),
    .Vbias                      (Vbias),
    .Vcc_wl_reset               (Vcc_wl_reset),
    .Vcc_set                    (Vcc_set),
    .dc_bias                    (dc_bias)
  );

  //============================================================================================
  // Common support
  //============================================================================================

  function automatic [13:0] expected_programmed_level;
    input logic        set_mode;
    input logic [7:0]  program_pwm;
    logic [16:0] target_sum;
    logic [13:0] target_midpoint;
    logic [14:0] level;
    begin
      if (set_mode)
        target_sum = {1'b0, CFG_TARGET_SET1} + {1'b0, CFG_TARGET_SET2};
      else
        target_sum = {1'b0, CFG_TARGET_RESET1} + {1'b0, CFG_TARGET_RESET2};

      target_midpoint = target_sum[14:1];
      level = {1'b0, target_midpoint} + {7'd0, program_pwm};
      expected_programmed_level = level[13:0];
    end
  endfunction

  task automatic drive_idle;
    begin
      i_cmd_valid           = 1'b0;
      i_mode                = MODE_RESET;
      i_row_index           = 5'd0;
      i_col_index           = 5'd0;
      i_pwm_data            = 8'd0;
      i_compute_last        = 1'b0;
      i_compute_all_columns = 1'b0;
      i_result_ready        = 1'b1;
      ScanInCC             = 1'b0;
      ScanInDL             = 1'b0;
      ScanInDR             = 1'b0;
      TM                   = 1'b0;
      Iref                 = 1'b0;
      Vcc_read             = 1'b0;
      Vcomp                = 1'b0;
      Bias_comp2           = 1'b0;
      Vcc_wl_read          = 1'b0;
      Vcc_wl_set           = 1'b0;
      Vbias                = 1'b0;
      Vcc_wl_reset         = 1'b0;
      Vcc_set              = 1'b0;
      dc_bias              = 1'b0;
    end
  endtask

  task automatic apply_reset;
    begin
      @(negedge clk_i);
      drive_idle();
      rst_i = 1'b1;
      repeat (4) @(posedge clk_i);
      @(negedge clk_i);
      rst_i = 1'b0;
      repeat (2) @(posedge clk_i);
      #1;
    end
  endtask

  task automatic check_condition;
    input logic  condition;
    input string description;
    begin
      if (condition !== 1'b1) begin
        failed_checks = failed_checks + 1;
        $error("CHECK FAILED: %s", description);
      end
    end
  endtask

  task automatic begin_test;
    input string test_name;
    output integer failure_mark;
    begin
      total_tests = total_tests + 1;
      failure_mark = failed_checks;
      $display("");
      $display("================================================================================");
      $display("TEST START: %s", test_name);
      $display("================================================================================");
    end
  endtask

  task automatic end_test;
    input string test_name;
    input integer failure_mark;
    begin
      check_condition(o_error_valid === 1'b0,
                      $sformatf("%s: no unexpected error_valid", test_name));
      check_condition(o_error === 3'b000,
                      $sformatf("%s: error status is STATUS_OK", test_name));

      if (failed_checks == failure_mark) begin
        passed_tests = passed_tests + 1;
        $display("TEST PASS: %s", test_name);
      end else begin
        failed_tests = failed_tests + 1;
        $display("TEST FAIL: %s", test_name);
      end
    end
  endtask

  task automatic wait_for_ready;
    integer cycles;
    begin
      cycles = 0;
      while ((o_cmd_ready !== 1'b1) && (cycles < MAX_WAIT)) begin
        @(negedge clk_i);
        cycles = cycles + 1;
      end
      check_condition(o_cmd_ready === 1'b1,
                      "command interface became ready before timeout");
    end
  endtask

  task automatic send_command;
    input logic [1:0] mode;
    input logic [4:0] row_index;
    input logic [4:0] col_index;
    input logic [7:0] pwm_data;
    input logic       compute_last;
    input logic       all_columns;
    begin
      wait_for_ready();
      @(negedge clk_i);
      i_mode                = mode;
      i_row_index           = row_index;
      i_col_index           = col_index;
      i_pwm_data            = pwm_data;
      i_compute_last        = compute_last;
      i_compute_all_columns = all_columns;
      i_cmd_valid           = 1'b1;

      @(posedge clk_i);
      #1;
      check_condition(o_command_accepted === 1'b1,
                      "command accepted pulse asserted");

      @(negedge clk_i);
      i_cmd_valid           = 1'b0;
      i_compute_last        = 1'b0;
      i_compute_all_columns = 1'b0;
    end
  endtask

  task automatic expect_result;
    input logic [1:0]  expected_mode;
    input logic [4:0]  expected_column;
    input logic [13:0] expected_count;
    input logic        expected_last;
    input logic        expected_program_readback;
    integer cycles;
    begin
      cycles = 0;
      while ((o_result_valid !== 1'b1) && (cycles < MAX_WAIT)) begin
        @(negedge clk_i);
        cycles = cycles + 1;
      end

      check_condition(o_result_valid === 1'b1,
                      "result became valid before timeout");
      if (o_result_valid === 1'b1) begin
        check_condition(o_result_data[20:19] === expected_mode,
                        $sformatf("result mode actual=%b expected=%b",
                                  o_result_data[20:19], expected_mode));
        check_condition(o_result_data[18:14] === expected_column,
                        $sformatf("result column actual=%0d expected=%0d",
                                  o_result_data[18:14], expected_column));
        check_condition(o_result_data[13:0] === expected_count,
                        $sformatf("result count actual=%0d expected=%0d",
                                  o_result_data[13:0], expected_count));
        check_condition(o_result_last === expected_last,
                        $sformatf("result last actual=%b expected=%b",
                                  o_result_last, expected_last));
        check_condition(o_busy === 1'b1,
                        "busy remains asserted while a result is valid");
        check_condition(o_program_readback_active === expected_program_readback,
                        "program readback status matches operation type");
      end

      @(posedge clk_i);
      #1;
    end
  endtask

  task automatic wait_for_idle;
    integer cycles;
    begin
      cycles = 0;
      while (((o_busy !== 1'b0) || (o_result_valid !== 1'b0)) &&
             (cycles < MAX_WAIT)) begin
        @(negedge clk_i);
        cycles = cycles + 1;
      end
      check_condition((o_busy === 1'b0) && (o_result_valid === 1'b0),
                      "interface returned to idle before timeout");
    end
  endtask

  //============================================================================================
  // Focused testcases
  //============================================================================================

  task automatic testcase_1_reset_and_idle;
    string test_name;
    integer failure_mark;
    begin
      test_name = "1. Reset and idle interface state";
      begin_test(test_name, failure_mark);
      apply_reset();
      check_condition(o_cmd_ready === 1'b1, "ready is high after reset");
      check_condition(o_busy === 1'b0, "busy is low after reset");
      check_condition(o_compute_pending === 1'b0,
                      "no partial COMPUTE transaction after reset");
      check_condition(o_result_valid === 1'b0, "no stale result after reset");
      check_condition(ScanOutCC === 1'b0, "scan output is low after reset");
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_2_single_read;
    string test_name;
    integer failure_mark;
    begin
      test_name = "2. Single READ command and exact result";
      begin_test(test_name, failure_mark);
      apply_reset();
      send_command(MODE_READ, 5'd2, 5'd3, 8'd10, 1'b0, 1'b0);
      expect_result(MODE_READ, 5'd3, INITIAL_CELL_LEVEL + 14'd10,
                    1'b1, 1'b0);
      wait_for_idle();
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_3_set_automatic_readback;
    string test_name;
    integer failure_mark;
    logic [13:0] expected_count;
    begin
      test_name = "3. SET command with automatic readback";
      begin_test(test_name, failure_mark);
      apply_reset();

      // A preceding READ establishes the separate previous-read PWM value.
      send_command(MODE_READ, 5'd0, 5'd0, 8'd4, 1'b0, 1'b0);
      expect_result(MODE_READ, 5'd0, INITIAL_CELL_LEVEL + 14'd4,
                    1'b1, 1'b0);
      wait_for_idle();

      expected_count = expected_programmed_level(1'b1, 8'd5) + 14'd4;
      send_command(MODE_SET, 5'd2, 5'd3, 8'd5, 1'b0, 1'b0);
      expect_result(MODE_SET, 5'd3, expected_count, 1'b1, 1'b1);
      wait_for_idle();
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_4_reset_automatic_readback;
    string test_name;
    integer failure_mark;
    logic [13:0] expected_count;
    begin
      test_name = "4. RESET/program-reset command with automatic readback";
      begin_test(test_name, failure_mark);
      apply_reset();

      send_command(MODE_READ, 5'd1, 5'd1, 8'd6, 1'b0, 1'b0);
      expect_result(MODE_READ, 5'd1, INITIAL_CELL_LEVEL + 14'd6,
                    1'b1, 1'b0);
      wait_for_idle();

      expected_count = expected_programmed_level(1'b0, 8'd9) + 14'd6;
      send_command(MODE_RESET, 5'd2, 5'd3, 8'd9, 1'b0, 1'b0);
      expect_result(MODE_RESET, 5'd3, expected_count, 1'b1, 1'b1);
      wait_for_idle();
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_5_single_row_compute;
    string test_name;
    integer failure_mark;
    begin
      test_name = "5. Program one cell and COMPUTE one row/column";
      begin_test(test_name, failure_mark);
      apply_reset();

      send_command(MODE_SET, 5'd4, 5'd5, 8'd1, 1'b0, 1'b0);
      expect_result(MODE_SET, 5'd5,
                    expected_programmed_level(1'b1, 8'd1), 1'b1, 1'b1);
      wait_for_idle();

      send_command(MODE_COMPUTE, 5'd4, 5'd5, 8'd7, 1'b1, 1'b0);
      expect_result(MODE_COMPUTE, 5'd5, 14'd7, 1'b1, 1'b0);
      wait_for_idle();
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_6_multirow_compute;
    string test_name;
    integer failure_mark;
    begin
      test_name = "6. Stream two COMPUTE rows into one column";
      begin_test(test_name, failure_mark);
      apply_reset();

      send_command(MODE_SET, 5'd4, 5'd7, 8'd1, 1'b0, 1'b0);
      expect_result(MODE_SET, 5'd7,
                    expected_programmed_level(1'b1, 8'd1), 1'b1, 1'b1);
      wait_for_idle();
      send_command(MODE_SET, 5'd6, 5'd7, 8'd2, 1'b0, 1'b0);
      expect_result(MODE_SET, 5'd7,
                    expected_programmed_level(1'b1, 8'd2), 1'b1, 1'b1);
      wait_for_idle();

      send_command(MODE_COMPUTE, 5'd4, 5'd7, 8'd3, 1'b0, 1'b0);
      check_condition(o_compute_pending === 1'b1,
                      "partial COMPUTE stream reports pending state");
      send_command(MODE_COMPUTE, 5'd6, 5'd7, 8'd9, 1'b1, 1'b0);
      expect_result(MODE_COMPUTE, 5'd7, 14'd12, 1'b1, 1'b0);
      wait_for_idle();
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_7_multicolumn_compute;
    string test_name;
    integer failure_mark;
    begin
      test_name = "7. COMPUTE result ordering across selected columns";
      begin_test(test_name, failure_mark);
      apply_reset();

      send_command(MODE_SET, 5'd4, 5'd3, 8'd1, 1'b0, 1'b0);
      expect_result(MODE_SET, 5'd3,
                    expected_programmed_level(1'b1, 8'd1), 1'b1, 1'b1);
      wait_for_idle();
      send_command(MODE_SET, 5'd7, 5'd5, 8'd1, 1'b0, 1'b0);
      expect_result(MODE_SET, 5'd5,
                    expected_programmed_level(1'b1, 8'd1), 1'b1, 1'b1);
      wait_for_idle();

      send_command(MODE_COMPUTE, 5'd4, 5'd3, 8'd4, 1'b0, 1'b0);
      send_command(MODE_COMPUTE, 5'd7, 5'd5, 8'd6, 1'b1, 1'b0);
      expect_result(MODE_COMPUTE, 5'd3, 14'd4, 1'b0, 1'b0);
      expect_result(MODE_COMPUTE, 5'd5, 14'd6, 1'b1, 1'b0);
      wait_for_idle();
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_8_full_column_compute;
    string test_name;
    integer failure_mark;
    integer column_index;
    logic [13:0] expected_count;
    begin
      test_name = "8. Full 32-column COMPUTE result stream";
      begin_test(test_name, failure_mark);
      apply_reset();

      send_command(MODE_SET, 5'd1, 5'd0, 8'd1, 1'b0, 1'b0);
      expect_result(MODE_SET, 5'd0,
                    expected_programmed_level(1'b1, 8'd1), 1'b1, 1'b1);
      wait_for_idle();
      send_command(MODE_SET, 5'd1, 5'd31, 8'd1, 1'b0, 1'b0);
      expect_result(MODE_SET, 5'd31,
                    expected_programmed_level(1'b1, 8'd1), 1'b1, 1'b1);
      wait_for_idle();

      send_command(MODE_COMPUTE, 5'd1, 5'd0, 8'd11, 1'b1, 1'b1);
      for (column_index = 0; column_index < 32;
           column_index = column_index + 1) begin
        if ((column_index == 0) || (column_index == 31))
          expected_count = 14'd11;
        else
          expected_count = 14'd0;

        expect_result(MODE_COMPUTE, column_index[4:0], expected_count,
                      column_index == 31, 1'b0);
      end
      wait_for_idle();
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_9_result_backpressure;
    string test_name;
    integer failure_mark;
    integer cycles;
    logic [20:0] held_data;
    logic held_last;
    begin
      test_name = "9. Result valid/data stability during consumer backpressure";
      begin_test(test_name, failure_mark);
      apply_reset();

      i_result_ready = 1'b0;
      send_command(MODE_READ, 5'd1, 5'd2, 8'd3, 1'b0, 1'b0);

      cycles = 0;
      while ((o_result_valid !== 1'b1) && (cycles < MAX_WAIT)) begin
        @(negedge clk_i);
        cycles = cycles + 1;
      end
      check_condition(o_result_valid === 1'b1,
                      "backpressured result became valid before timeout");

      held_data = o_result_data;
      held_last = o_result_last;
      check_condition(held_data === {MODE_READ, 5'd2,
                                     (INITIAL_CELL_LEVEL + 14'd3)},
                      "backpressured result has the expected value");
      check_condition(held_last === 1'b1,
                      "backpressured single result is marked last");

      repeat (5) begin
        @(posedge clk_i);
        #1;
        check_condition(o_result_valid === 1'b1,
                        "result_valid remains high during backpressure");
        check_condition(o_result_data === held_data,
                        "result_data remains stable during backpressure");
        check_condition(o_result_last === held_last,
                        "result_last remains stable during backpressure");
        check_condition(o_cmd_ready === 1'b0,
                        "new commands are blocked while a result is pending");
      end

      @(negedge clk_i);
      i_result_ready = 1'b1;
      wait_for_idle();
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_10_cancel_partial_compute;
    string test_name;
    integer failure_mark;
    begin
      test_name = "10. Non-COMPUTE command cancels a partial COMPUTE stream";
      begin_test(test_name, failure_mark);
      apply_reset();

      send_command(MODE_COMPUTE, 5'd2, 5'd4, 8'd6, 1'b0, 1'b0);
      check_condition(o_compute_pending === 1'b1,
                      "unfinished COMPUTE stream is reported as pending");
      check_condition(o_busy === 1'b1,
                      "pending COMPUTE stream contributes to busy status");

      send_command(MODE_READ, 5'd3, 5'd6, 8'd2, 1'b0, 1'b0);
      check_condition(o_compute_pending === 1'b0,
                      "READ command cancels the partial COMPUTE stream");
      expect_result(MODE_READ, 5'd6, INITIAL_CELL_LEVEL + 14'd2,
                    1'b1, 1'b0);
      wait_for_idle();

      repeat (10) @(posedge clk_i);
      check_condition(o_result_valid === 1'b0,
                      "cancelled COMPUTE stream creates no stale result");
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_11_scan_mode_blocking;
    string test_name;
    integer failure_mark;
    begin
      test_name = "11. Scan/test mode blocks functional commands";
      begin_test(test_name, failure_mark);
      apply_reset();

      @(negedge clk_i);
      TM         = 1'b1;
      ScanInCC   = 1'b1;
      ScanInDL   = 1'b1;
      repeat (3) @(posedge clk_i);
      #1;
      check_condition(ScanOutCC === ScanInCC,
                      "scan output follows the reference boundary behavior");
      check_condition(o_cmd_ready === 1'b0,
                      "functional command interface is blocked in test mode");

      @(negedge clk_i);
      TM         = 1'b0;
      ScanInCC   = 1'b0;
      ScanInDL   = 1'b0;
      repeat (2) @(posedge clk_i);
      #1;
      check_condition(ScanOutCC === 1'b0, "scan output clears with ScanInCC");
      check_condition(o_cmd_ready === 1'b1,
                      "functional command interface recovers after test mode");
      end_test(test_name, failure_mark);
    end
  endtask

  task automatic testcase_12_reset_during_operation;
    string test_name;
    integer failure_mark;
    begin
      test_name = "12. Reset aborts an active operation without a stale result";
      begin_test(test_name, failure_mark);
      apply_reset();

      send_command(MODE_READ, 5'd3, 5'd2, 8'd9, 1'b0, 1'b0);
      repeat (5) @(posedge clk_i);
      check_condition(o_busy === 1'b1, "READ operation is active before reset");

      apply_reset();
      check_condition(o_cmd_ready === 1'b1, "ready is restored after abort reset");
      check_condition(o_busy === 1'b0, "busy clears after abort reset");
      check_condition(o_compute_pending === 1'b0,
                      "compute accumulator clears after abort reset");
      check_condition(o_result_valid === 1'b0,
                      "no result is valid immediately after abort reset");

      repeat (READ_DELAY + 10) @(posedge clk_i);
      check_condition(o_result_valid === 1'b0,
                      "aborted operation does not create a delayed stale result");
      end_test(test_name, failure_mark);
    end
  endtask

  //============================================================================================
  // Optional raw-interface monitor
  //============================================================================================

  always @(posedge clk_i) begin
    if (monitor_enabled && o_command_accepted) begin
      $display("[%0t] CMD ACCEPT mode=%b row=%0d col=%0d pwm=%0d last=%b all=%b",
               $time, i_mode, i_row_index, i_col_index, i_pwm_data,
               i_compute_last, i_compute_all_columns);
    end

    if (monitor_enabled && o_result_valid && i_result_ready) begin
      $display("[%0t] RESULT mode=%b col=%0d count=%0d last=%b",
               $time, o_result_data[20:19], o_result_data[18:14],
               o_result_data[13:0], o_result_last);
    end
  end

  //============================================================================================
  // Test selection and final summary
  //============================================================================================

  initial begin
    rst_i = 1'b1;
    drive_idle();

    i_target_set1       = CFG_TARGET_SET1;
    i_target_set2       = CFG_TARGET_SET2;
    i_target_reset1     = CFG_TARGET_RESET1;
    i_target_reset2     = CFG_TARGET_RESET2;
    i_no_of_clk_cycles  = CFG_CLK_CYCLES;
    i_counter_value     = CFG_COUNTER;
    i_tdc_time_out      = CFG_TIMEOUT;
    i_tdc_dead_time     = CFG_DEAD_TIME;

    selected_case  = 0;
    total_tests    = 0;
    passed_tests   = 0;
    failed_tests   = 0;
    failed_checks  = 0;
    monitor_enabled = $test$plusargs("MONITOR");

    if ($value$plusargs("CASE=%d", selected_case))
      $display("Selected testcase from plusarg: CASE=%0d", selected_case);

    $display("");
    $display("================================================================================");
    $display("FOCUSED TESTS FOR THE RAW-SIGNAL BEHAVIORAL MODEL");
    $display("selected_case=%0d (0 means run all twelve)", selected_case);
    $display("================================================================================");

    if ((selected_case == 0) || (selected_case == 1))
      testcase_1_reset_and_idle();
    if ((selected_case == 0) || (selected_case == 2))
      testcase_2_single_read();
    if ((selected_case == 0) || (selected_case == 3))
      testcase_3_set_automatic_readback();
    if ((selected_case == 0) || (selected_case == 4))
      testcase_4_reset_automatic_readback();
    if ((selected_case == 0) || (selected_case == 5))
      testcase_5_single_row_compute();
    if ((selected_case == 0) || (selected_case == 6))
      testcase_6_multirow_compute();
    if ((selected_case == 0) || (selected_case == 7))
      testcase_7_multicolumn_compute();
    if ((selected_case == 0) || (selected_case == 8))
      testcase_8_full_column_compute();
    if ((selected_case == 0) || (selected_case == 9))
      testcase_9_result_backpressure();
    if ((selected_case == 0) || (selected_case == 10))
      testcase_10_cancel_partial_compute();
    if ((selected_case == 0) || (selected_case == 11))
      testcase_11_scan_mode_blocking();
    if ((selected_case == 0) || (selected_case == 12))
      testcase_12_reset_during_operation();

    $display("");
    $display("================================================================================");
    $display("FINAL SUMMARY: TOTAL=%0d PASS=%0d FAIL=%0d FAILED_CHECKS=%0d",
             total_tests, passed_tests, failed_tests, failed_checks);
    $display("================================================================================");

    if (total_tests == 0)
      $fatal(1, "Invalid selected_case=%0d. Use 0 through 12.", selected_case);
    else if ((failed_tests != 0) || (failed_checks != 0))
      $fatal(1, "One or more raw-interface tests failed");
    else
      $finish;
  end

  initial begin
    #20_000_000;
    $fatal(1, "Simulation watchdog timeout");
  end

endmodule

