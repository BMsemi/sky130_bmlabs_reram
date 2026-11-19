`timescale 1ns/1ps
`default_nettype none

// Synthesizable FPGA smoke-test controller for the native/direct CIM interface.
//
// Sequence after a rising edge on start_i:
//   1. SET   cell (ROW_INDEX, COL_INDEX), then consume its automatic readback.
//   2. RESET the same cell, then consume its automatic readback.
//
// The controller permits only one outstanding direct transaction. It therefore
// waits for and consumes the SET automatic readback before presenting RESET.
// No explicit READ command is generated.
//
// Connect the cim_* ports directly to the corresponding pins on
// sky130_bmlabs_reram__cim32x32. start_i passes through a two-flop synchronizer,
// but a mechanical pushbutton still needs an external debounce circuit.
//
// done_o/pass_o/fail_o remain asserted until rst_i. The captured result format
// is {mode[1:0], column[4:0], count[13:0]}. failure_code_o meanings are:
//   01 SET command timeout       02 SET automatic response mismatch
//   03 SET automatic timeout     04 RESET command timeout
//   05 RESET automatic response mismatch
//   06 RESET automatic timeout
//   FF illegal FSM state
module sky130_bmlabs_reram__cim32x32_direct_smoke_controller #(
  parameter logic [4:0]  ROW_INDEX = 5'd2,
  parameter logic [4:0]  COL_INDEX = 5'd1,
  parameter logic [7:0]  SET_PWM = 8'hFF,
  parameter logic [7:0]  RESET_PWM = 8'hFF,
  parameter logic [15:0] TARGET_SET1 = 16'h6472,
  parameter logic [15:0] TARGET_SET2 = 16'h0003,
  parameter logic [15:0] TARGET_RESET1 = 16'h000B,
  parameter logic [15:0] TARGET_RESET2 = 16'h462B,
  parameter logic [9:0]  NO_OF_CLK_CYCLES = 10'd5,
  parameter logic [9:0]  COUNTER_VALUE = 10'd5,
  parameter logic [6:0]  TDC_TIME_OUT = 7'd62,
  parameter logic [1:0]  TDC_DEAD_TIME = 2'd2,
  // Referenced RTL: 0 enables and 1 disables the level shifters. Hardware
  // therefore defaults to enabled; override only if the integration requires it.
  parameter logic        LEVELSH_CONTROL = 1'b0,
  parameter integer      TIMEOUT_CYCLES = 1_000_000
)(
  input  wire         clk_i,
  input  wire         rst_i,
  input  wire         start_i,

  // Static CIM interface selection and configuration.
  output wire         interface_sel,
  output wire         cim_i_Levelsh_enable,
  output wire [15:0]  cim_i_target_set1,
  output wire [15:0]  cim_i_target_set2,
  output wire [15:0]  cim_i_target_reset1,
  output wire [15:0]  cim_i_target_reset2,
  output wire [9:0]   cim_i_no_of_clk_cycles,
  output wire [9:0]   cim_i_counter_value,
  output wire [6:0]   cim_i_tdc_time_out,
  output wire [1:0]   cim_i_tdc_dead_time,

  // Native/direct command interface to the CIM.
  output logic        cim_i_cmd_valid,
  input  wire         cim_o_cmd_ready,
  output logic [1:0]  cim_i_mode,
  output wire [4:0]   cim_i_row_index,
  output wire [4:0]   cim_i_col_index,
  output logic [7:0]  cim_i_pwm_data,
  output wire         cim_i_compute_last,
  output wire         cim_i_compute_all_columns,

  // Native/direct result interface from the CIM.
  input  wire         cim_o_result_valid,
  output logic        cim_i_result_ready,
  input  wire [20:0]  cim_o_result_data,
  input  wire         cim_o_result_last,
  input  wire [2:0]   cim_o_error,
  input  wire         cim_o_error_valid,

  // FPGA-visible status. These signals can be connected to LEDs, a logic
  // analyzer, UART registers, or fabric-visible status registers.
  output logic        busy_o,
  output logic        done_o,
  output logic        pass_o,
  output logic        fail_o,
  output logic [3:0]  state_o,
  output logic [7:0]  failure_code_o,
  output logic [20:0] set_auto_result_o,
  output logic [20:0] reset_auto_result_o,
  output logic [2:0]  accepted_count_o,
  output logic [2:0]  result_count_o
);

  localparam logic [1:0] MODE_RESET = 2'b00;
  localparam logic [1:0] MODE_SET   = 2'b11;

  localparam integer TIMEOUT_WIDTH =
      (TIMEOUT_CYCLES < 2) ? 1 : $clog2(TIMEOUT_CYCLES);

  typedef enum logic [3:0] {
    ST_IDLE            = 4'd0,
    ST_SEND_SET        = 4'd1,
    ST_WAIT_SET_AUTO   = 4'd2,
    ST_SEND_RESET      = 4'd3,
    ST_WAIT_RESET_AUTO = 4'd4,
    ST_DONE            = 4'd5,
    ST_FAIL            = 4'd6
  } state_t;

  state_t state;
  logic [TIMEOUT_WIDTH-1:0] timeout_counter;
  logic start_meta;
  logic start_sync;
  logic start_sync_d;

  wire start_rise = start_sync && !start_sync_d;
  wire command_transfer = cim_i_cmd_valid && cim_o_cmd_ready;
  wire result_transfer = cim_o_result_valid && cim_i_result_ready;
  wire timeout_expired = (timeout_counter == TIMEOUT_CYCLES - 1);

  assign interface_sel = 1'b0;
  assign cim_i_Levelsh_enable = LEVELSH_CONTROL;
  assign cim_i_target_set1 = TARGET_SET1;
  assign cim_i_target_set2 = TARGET_SET2;
  assign cim_i_target_reset1 = TARGET_RESET1;
  assign cim_i_target_reset2 = TARGET_RESET2;
  assign cim_i_no_of_clk_cycles = NO_OF_CLK_CYCLES;
  assign cim_i_counter_value = COUNTER_VALUE;
  assign cim_i_tdc_time_out = TDC_TIME_OUT;
  assign cim_i_tdc_dead_time = TDC_DEAD_TIME;
  assign cim_i_row_index = ROW_INDEX;
  assign cim_i_col_index = COL_INDEX;
  assign cim_i_compute_last = 1'b0;
  assign cim_i_compute_all_columns = 1'b0;

  always_comb begin
    cim_i_cmd_valid = 1'b0;
    cim_i_result_ready = 1'b0;
    cim_i_mode = MODE_RESET;
    cim_i_pwm_data = 8'b0;

    case (state)
      ST_SEND_SET: begin
        cim_i_cmd_valid = 1'b1;
        cim_i_mode = MODE_SET;
        cim_i_pwm_data = SET_PWM;
      end
      ST_WAIT_SET_AUTO: begin
        cim_i_result_ready = 1'b1;
      end
      ST_SEND_RESET: begin
        cim_i_cmd_valid = 1'b1;
        cim_i_mode = MODE_RESET;
        cim_i_pwm_data = RESET_PWM;
      end
      ST_WAIT_RESET_AUTO: begin
        cim_i_result_ready = 1'b1;
      end
      default: begin
      end
    endcase
  end

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      start_meta <= 1'b0;
      start_sync <= 1'b0;
      start_sync_d <= 1'b0;
    end else begin
      start_meta <= start_i;
      start_sync <= start_meta;
      start_sync_d <= start_sync;
    end
  end

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      state <= ST_IDLE;
      timeout_counter <= '0;
      busy_o <= 1'b0;
      done_o <= 1'b0;
      pass_o <= 1'b0;
      fail_o <= 1'b0;
      failure_code_o <= 8'h00;
      set_auto_result_o <= 21'b0;
      reset_auto_result_o <= 21'b0;
      accepted_count_o <= 3'd0;
      result_count_o <= 3'd0;
    end else begin
      case (state)
        ST_IDLE: begin
          timeout_counter <= '0;
          busy_o <= 1'b0;
          done_o <= 1'b0;
          pass_o <= 1'b0;
          fail_o <= 1'b0;
          failure_code_o <= 8'h00;
          accepted_count_o <= 3'd0;
          result_count_o <= 3'd0;
          if (start_rise) begin
            busy_o <= 1'b1;
            state <= ST_SEND_SET;
          end
        end

        ST_SEND_SET: begin
          if (command_transfer) begin
            accepted_count_o <= accepted_count_o + 3'd1;
            timeout_counter <= '0;
            state <= ST_WAIT_SET_AUTO;
          end else if (timeout_expired) begin
            busy_o <= 1'b0;
            fail_o <= 1'b1;
            done_o <= 1'b1;
            failure_code_o <= 8'h01;
            state <= ST_FAIL;
          end else begin
            timeout_counter <= timeout_counter + 1'b1;
          end
        end

        ST_WAIT_SET_AUTO: begin
          if (result_transfer) begin
            set_auto_result_o <= cim_o_result_data;
            result_count_o <= result_count_o + 3'd1;
            timeout_counter <= '0;
            if ((cim_o_result_data[20:19] != MODE_SET) ||
                (cim_o_result_data[18:14] != COL_INDEX) ||
                !cim_o_result_last ||
                (cim_o_error_valid && (cim_o_error != 3'b000))) begin
              busy_o <= 1'b0;
              fail_o <= 1'b1;
              done_o <= 1'b1;
              failure_code_o <= 8'h02;
              state <= ST_FAIL;
            end else begin
              state <= ST_SEND_RESET;
            end
          end else if (timeout_expired) begin
            busy_o <= 1'b0;
            fail_o <= 1'b1;
            done_o <= 1'b1;
            failure_code_o <= 8'h03;
            state <= ST_FAIL;
          end else begin
            timeout_counter <= timeout_counter + 1'b1;
          end
        end

        ST_SEND_RESET: begin
          if (command_transfer) begin
            accepted_count_o <= accepted_count_o + 3'd1;
            timeout_counter <= '0;
            state <= ST_WAIT_RESET_AUTO;
          end else if (timeout_expired) begin
            busy_o <= 1'b0;
            fail_o <= 1'b1;
            done_o <= 1'b1;
            failure_code_o <= 8'h04;
            state <= ST_FAIL;
          end else begin
            timeout_counter <= timeout_counter + 1'b1;
          end
        end

        ST_WAIT_RESET_AUTO: begin
          if (result_transfer) begin
            reset_auto_result_o <= cim_o_result_data;
            result_count_o <= result_count_o + 3'd1;
            timeout_counter <= '0;
            if ((cim_o_result_data[20:19] != MODE_RESET) ||
                (cim_o_result_data[18:14] != COL_INDEX) ||
                !cim_o_result_last ||
                (cim_o_error_valid && (cim_o_error != 3'b000))) begin
              busy_o <= 1'b0;
              fail_o <= 1'b1;
              done_o <= 1'b1;
              failure_code_o <= 8'h05;
              state <= ST_FAIL;
            end else begin
              busy_o <= 1'b0;
              done_o <= 1'b1;
              pass_o <= 1'b1;
              state <= ST_DONE;
            end
          end else if (timeout_expired) begin
            busy_o <= 1'b0;
            fail_o <= 1'b1;
            done_o <= 1'b1;
            failure_code_o <= 8'h06;
            state <= ST_FAIL;
          end else begin
            timeout_counter <= timeout_counter + 1'b1;
          end
        end

        ST_DONE: begin
          busy_o <= 1'b0;
          done_o <= 1'b1;
          pass_o <= 1'b1;
        end

        default: begin
          state <= ST_FAIL;
          busy_o <= 1'b0;
          done_o <= 1'b1;
          pass_o <= 1'b0;
          fail_o <= 1'b1;
          if (failure_code_o == 8'h00)
            failure_code_o <= 8'hFF;
        end
      endcase
    end
  end

  always_comb begin
    state_o = state;
  end

endmodule

`default_nettype wire
