`timescale 1ns/1ps

// Focused regression for the December-2026 dual-interface behavioral model.
module sky130_bmlabs_reram__cim32x32_dual_if_tb;
  localparam logic [31:0] WB_ADDR = 32'h3000_0004;
  localparam logic [31:0] WB_EMPTY = 32'hA000_0000;
  localparam logic [1:0] MODE_RESET = 2'b00;
  localparam logic [1:0] MODE_READ = 2'b01;
  localparam logic [1:0] MODE_COMPUTE = 2'b10;
  localparam logic [1:0] MODE_SET = 2'b11;

  logic clk_i = 1'b0;
  logic rst_i = 1'b1;
  always #5 clk_i = ~clk_i;

  logic interface_sel = 1'b0;
  logic i_Levelsh_enable = 1'b0;

  logic       i_cmd_valid = 1'b0;
  wire        o_cmd_ready;
  logic [1:0] i_mode = 2'b0;
  logic [4:0] i_row_index = 5'b0;
  logic [4:0] i_col_index = 5'b0;
  logic [7:0] i_pwm_data = 8'b0;
  logic       i_compute_last = 1'b0;
  logic       i_compute_all_columns = 1'b0;

  logic [15:0] i_target_set1 = 16'h1000;
  logic [15:0] i_target_set2 = 16'h1000;
  logic [15:0] i_target_reset1 = 16'h0200;
  logic [15:0] i_target_reset2 = 16'h0200;
  logic [9:0]  i_no_of_clk_cycles = 10'd1;
  logic [9:0]  i_counter_value = 10'd2;
  logic [6:0]  i_tdc_time_out = 7'd63;
  logic [1:0]  i_tdc_dead_time = 2'd2;

  wire       o_busy;
  wire       o_command_accepted;
  wire       o_compute_pending;
  wire [2:0] o_error;
  wire       o_error_valid;
  wire       o_operation_done;
  wire       o_program_readback_active;
  wire       o_result_valid;
  logic      i_result_ready = 1'b1;
  wire [20:0] o_result_data;
  wire       o_result_last;

  logic        wbs_stb_i = 1'b0;
  logic        wbs_cyc_i = 1'b0;
  logic        wbs_we_i = 1'b0;
  logic [3:0]  wbs_sel_i = 4'hF;
  logic [31:0] wbs_dat_i = 32'b0;
  logic [31:0] wbs_adr_i = WB_ADDR;
  wire [31:0]  wbs_dat_o;
  wire         wbs_ack_o;

  logic [31:0] stop_bit_i = 32'b0;
  logic ScanInCC = 1'b0;
  logic ScanInDL = 1'b0;
  logic ScanInDR = 1'b0;
  logic TM = 1'b0;
  wire ScanOutCC;

  integer checks = 0;
  integer failures = 0;

  sky130_bmlabs_reram__cim32x32 #(
    .READ_DELAY(2),
    .PROGRAM_DELAY(3),
    .COMPUTE_DELAY(4)
  ) dut (
    .interface_sel(interface_sel),
    .i_Levelsh_enable(i_Levelsh_enable),
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
    .wbs_stb_i(wbs_stb_i),
    .wbs_cyc_i(wbs_cyc_i),
    .wbs_we_i(wbs_we_i),
    .wbs_sel_i(wbs_sel_i),
    .wbs_dat_i(wbs_dat_i),
    .wbs_adr_i(wbs_adr_i),
    .wbs_dat_o(wbs_dat_o),
    .wbs_ack_o(wbs_ack_o),
    .stop_bit_i(stop_bit_i),
    .ScanInCC(ScanInCC),
    .ScanInDL(ScanInDL),
    .ScanInDR(ScanInDR),
    .ScanOutCC(ScanOutCC),
    .TM(TM),
    .Iref(),
    .Vcc_read(),
    .Vcomp(),
    .Bias_comp2(),
    .Vcc_wl_read(),
    .Vcc_wl_set(),
    .Vbias(),
    .Vcc_wl_reset(),
    .Vcc_set(),
    .VCC_SNEAK(),
    .dc_bias()
  );

  function automatic [31:0] packet(
    input logic [1:0] mode,
    input logic [4:0] row_index,
    input logic [4:0] col_index,
    input logic all_columns,
    input logic compute_last,
    input logic [7:0] pwm
  );
    packet = {mode, row_index, col_index, 1'b0, all_columns,
              compute_last, 9'b0, pwm};
  endfunction

  task automatic check(input logic condition, input string message);
    begin
      checks = checks + 1;
      if (!condition) begin
        failures = failures + 1;
        $display("FAIL: %s", message);
      end else begin
        $display("PASS: %s", message);
      end
    end
  endtask

  task automatic raw_command(
    input logic [1:0] mode,
    input logic [4:0] row_index,
    input logic [4:0] col_index,
    input logic [7:0] pwm,
    output logic [20:0] result
  );
    integer timeout;
    begin
      timeout = 0;
      while (!o_cmd_ready && timeout < 1000) begin
        @(negedge clk_i);
        timeout = timeout + 1;
      end
      if (timeout == 1000) begin
        failures = failures + 1;
        $display("FAIL: raw command timed out waiting for ready");
      end

      @(negedge clk_i);
      i_mode = mode;
      i_row_index = row_index;
      i_col_index = col_index;
      i_pwm_data = pwm;
      i_compute_last = 1'b0;
      i_compute_all_columns = 1'b0;
      i_cmd_valid = 1'b1;
      @(negedge clk_i);
      i_cmd_valid = 1'b0;

      timeout = 0;
      while (!o_result_valid && timeout < 1000) begin
        @(negedge clk_i);
        timeout = timeout + 1;
      end
      result = o_result_data;
      if (timeout == 1000) begin
        failures = failures + 1;
        $display("FAIL: raw command timed out waiting for result");
      end
      @(negedge clk_i);
    end
  endtask

  task automatic wb_write(input logic [31:0] data);
    integer timeout;
    begin
      @(negedge clk_i);
      wbs_dat_i = data;
      wbs_we_i = 1'b1;
      wbs_cyc_i = 1'b1;
      wbs_stb_i = 1'b1;
      timeout = 0;
      while (!wbs_ack_o && timeout < 1000) begin
        @(negedge clk_i);
        timeout = timeout + 1;
      end
      if (timeout == 1000) begin
        failures = failures + 1;
        $display("FAIL: Wishbone write timed out data=%08x", data);
      end
      wbs_cyc_i = 1'b0;
      wbs_stb_i = 1'b0;
      wbs_we_i = 1'b0;
      @(negedge clk_i);
    end
  endtask

  task automatic wb_read(output logic [31:0] data);
    integer timeout;
    begin
      @(negedge clk_i);
      wbs_we_i = 1'b0;
      wbs_cyc_i = 1'b1;
      wbs_stb_i = 1'b1;
      timeout = 0;
      while (!wbs_ack_o && timeout < 1000) begin
        @(negedge clk_i);
        timeout = timeout + 1;
      end
      data = wbs_dat_o;
      if (timeout == 1000) begin
        failures = failures + 1;
        $display("FAIL: Wishbone read timed out");
      end
      wbs_cyc_i = 1'b0;
      wbs_stb_i = 1'b0;
      @(negedge clk_i);
    end
  endtask

  task automatic wb_wait_result(output logic [31:0] data);
    integer poll_count;
    begin
      data = WB_EMPTY;
      poll_count = 0;
      while (data == WB_EMPTY && poll_count < 1000) begin
        wb_read(data);
        poll_count = poll_count + 1;
      end
      if (data == WB_EMPTY) begin
        failures = failures + 1;
        $display("FAIL: Wishbone result polling timed out");
      end
    end
  endtask

  logic [20:0] raw_set_result;
  logic [20:0] raw_read_result;
  logic [31:0] wb_result;
  logic [31:0] wb_reset_result;
  logic [31:0] wb_cfg3;

  initial begin
    repeat (4) @(posedge clk_i);
    rst_i = 1'b0;
    repeat (2) @(negedge clk_i);

    check(o_cmd_ready && !wbs_ack_o,
          "direct mode owns the raw command boundary");

    raw_command(MODE_SET, 5'd2, 5'd3, 8'd5, raw_set_result);
    check(raw_set_result[20:19] == MODE_SET &&
          raw_set_result[18:14] == 5'd3,
          "direct SET returns the expected mode and column");

    interface_sel = 1'b1;
    repeat (2) @(negedge clk_i);
    check(!o_cmd_ready && !o_result_valid,
          "Wishbone selection isolates the raw interface");

    wb_write({16'h1000, 16'h1000});
    wb_write({16'h0200, 16'h0200});
    wb_cfg3 = {2'd2, 2'b00, 1'b1, 7'd63, 10'd2, 10'd1};
    wb_write(wb_cfg3);
    repeat (10) @(negedge clk_i);
    wb_write(packet(MODE_READ, 5'd2, 5'd3, 1'b0, 1'b0, 8'd0));
    wb_wait_result(wb_result);
    check(wb_result[20:19] == MODE_READ && wb_result[18:14] == 5'd3,
          "Wishbone READ returns the expected mode and column");
    check(wb_result[13:0] == raw_set_result[13:0],
          "Wishbone READ sees the cell programmed through the raw interface");

    wb_write(packet(MODE_RESET, 5'd2, 5'd3, 1'b0, 1'b0, 8'd1));
    wb_wait_result(wb_reset_result);
    check(wb_reset_result[20:19] == MODE_RESET &&
          wb_reset_result[18:14] == 5'd3,
          "Wishbone RESET returns its automatic readback");

    wb_write(packet(MODE_COMPUTE, 5'd2, 5'd3, 1'b0, 1'b1, 8'd4));
    wb_wait_result(wb_result);
    check(wb_result[20:19] == MODE_COMPUTE &&
          wb_result[18:14] == 5'd3,
          "Wishbone COMPUTE packet produces the selected-column result");

    wb_read(wb_result);
    check(wb_result == WB_EMPTY,
          "empty Wishbone result queue returns 0xA0000000");

    interface_sel = 1'b0;
    repeat (2) @(negedge clk_i);
    check(!wbs_ack_o && o_cmd_ready,
          "switching back to direct mode isolates Wishbone and restores ready");
    raw_command(MODE_READ, 5'd2, 5'd3, 8'd0, raw_read_result);
    check(raw_read_result[13:0] == wb_reset_result[13:0],
          "direct READ sees the cell reset through Wishbone");

    $display("DUAL-INTERFACE SUMMARY: checks=%0d failures=%0d", checks, failures);
    if (failures != 0)
      $fatal(1, "dual-interface regression failed");
    $finish;
  end

endmodule
