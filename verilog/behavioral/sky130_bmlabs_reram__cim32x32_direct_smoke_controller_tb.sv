`timescale 1ns/1ps

module sky130_bmlabs_reram__cim32x32_direct_smoke_controller_tb;
  logic clk_i = 1'b0;
  logic rst_i = 1'b1;
  logic start_i = 1'b0;
  always #5 clk_i = ~clk_i;

  wire interface_sel;
  wire cim_i_Levelsh_enable;
  wire [15:0] cim_i_target_set1;
  wire [15:0] cim_i_target_set2;
  wire [15:0] cim_i_target_reset1;
  wire [15:0] cim_i_target_reset2;
  wire [9:0] cim_i_no_of_clk_cycles;
  wire [9:0] cim_i_counter_value;
  wire [6:0] cim_i_tdc_time_out;
  wire [1:0] cim_i_tdc_dead_time;
  wire cim_i_cmd_valid;
  wire cim_o_cmd_ready;
  wire [1:0] cim_i_mode;
  wire [4:0] cim_i_row_index;
  wire [4:0] cim_i_col_index;
  wire [7:0] cim_i_pwm_data;
  wire cim_i_compute_last;
  wire cim_i_compute_all_columns;
  wire cim_o_result_valid;
  wire cim_i_result_ready;
  wire [20:0] cim_o_result_data;
  wire cim_o_result_last;
  wire [2:0] cim_o_error;
  wire cim_o_error_valid;
  wire busy_o;
  wire done_o;
  wire pass_o;
  wire fail_o;
  wire [3:0] state_o;
  wire [7:0] failure_code_o;
  wire [20:0] set_auto_result_o;
  wire [20:0] reset_auto_result_o;
  wire [2:0] accepted_count_o;
  wire [2:0] result_count_o;
  sky130_bmlabs_reram__cim32x32_direct_smoke_controller #(
    .TIMEOUT_CYCLES(2000)
  ) controller (
    .*
  );

  sky130_bmlabs_reram__cim32x32 #(
    .READ_DELAY(2),
    .PROGRAM_DELAY(3),
    .COMPUTE_DELAY(4)
  ) cim (
    .interface_sel(interface_sel),
    .i_Levelsh_enable(cim_i_Levelsh_enable),
    .clk_i(clk_i),
    .rst_i(rst_i),
    .i_cmd_valid(cim_i_cmd_valid),
    .o_cmd_ready(cim_o_cmd_ready),
    .i_mode(cim_i_mode),
    .i_row_index(cim_i_row_index),
    .i_col_index(cim_i_col_index),
    .i_pwm_data(cim_i_pwm_data),
    .i_compute_last(cim_i_compute_last),
    .i_compute_all_columns(cim_i_compute_all_columns),
    .i_target_set1(cim_i_target_set1),
    .i_target_set2(cim_i_target_set2),
    .i_target_reset1(cim_i_target_reset1),
    .i_target_reset2(cim_i_target_reset2),
    .i_no_of_clk_cycles(cim_i_no_of_clk_cycles),
    .i_counter_value(cim_i_counter_value),
    .i_tdc_time_out(cim_i_tdc_time_out),
    .i_tdc_dead_time(cim_i_tdc_dead_time),
    .o_busy(),
    .o_command_accepted(),
    .o_compute_pending(),
    .o_error(cim_o_error),
    .o_error_valid(cim_o_error_valid),
    .o_operation_done(),
    .o_program_readback_active(),
    .o_result_valid(cim_o_result_valid),
    .i_result_ready(cim_i_result_ready),
    .o_result_data(cim_o_result_data),
    .o_result_last(cim_o_result_last),
    .wbs_stb_i(1'b0),
    .wbs_cyc_i(1'b0),
    .wbs_we_i(1'b0),
    .wbs_sel_i(4'b0),
    .wbs_dat_i(32'b0),
    .wbs_adr_i(32'b0),
    .wbs_dat_o(),
    .wbs_ack_o(),
    .ScanInCC(1'b0),
    .ScanInDL(1'b0),
    .ScanInDR(1'b0),
    .ScanOutCC(),
    .TM(1'b0),
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

  initial begin
    repeat (5) @(posedge clk_i);
    rst_i = 1'b0;
    repeat (3) @(posedge clk_i);
    start_i = 1'b1;
    repeat (2) @(posedge clk_i);
    start_i = 1'b0;

    fork
      begin
        wait (done_o);
        #1;
        if (!pass_o || fail_o)
          $fatal(1, "smoke controller failed: code=%02h state=%0d",
                 failure_code_o, state_o);
        if (interface_sel !== 1'b0)
          $fatal(1, "direct/raw interface was not selected");
        if ((accepted_count_o != 2) || (result_count_o != 2))
          $fatal(1, "unexpected transaction counts: accepted=%0d results=%0d",
                 accepted_count_o, result_count_o);
        if (set_auto_result_o[20:19] != 2'b11 ||
            reset_auto_result_o[20:19] != 2'b00)
          $fatal(1, "result mode tags are incorrect");
        $display("FPGA MASTER SMOKE PASS: set_auto=%06h reset_auto=%06h",
                 set_auto_result_o, reset_auto_result_o);
        $finish;
      end
      begin
        repeat (10000) @(posedge clk_i);
        $fatal(1, "smoke controller simulation timed out");
      end
    join_any
  end

endmodule
