`timescale 1ns/1ps

// Behavioral-model adaptation of the supplied 17-scenario native-direct TB.
//
// The supplied TB instantiated top_module_wr and inspected Wishbone FIFO and
// internal TDC hierarchy.  This version uses only the public raw-interface
// contract of sky130_bmlabs_reram__cim32x32:
//   * command/result ready-valid handshakes;
//   * externally visible result data and status;
//   * no assumed Wishbone result FIFO;
//   * no assumed implementation hierarchy.
//
// Case 15 therefore checks raw-interface backpressure rather than queueing a
// second operation behind a full Wishbone FIFO.  Case 17 checks the externally
// visible COMPUTE completion/result and latency; fine/coarse analog stop timing
// is outside the abstraction provided by this digital behavioral model.

module sky130_bmlabs_reram__cim32x32_direct17_tb;

  localparam logic [1:0] MODE_RESET   = 2'b00;
  localparam logic [1:0] MODE_READ    = 2'b01;
  localparam logic [1:0] MODE_COMPUTE = 2'b10;
  localparam logic [1:0] MODE_SET     = 2'b11;

  localparam integer READ_DELAY    = 160;
  localparam integer PROGRAM_DELAY = 360;
  localparam integer COMPUTE_DELAY = 450;
  localparam integer MAX_WAIT      = 3000;

  localparam logic [13:0] INITIAL_CELL_LEVEL = 14'h0E23;
  localparam logic [15:0] CFG_TARGET_SET1   = 16'h6472;
  localparam logic [15:0] CFG_TARGET_SET2   = 16'h0003;
  localparam logic [15:0] CFG_TARGET_RESET1 = 16'h000B;
  localparam logic [15:0] CFG_TARGET_RESET2 = 16'h462B;
  localparam logic [9:0]  CFG_CLK_CYCLES    = 10'd5;
  localparam logic [9:0]  CFG_COUNTER       = 10'd5;
  localparam logic [6:0]  CFG_TIMEOUT       = 7'd62;
  localparam logic [1:0]  CFG_DEAD_TIME     = 2'd2;

  logic clk_i;
  logic rst_i;
  logic i_cmd_valid;
  wire  o_cmd_ready;
  logic [1:0] i_mode;
  logic [4:0] i_row_index;
  logic [4:0] i_col_index;
  logic [7:0] i_pwm_data;
  logic i_compute_last;
  logic i_compute_all_columns;

  logic [15:0] i_target_set1;
  logic [15:0] i_target_set2;
  logic [15:0] i_target_reset1;
  logic [15:0] i_target_reset2;
  logic [9:0]  i_no_of_clk_cycles;
  logic [9:0]  i_counter_value;
  logic [6:0]  i_tdc_time_out;
  logic [1:0]  i_tdc_dead_time;

  wire o_busy;
  wire o_command_accepted;
  wire o_compute_pending;
  wire [2:0] o_error;
  wire o_error_valid;
  wire o_operation_done;
  wire o_program_readback_active;
  wire o_result_valid;
  logic i_result_ready;
  wire [20:0] o_result_data;
  wire o_result_last;

  logic ScanInCC;
  logic ScanInDL;
  logic ScanInDR;
  logic TM;
  wire ScanOutCC;

  tri Iref = 1'b0;
  tri Vcc_read = 1'b0;
  tri Vcomp = 1'b0;
  tri Bias_comp2 = 1'b0;
  tri Vcc_wl_read = 1'b0;
  tri Vcc_wl_set = 1'b0;
  tri Vbias = 1'b0;
  tri Vcc_wl_reset = 1'b0;
  tri Vcc_set = 1'b0;
  tri dc_bias = 1'b0;

  integer selected_case;
  integer total_tests;
  integer passed_tests;
  integer failed_tests;
  integer failed_checks;
  integer accepted_commands;
  integer consumed_results;
  integer monitor_enabled;

  logic expected_state [0:31][0:31];
  logic [13:0] expected_level [0:31][0:31];
  logic [31:0] expected_compute_rows;
  logic [31:0] expected_compute_columns;
  logic [7:0] expected_compute_pwm [0:31];
  logic expected_compute_all_columns;
  logic [7:0] expected_previous_read_pwm;

  initial clk_i = 1'b0;
  always #50 clk_i = ~clk_i;

  sky130_bmlabs_reram__cim32x32 #(
    .READ_DELAY(READ_DELAY),
    .PROGRAM_DELAY(PROGRAM_DELAY),
    .COMPUTE_DELAY(COMPUTE_DELAY),
    .INITIAL_CELL_LEVEL(INITIAL_CELL_LEVEL)
  ) dut (
    .interface_sel(1'b0),
    .i_Levelsh_enable(1'b1),
    .clk_i(clk_i),
    .rst_i(rst_i),
    .i_cmd_valid(i_cmd_valid),
    .o_cmd_ready(o_cmd_ready),
    .i_mode(i_mode),
    .i_row_index(i_row_index),
    .i_col_index(i_col_index),
    .i_pwm_data(i_pwm_data),
    .i_compute_last(i_compute_last),
    .i_compute_all_columns(i_compute_all_columns),
    .i_target_set1(i_target_set1),
    .i_target_set2(i_target_set2),
    .i_target_reset1(i_target_reset1),
    .i_target_reset2(i_target_reset2),
    .i_no_of_clk_cycles(i_no_of_clk_cycles),
    .i_counter_value(i_counter_value),
    .i_tdc_time_out(i_tdc_time_out),
    .i_tdc_dead_time(i_tdc_dead_time),
    .o_busy(o_busy),
    .o_command_accepted(o_command_accepted),
    .o_compute_pending(o_compute_pending),
    .o_error(o_error),
    .o_error_valid(o_error_valid),
    .o_operation_done(o_operation_done),
    .o_program_readback_active(o_program_readback_active),
    .o_result_valid(o_result_valid),
    .i_result_ready(i_result_ready),
    .o_result_data(o_result_data),
    .o_result_last(o_result_last),
    .wbs_stb_i(1'b0),
    .wbs_cyc_i(1'b0),
    .wbs_we_i(1'b0),
    .wbs_sel_i(4'b0),
    .wbs_dat_i(32'b0),
    .wbs_adr_i(32'b0),
    .wbs_dat_o(),
    .wbs_ack_o(),
    .stop_bit_i(32'b0),
    .ScanInCC(ScanInCC),
    .ScanInDL(ScanInDL),
    .ScanInDR(ScanInDR),
    .ScanOutCC(ScanOutCC),
    .TM(TM),
    .Iref(Iref),
    .Vcc_read(Vcc_read),
    .Vcomp(Vcomp),
    .Bias_comp2(Bias_comp2),
    .Vcc_wl_read(Vcc_wl_read),
    .Vcc_wl_set(Vcc_wl_set),
    .Vbias(Vbias),
    .Vcc_wl_reset(Vcc_wl_reset),
    .Vcc_set(Vcc_set),
    .VCC_SNEAK(),
    .dc_bias(dc_bias)
  );

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
    input logic set_mode;
    input logic [7:0] pwm;
    logic [14:0] value;
    begin
      if (set_mode)
        value = {1'b0, target_midpoint(CFG_TARGET_SET1, CFG_TARGET_SET2)} +
                {7'd0, pwm};
      else
        value = {1'b0, target_midpoint(CFG_TARGET_RESET1, CFG_TARGET_RESET2)} +
                {7'd0, pwm};
      programmed_level = value[13:0];
    end
  endfunction

  function automatic [13:0] clamp_count;
    input logic [16:0] raw_count;
    logic [13:0] ceiling;
    begin
      ceiling = {CFG_TIMEOUT[5:0], 8'hFF};
      if (raw_count > {3'b0, ceiling})
        clamp_count = ceiling;
      else
        clamp_count = raw_count[13:0];
    end
  endfunction

  function automatic [4:0] highest_column;
    input logic [31:0] mask;
    integer column;
    begin
      highest_column = 5'd0;
      for (column = 0; column < 32; column = column + 1)
        if (mask[column])
          highest_column = column[4:0];
    end
  endfunction

  task automatic check_condition;
    input logic condition;
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

  task automatic clear_compute_scoreboard;
    integer row;
    begin
      expected_compute_rows = 32'b0;
      expected_compute_columns = 32'b0;
      expected_compute_all_columns = 1'b0;
      for (row = 0; row < 32; row = row + 1)
        expected_compute_pwm[row] = 8'b0;
    end
  endtask

  task automatic reset_scoreboard;
    integer row;
    integer column;
    begin
      expected_previous_read_pwm = 8'b0;
      clear_compute_scoreboard();
      for (row = 0; row < 32; row = row + 1) begin
        for (column = 0; column < 32; column = column + 1) begin
          expected_state[row][column] = 1'b0;
          expected_level[row][column] = INITIAL_CELL_LEVEL;
        end
      end
    end
  endtask

  task automatic drive_idle;
    begin
      i_cmd_valid = 1'b0;
      i_mode = MODE_RESET;
      i_row_index = 5'd0;
      i_col_index = 5'd0;
      i_pwm_data = 8'd0;
      i_compute_last = 1'b0;
      i_compute_all_columns = 1'b0;
      i_result_ready = 1'b1;
      ScanInCC = 1'b0;
      ScanInDL = 1'b0;
      ScanInDR = 1'b0;
      TM = 1'b0;
    end
  endtask

  task automatic apply_reset;
    begin
      @(negedge clk_i);
      drive_idle();
      rst_i = 1'b1;
      reset_scoreboard();
      repeat (4) @(posedge clk_i);
      @(negedge clk_i);
      rst_i = 1'b0;
      repeat (2) @(posedge clk_i);
      #1;
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
    input logic [7:0] pwm;
    input logic all_columns;
    input logic compute_last;
    begin
      wait_for_ready();
      @(negedge clk_i);
      i_mode = mode;
      i_row_index = row_index;
      i_col_index = col_index;
      i_pwm_data = pwm;
      i_compute_all_columns = all_columns;
      i_compute_last = compute_last;
      i_cmd_valid = 1'b1;
      @(posedge clk_i);
      #1;
      check_condition(o_command_accepted === 1'b1,
                      "valid/ready transfer pulses command_accepted");
      if (o_command_accepted === 1'b1)
        accepted_commands = accepted_commands + 1;
      @(negedge clk_i);
      i_cmd_valid = 1'b0;
      i_compute_all_columns = 1'b0;
      i_compute_last = 1'b0;
    end
  endtask

  task automatic expect_result;
    input logic [1:0] expected_mode;
    input logic [4:0] expected_column;
    input logic [13:0] expected_count;
    input logic expected_last;
    input logic expected_program_readback;
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
                        "result last marker matches expected ordering");
        check_condition(o_program_readback_active === expected_program_readback,
                        "program-readback status matches operation type");
        check_condition(o_busy === 1'b1,
                        "busy remains asserted while result is presented");
        consumed_results = consumed_results + 1;
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

  task automatic expect_no_result;
    input integer cycles;
    input string description;
    integer index;
    begin
      for (index = 0; index < cycles; index = index + 1) begin
        @(posedge clk_i);
        #1;
        check_condition(o_result_valid === 1'b0, description);
      end
    end
  endtask

  task automatic do_read;
    input integer row;
    input integer column;
    input logic [7:0] pwm;
    logic [16:0] raw_count;
    begin
      raw_count = {3'b0, expected_level[row][column]} + {9'b0, pwm};
      send_command(MODE_READ, row[4:0], column[4:0], pwm, 1'b0, 1'b0);
      expect_result(MODE_READ, column[4:0], clamp_count(raw_count), 1'b1, 1'b0);
      expected_previous_read_pwm = pwm;
      wait_for_idle();
    end
  endtask

  task automatic do_program;
    input logic set_mode;
    input integer row;
    input integer column;
    input logic [7:0] pwm;
    logic [13:0] new_level;
    logic [16:0] raw_count;
    begin
      new_level = programmed_level(set_mode, pwm);
      raw_count = {3'b0, new_level} + {9'b0, expected_previous_read_pwm};
      send_command(set_mode ? MODE_SET : MODE_RESET,
                   row[4:0], column[4:0], pwm, 1'b0, 1'b0);
      expect_result(set_mode ? MODE_SET : MODE_RESET,
                    column[4:0], clamp_count(raw_count), 1'b1, 1'b1);
      expected_state[row][column] = set_mode;
      expected_level[row][column] = new_level;
      wait_for_idle();
    end
  endtask

  task automatic send_compute;
    input integer row;
    input integer column;
    input logic [7:0] pwm;
    input logic all_columns;
    input logic compute_last;
    begin
      send_command(MODE_COMPUTE, row[4:0], column[4:0], pwm,
                   all_columns, compute_last);
      expected_compute_rows[row] = 1'b1;
      expected_compute_columns[column] = 1'b1;
      expected_compute_pwm[row] = pwm;
      expected_compute_all_columns = expected_compute_all_columns || all_columns;
      if (!compute_last)
        check_condition(o_compute_pending === 1'b1,
                        "unfinished COMPUTE stream remains pending");
    end
  endtask

  task automatic expect_compute_results;
    logic [31:0] result_mask;
    logic [4:0] last_column;
    logic [16:0] accumulated;
    integer row;
    integer column;
    begin
      result_mask = expected_compute_all_columns ? 32'hFFFF_FFFF :
                                                  expected_compute_columns;
      last_column = highest_column(result_mask);
      for (column = 0; column < 32; column = column + 1) begin
        if (result_mask[column]) begin
          accumulated = 17'b0;
          for (row = 0; row < 32; row = row + 1) begin
            if (expected_compute_rows[row] && expected_state[row][column])
              accumulated = accumulated + {9'b0, expected_compute_pwm[row]};
          end
          expect_result(MODE_COMPUTE, column[4:0], clamp_count(accumulated),
                        column[4:0] == last_column, 1'b0);
        end
      end
      wait_for_idle();
      clear_compute_scoreboard();
    end
  endtask

  task automatic case_1;
    string name;
    integer mark;
    begin
      name = "CASE 1 - configuration applied on direct program command";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 2, 4, 8'h03);
      check_condition(expected_level[2][4] === programmed_level(1'b1, 8'h03),
                      "configured SET targets determine exact readback level");
      end_test(name, mark);
    end
  endtask

  task automatic case_2;
    string name;
    integer mark;
    begin
      name = "CASE 2 - configuration only produces no result";
      begin_test(name, mark);
      apply_reset();
      expect_no_result(10, "configuration-only idle state has no result");
      check_condition(o_cmd_ready === 1'b1, "interface remains ready");
      end_test(name, mark);
    end
  endtask

  task automatic case_3;
    string name;
    integer mark;
    begin
      name = "CASE 3 - reset leaves no stale result";
      begin_test(name, mark);
      apply_reset();
      expect_no_result(10, "reset produces no stale result");
      check_condition(o_busy === 1'b0, "reset leaves interface idle");
      end_test(name, mark);
    end
  endtask

  task automatic case_4;
    string name;
    integer mark;
    begin
      name = "CASE 4 - SET readback followed by RESET readback";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 2, 4, 8'h03);
      do_program(1'b0, 2, 4, 8'h09);
      check_condition(expected_state[2][4] === 1'b0,
                      "RESET clears programmed cell state");
      end_test(name, mark);
    end
  endtask

  task automatic case_5;
    string name;
    integer mark;
    integer row;
    begin
      name = "CASE 5 - six COMPUTEs without compute_last remain pending";
      begin_test(name, mark);
      apply_reset();
      for (row = 0; row < 6; row = row + 1)
        send_compute(row, row + 2, 8'h10 + row, row == 5, 1'b0);
      expect_no_result(200, "all_columns without compute_last produces no result");
      check_condition(o_compute_pending === 1'b1,
                      "six packets remain accumulated pending compute_last");
      check_condition(o_busy === 1'b1,
                      "pending raw COMPUTE contributes to busy status");
      apply_reset();
      end_test(name, mark);
    end
  endtask

  task automatic case_6;
    string name;
    integer mark;
    begin
      name = "CASE 6 - two-packet full-column COMPUTE";
      begin_test(name, mark);
      apply_reset();
      send_compute(1, 2, 8'h11, 1'b0, 1'b0);
      send_compute(2, 5, 8'h22, 1'b1, 1'b1);
      expect_compute_results();
      end_test(name, mark);
    end
  endtask

  task automatic case_7;
    string name;
    integer mark;
    begin
      name = "CASE 7 - SET/RESET automatic readbacks then idle";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 2, 4, 8'h03);
      do_program(1'b0, 2, 4, 8'h09);
      expect_no_result(10, "no duplicate program readback remains");
      end_test(name, mark);
    end
  endtask

  task automatic case_8;
    string name;
    integer mark;
    begin
      name = "CASE 8 - exactly one result per SET and RESET";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 2, 4, 8'h03);
      expect_no_result(3, "SET creates exactly one result");
      do_program(1'b0, 2, 4, 8'h09);
      expect_no_result(3, "RESET creates exactly one result");
      end_test(name, mark);
    end
  endtask

  task automatic case_9;
    string name;
    integer mark;
    integer result_mark;
    begin
      name = "CASE 9 - isolated automatic SET and RESET readbacks";
      begin_test(name, mark);
      apply_reset();
      result_mark = consumed_results;
      do_program(1'b1, 2, 4, 8'h03);
      check_condition(consumed_results == result_mark + 1,
                      "SET produces exactly one consumed result");
      result_mark = consumed_results;
      do_program(1'b0, 3, 6, 8'h09);
      check_condition(consumed_results == result_mark + 1,
                      "RESET produces exactly one consumed result");
      end_test(name, mark);
    end
  endtask

  task automatic case_10;
    string name;
    integer mark;
    integer packet;
    begin
      name = "CASE 10 - six COMPUTE rows on selected column 7";
      begin_test(name, mark);
      apply_reset();
      for (packet = 0; packet < 6; packet = packet + 1)
        send_compute(packet, 7, 8'h21 + packet, 1'b0, packet == 5);
      expect_compute_results();
      end_test(name, mark);
    end
  endtask

  task automatic case_11;
    string name;
    integer mark;
    begin
      name = "CASE 11 - four COMPUTE rows and selected columns";
      begin_test(name, mark);
      apply_reset();
      send_compute(2, 3, 8'h31, 1'b0, 1'b0);
      send_compute(4, 9, 8'h32, 1'b0, 1'b0);
      send_compute(6, 14, 8'h33, 1'b0, 1'b0);
      send_compute(8, 21, 8'h34, 1'b0, 1'b1);
      expect_compute_results();
      end_test(name, mark);
    end
  endtask

  task automatic case_12;
    string name;
    integer mark;
    begin
      name = "CASE 12 - three-packet full-column COMPUTE";
      begin_test(name, mark);
      apply_reset();
      send_compute(1, 2, 8'h41, 1'b0, 1'b0);
      send_compute(10, 11, 8'h42, 1'b0, 1'b0);
      send_compute(20, 23, 8'h43, 1'b1, 1'b1);
      expect_compute_results();
      end_test(name, mark);
    end
  endtask

  task automatic case_13;
    string name;
    integer mark;
    begin
      name = "CASE 13 - program cells then selected-column COMPUTE";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 1, 3, 8'h51);
      do_program(1'b1, 6, 11, 8'h52);
      do_program(1'b1, 12, 20, 8'h53);
      do_program(1'b0, 1, 3, 8'h61);
      do_program(1'b0, 6, 11, 8'h62);
      do_program(1'b0, 15, 25, 8'h63);
      send_compute(0, 2, 8'h71, 1'b0, 1'b0);
      send_compute(4, 5, 8'h72, 1'b0, 1'b0);
      send_compute(8, 9, 8'h73, 1'b0, 1'b0);
      send_compute(12, 14, 8'h74, 1'b0, 1'b0);
      send_compute(16, 23, 8'h75, 1'b0, 1'b1);
      expect_compute_results();
      end_test(name, mark);
    end
  endtask

  task automatic case_14;
    string name;
    integer mark;
    begin
      name = "CASE 14 - mixed programming then full-column COMPUTE";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 2, 4, 8'h81);
      do_program(1'b1, 7, 12, 8'h82);
      do_program(1'b0, 2, 4, 8'h91);
      do_program(1'b0, 10, 18, 8'h92);
      send_compute(1, 3, 8'hA1, 1'b0, 1'b0);
      send_compute(9, 13, 8'hA2, 1'b0, 1'b0);
      send_compute(17, 27, 8'hA3, 1'b1, 1'b1);
      expect_compute_results();
      end_test(name, mark);
    end
  endtask

  task automatic case_15;
    string name;
    integer mark;
    integer cycles;
    logic [20:0] held_data;
    logic held_last;
    begin
      name = "CASE 15 - two full-column COMPUTEs with raw backpressure";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 1, 2, 8'hB1);
      do_program(1'b1, 4, 7, 8'hB2);
      do_program(1'b1, 9, 15, 8'hB3);

      i_result_ready = 1'b0;
      send_compute(0, 3, 8'hC1, 1'b0, 1'b0);
      send_compute(8, 13, 8'hC2, 1'b0, 1'b0);
      send_compute(16, 23, 8'hC3, 1'b1, 1'b1);
      cycles = 0;
      while ((o_result_valid !== 1'b1) && (cycles < MAX_WAIT)) begin
        @(negedge clk_i);
        cycles = cycles + 1;
      end
      check_condition(o_result_valid === 1'b1,
                      "first full-column result reaches backpressured boundary");
      held_data = o_result_data;
      held_last = o_result_last;
      repeat (5) begin
        @(posedge clk_i);
        #1;
        check_condition(o_result_valid === 1'b1,
                        "result_valid remains asserted during backpressure");
        check_condition(o_result_data === held_data && o_result_last === held_last,
                        "result payload remains stable during backpressure");
        check_condition(o_cmd_ready === 1'b0,
                        "second operation is blocked until first stream is consumed");
      end
      @(negedge clk_i);
      i_result_ready = 1'b1;
      expect_compute_results();

      send_compute(1, 5, 8'hD1, 1'b0, 1'b0);
      send_compute(9, 15, 8'hD2, 1'b0, 1'b0);
      send_compute(17, 25, 8'hD3, 1'b1, 1'b1);
      expect_compute_results();
      end_test(name, mark);
    end
  endtask

  task automatic case_16;
    string name;
    integer mark;
    begin
      name = "CASE 16 - original SET, RESET and READ sequence";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 2, 1, 8'hFF);
      do_program(1'b0, 4, 5, 8'hFF);
      do_read(9, 0, 8'hFF);
      expect_no_result(5, "sequence leaves no duplicate result");
      end_test(name, mark);
    end
  endtask

  task automatic case_17;
    string name;
    integer mark;
    integer latency_cycles;
    begin
      name = "CASE 17 - externally visible COMPUTE completion and latency";
      begin_test(name, mark);
      apply_reset();
      do_program(1'b1, 0, 0, 8'h01);
      send_compute(0, 0, 8'h20, 1'b0, 1'b0);
      send_compute(0, 0, 8'h20, 1'b0, 1'b0);
      send_compute(0, 0, 8'h20, 1'b0, 1'b1);
      latency_cycles = 0;
      while ((o_result_valid !== 1'b1) && (latency_cycles < MAX_WAIT)) begin
        @(negedge clk_i);
        latency_cycles = latency_cycles + 1;
      end
      check_condition(latency_cycles >= COMPUTE_DELAY,
                      $sformatf("COMPUTE latency actual=%0d expected-at-least=%0d",
                                latency_cycles, COMPUTE_DELAY));
      expect_compute_results();
      check_condition(o_result_valid === 1'b0,
                      "one selected channel produces exactly one result");
      $display("CASE 17 NOTE: fine/coarse stop timing is not exposed by this behavioral-model boundary");
      end_test(name, mark);
    end
  endtask

  always @(posedge clk_i) begin
    if (monitor_enabled && o_command_accepted)
      $display("[%0t] CMD mode=%b row=%0d col=%0d pwm=%0d last=%b all=%b",
               $time, i_mode, i_row_index, i_col_index, i_pwm_data,
               i_compute_last, i_compute_all_columns);
    if (monitor_enabled && o_result_valid && i_result_ready)
      $display("[%0t] RESULT mode=%b col=%0d count=%0d last=%b",
               $time, o_result_data[20:19], o_result_data[18:14],
               o_result_data[13:0], o_result_last);
  end

  initial begin
    rst_i = 1'b1;
    drive_idle();
    i_target_set1 = CFG_TARGET_SET1;
    i_target_set2 = CFG_TARGET_SET2;
    i_target_reset1 = CFG_TARGET_RESET1;
    i_target_reset2 = CFG_TARGET_RESET2;
    i_no_of_clk_cycles = CFG_CLK_CYCLES;
    i_counter_value = CFG_COUNTER;
    i_tdc_time_out = CFG_TIMEOUT;
    i_tdc_dead_time = CFG_DEAD_TIME;

    selected_case = 0;
    total_tests = 0;
    passed_tests = 0;
    failed_tests = 0;
    failed_checks = 0;
    accepted_commands = 0;
    consumed_results = 0;
    monitor_enabled = $test$plusargs("MONITOR");

    if ($value$plusargs("CASE=%d", selected_case))
      $display("Selected direct testcase: %0d", selected_case);
    if ((selected_case < 0) || (selected_case > 17))
      $fatal(1, "Use +CASE=0..17");

    $display("");
    $display("================================================================================");
    $display("17-SCENARIO DIRECT TEST FOR sky130_bmlabs_reram__cim32x32");
    $display("selected_case=%0d (0 means run all seventeen)", selected_case);
    $display("================================================================================");

    if ((selected_case == 0) || (selected_case == 1)) case_1();
    if ((selected_case == 0) || (selected_case == 2)) case_2();
    if ((selected_case == 0) || (selected_case == 3)) case_3();
    if ((selected_case == 0) || (selected_case == 4)) case_4();
    if ((selected_case == 0) || (selected_case == 5)) case_5();
    if ((selected_case == 0) || (selected_case == 6)) case_6();
    if ((selected_case == 0) || (selected_case == 7)) case_7();
    if ((selected_case == 0) || (selected_case == 8)) case_8();
    if ((selected_case == 0) || (selected_case == 9)) case_9();
    if ((selected_case == 0) || (selected_case == 10)) case_10();
    if ((selected_case == 0) || (selected_case == 11)) case_11();
    if ((selected_case == 0) || (selected_case == 12)) case_12();
    if ((selected_case == 0) || (selected_case == 13)) case_13();
    if ((selected_case == 0) || (selected_case == 14)) case_14();
    if ((selected_case == 0) || (selected_case == 15)) case_15();
    if ((selected_case == 0) || (selected_case == 16)) case_16();
    if ((selected_case == 0) || (selected_case == 17)) case_17();

    $display("");
    $display("DIRECT MONITORS: accepted=%0d consumed_results=%0d",
             accepted_commands, consumed_results);
    $display("FINAL SUMMARY: TOTAL=%0d PASS=%0d FAIL=%0d FAILED_CHECKS=%0d",
             total_tests, passed_tests, failed_tests, failed_checks);

    if ((failed_tests != 0) || (failed_checks != 0))
      $fatal(1, "One or more direct-mode scenarios failed");
    else
      $finish;
  end

  initial begin
    #100_000_000;
    $fatal(1, "17-scenario behavioral regression watchdog timeout");
  end

endmodule
