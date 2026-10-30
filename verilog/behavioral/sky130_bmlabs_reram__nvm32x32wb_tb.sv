`timescale 1ns/1ps
`default_nettype none

module sky130_bmlabs_reram__nvm32x32wb_tb;
  localparam logic [31:0] ADDR = 32'h3000_0004;

  logic        user_clk = 1'b0;
  logic        user_rst = 1'b0;
  logic        wb_clk_i = 1'b0;
  logic        wb_rst_i = 1'b1;
  logic        wbs_stb_i = 1'b0;
  logic        wbs_cyc_i = 1'b0;
  logic        wbs_we_i = 1'b0;
  logic [3:0]  wbs_sel_i = 4'h0;
  logic [31:0] wbs_dat_i = 32'h0;
  logic [31:0] wbs_adr_i = 32'h0;
  wire  [31:0] wbs_dat_o;
  wire         wbs_ack_o;

  logic ScanInCC = 1'b0;
  logic ScanInDL = 1'b0;
  logic ScanInDR = 1'b0;
  logic TM = 1'b0;
  wire  ScanOutCC;

  logic Iref = 1'b0;
  logic Vcc_read = 1'b0;
  logic Vcomp = 1'b0;
  logic Bias_comp2 = 1'b0;
  logic Vcc_wl_read = 1'b0;
  logic Vcc_wl_set = 1'b0;
  logic Vbias = 1'b0;
  logic Vcc_wl_reset = 1'b0;
  logic Vcc_set = 1'b0;
  logic dc_bias = 1'b0;

  always #5 user_clk = ~user_clk;
  always #5 wb_clk_i = ~wb_clk_i;

  sky130_bmlabs_reram__nvm32x32wb dut (
    .user_clk(user_clk),
    .user_rst(user_rst),
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),
    .wbs_stb_i(wbs_stb_i),
    .wbs_cyc_i(wbs_cyc_i),
    .wbs_we_i(wbs_we_i),
    .wbs_sel_i(wbs_sel_i),
    .wbs_dat_i(wbs_dat_i),
    .wbs_adr_i(wbs_adr_i),
    .wbs_dat_o(wbs_dat_o),
    .wbs_ack_o(wbs_ack_o),
    .ScanInCC(ScanInCC),
    .ScanInDL(ScanInDL),
    .ScanInDR(ScanInDR),
    .TM(TM),
    .ScanOutCC(ScanOutCC),
    .Iref(Iref),
    .Vcc_read(Vcc_read),
    .Vcomp(Vcomp),
    .Bias_comp2(Bias_comp2),
    .Vcc_wl_read(Vcc_wl_read),
    .Vcc_wl_set(Vcc_wl_set),
    .Vbias(Vbias),
    .Vcc_wl_reset(Vcc_wl_reset),
    .Vcc_set(Vcc_set),
    .dc_bias(dc_bias)
  );

  task automatic wb_write(input logic [31:0] data);
    begin
      @(negedge wb_clk_i);
      wbs_adr_i = ADDR;
      wbs_dat_i = data;
      wbs_sel_i = 4'hF;
      wbs_we_i = 1'b1;
      wbs_cyc_i = 1'b1;
      wbs_stb_i = 1'b1;
      do @(posedge wb_clk_i); while (!wbs_ack_o);
      @(negedge wb_clk_i);
      wbs_cyc_i = 1'b0;
      wbs_stb_i = 1'b0;
      wbs_we_i = 1'b0;
    end
  endtask

  task automatic wb_read(output logic [31:0] data);
    begin
      @(negedge wb_clk_i);
      wbs_adr_i = ADDR;
      wbs_sel_i = 4'hF;
      wbs_we_i = 1'b0;
      wbs_cyc_i = 1'b1;
      wbs_stb_i = 1'b1;
      do @(posedge wb_clk_i); while (!wbs_ack_o);
      #1 data = wbs_dat_o;
      @(negedge wb_clk_i);
      wbs_cyc_i = 1'b0;
      wbs_stb_i = 1'b0;
    end
  endtask

  logic [31:0] read_data;

  task automatic issue_read_and_check(
    input logic [4:0] row,
    input logic [4:0] column,
    input logic       expected,
    input string      operation
  );
    begin
      wb_write({2'b01, row, column, 12'd0, 8'h00});
      repeat (50) @(posedge wb_clk_i);
      wb_read(read_data);

      if (read_data !== {31'd0, expected}) begin
        $fatal(1, "%s failed: expected %08x, got %08x",
               operation, {31'd0, expected}, read_data);
      end
    end
  endtask

  initial begin
    #100000;
    $fatal(1, "NVM behavioral test timed out");
  end

  initial begin
    repeat (3) @(posedge wb_clk_i);
    wb_rst_i = 1'b0;

    // SET row 3, column 7 and verify the stored one.
    wb_write({2'b11, 5'd3, 5'd7, 12'd0, 8'hFF});
    repeat (205) @(posedge wb_clk_i);
    issue_read_and_check(5'd3, 5'd7, 1'b1, "SET/readback");

    // A Wishbone reset clears the interface/FIFOs, not the nonvolatile array.
    @(negedge wb_clk_i);
    wb_rst_i = 1'b1;
    repeat (3) @(posedge wb_clk_i);
    @(negedge wb_clk_i);
    wb_rst_i = 1'b0;
    issue_read_and_check(5'd3, 5'd7, 1'b1, "reset persistence");

    // An unsupported COMPUTE opcode must be discarded rather than blocking
    // the valid RESET command queued after it.
    wb_write({2'b10, 5'd0, 5'd0, 12'd0, 8'h00});

    // RESET the same cell with a low program value and verify the stored zero.
    wb_write({2'b11, 5'd3, 5'd7, 12'd0, 8'h00});
    repeat (205) @(posedge wb_clk_i);
    issue_read_and_check(5'd3, 5'd7, 1'b0, "RESET/readback");

    $display("PASS: sky130_bmlabs_reram__nvm32x32wb SET/RESET/READ behavior");
    $finish;
  end
endmodule

`default_nettype wire
