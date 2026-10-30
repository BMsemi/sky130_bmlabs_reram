
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Wishbone shim: expose one address (0x3000_0004).
//  - WB WRITE @ 0x3000_0004  -> send command into core
//  - WB READ  @ 0x3000_0004  -> get result from core
// -----------------------------------------------------------------------------

`ifdef USE_POWER_PINS
    `define USE_PG_PIN
`endif

`celldefine

module sky130_bmlabs_reram__nvm32x32wb (

`ifdef USE_PG_PIN
   inout         VDDC1,            // 1.8 V digital supply; connect to vccd1
   inout         VDDC2,            // 1.8 V digital supply; connect to vccd2
   inout         VDDA1,            // 3.3 V analog supply; connect to vdda1
   inout         VDDA2,            // 3.3 V analog supply; connect to vdda2
   inout         VSS,              // common ground; connect to vssd1
`endif
  input         user_clk,     // user clock
  input         user_rst,     // user reset
  input         wb_clk_i,     // Wishbone clock
  input         wb_rst_i,     // Wishbone reset (Active High)
  input         wbs_stb_i,    // Wishbone strobe
  input         wbs_cyc_i,    // Wishbone cycle indicator
  input         wbs_we_i,     // Wishbone write enable: 1=write, 0=read
  input  [3:0]  wbs_sel_i,    // Wishbone byte select (must be 4'hF for 32-bit op)
  input  [31:0] wbs_dat_i,    // Wishbone write data (becomes DI to core)
  input  [31:0] wbs_adr_i,    // Wishbone address
  output [31:0] wbs_dat_o,    // Wishbone read data output (driven by DO from core)
  output        wbs_ack_o,     // Wishbone acknowledge output (core_ack from core)
  
  // Scan/Test Pins
  input         ScanInCC,        // Scan enable
  input         ScanInDL,        // Data scan chain input (user_clk domain)
  input         ScanInDR,        // Data scan chain input (wb_clk domain)
  input         TM,              // Test mode
  output        ScanOutCC,       // Data scan chain output

  // Analog Pins
  input         Iref,            // 100 µA current reference
  input         Vcc_read,        // 0.3 V read rail
  input         Vcomp,           // 0.6 V comparator bias
  input         Bias_comp2,      // 0.6 V comparator bias
  input         Vcc_wl_read,     // 0.7 V wordline read rail
  input         Vcc_wl_set,      // 1.8 V wordline set rail
  input         Vbias,           // 1.8 V analog bias
  input         Vcc_wl_reset,    // 2.6 V wordline reset rail
  input         Vcc_set,         // 3.3 V array set rail
  input         dc_bias
);

  parameter [31:0] ADDR_MATCH = 32'h3000_0004;
	
	// --------------------------------------------------------------------------
  // Internal wires connecting the shim to the behavioral core
  // --------------------------------------------------------------------------
	wire        CLKin;
  wire        RSTin;
  wire        EN;
  wire [31:0] DI;
  wire        W_RB;
  wire [31:0] DO;
  wire        core_ack;
	
	// Map WB to core
	assign EN = (wbs_stb_i && wbs_cyc_i && (wbs_adr_i == ADDR_MATCH) && (wbs_sel_i == 4'hF));
	assign CLKin      = wb_clk_i;
  assign RSTin      = wb_rst_i;
	assign DI         = wbs_dat_i;
	assign W_RB       = wbs_we_i;
	assign wbs_dat_o  = DO;
	assign wbs_ack_o  = core_ack;
	
	// Instantiate the behavioral core
	sky130_bmlabs_reram__nvm32x32wb_beh core_inst (
	`ifdef USE_PG_PIN
      .VDDC1(VDDC1),
      .VDDC2(VDDC2),
      .VDDA1(VDDA1),
      .VDDA2(VDDA2),
      .VSS(VSS),
`endif
    .CLKin      (CLKin),
    .RSTin      (RSTin),
    .EN         (EN),
    .DI         (DI),
    .W_RB       (W_RB),
    .DO         (DO),
    .core_ack   (core_ack),
    
    // Scan/Test Pins
    .ScanInCC(ScanInCC),
    .ScanInDL(ScanInDL),
    .ScanInDR(ScanInDR),
    .TM(TM),
    .ScanOutCC(ScanOutCC),

    // Analog Pins
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
	
endmodule


// -----------------------------------------------------------------------------
// Behavioral core (sim only)
//  - 32x32 bit array
//  - input FIFO (commands), output FIFO (read results)
//  - PROGRAM (MODE=11): after WR_Dly cycles, DATA[7:0] selects SET/RESET
//  - READ    (MODE=01): after RD_Dly cycles, push {31'b0, bit} into output FIFO
//  - WB READ a result: ACK=1 when a word is popped
//  - If empty: DO=DEAD_C0DE for visibility and ACK=1
//
// Command word:
//   [31:30] operation: 2'b11 PROGRAM, 2'b01 READ
//   [29:25] row (0..31)
//   [24:20] column (0..31)
//   [19:8]  reserved
//   [7:0]   program value (> 8'h7F SETs to 1, <= 8'h7F RESETs to 0)
// Modes 2'b00 and 2'b10 are unsupported by this X1 NVM model and are discarded.
// -----------------------------------------------------------------------------


module sky130_bmlabs_reram__nvm32x32wb_beh (

`ifdef USE_PG_PIN
   inout         VDDC1,            // 1.8 V digital supply; connect to vccd1
   inout         VDDC2,            // 1.8 V digital supply; connect to vccd2
   inout         VDDA1,            // 3.3 V analog supply; connect to vdda1
   inout         VDDA2,            // 3.3 V analog supply; connect to vdda2
   inout         VSS,              // common ground; connect to vssd1
`endif

  input         CLKin,
	input         RSTin,
	input         EN,
	input  [31:0] DI,
	input         W_RB,
	output reg [31:0] DO,
	output reg    core_ack,
	
	// Scan/Test Pins
  input         ScanInCC,        // Scan enable
  input         ScanInDL,        // Scan data in (user_clk domain)
  input         ScanInDR,        // Scan data in (wb_clk domain)
  input         TM,              // Test mode
  output        ScanOutCC,       // Scan data out

  // Analog Pins
  input         Iref,            // 100 µA current reference
  input         Vcc_read,        // 0.3 V read rail
  input         Vcomp,           // 0.6 V comparator bias
  input         Bias_comp2,      // 0.6 V comparator bias
  input         Vcc_wl_read,     // 0.7 V wordline read rail
  input         Vcc_wl_set,      // 1.8 V wordline set rail
  input         Vbias,           // 1.8 V analog bias
  input         Vcc_wl_reset,    // 2.6 V wordline reset rail
  input         Vcc_set,         // 3.3 V set rail
  input         dc_bias
);
  
        assign ScanOutCC = 1'b0;
        
	parameter RD_Dly       = 44;  // Clock cycles delay before read data becomes valid
	parameter WR_Dly       = 200; // Write delay (simulate ~1K cycles for real chip)
	
	integer arry_row,arry_col;
	localparam [1:0] MODE_READ    = 2'b01;
	localparam [1:0] MODE_PROGRAM = 2'b11;
	
	// 32x32 1-bit memory
	reg array_mem [0:31][0:31];
	
	// Two 32-deep FIFOs (behavioral)
	reg [31:0] ip_fifo [0:31];
	reg [31:0] op_fifo [0:31];
	
	// FIFO pointers/counters
	reg [4:0]  ip_fifo_addr;
	reg [4:0]  ip_fifo_addr_1;
	reg [4:0]  op_fifo_addr;
	reg [4:0]  op_fifo_addr_1;
	reg [5:0]  ip_fifo_size;
	reg [5:0]  op_fifo_size;
	
	// One command executes at a time while later commands may remain queued.
	reg        engine_busy;
	integer    engine_cycles_left;
	reg [31:0] engine_command;
  
  `ifndef SYNTHESIS
	wire [1:0] fifo_head_mode = ip_fifo[ip_fifo_addr_1][31:30];
	wire wb_write_accept = EN && W_RB && (ip_fifo_size < 32);
	wire wb_result_pop = EN && !W_RB && (op_fifo_size > 0);
	wire engine_start = !engine_busy && (ip_fifo_size > 0) &&
	                    !((fifo_head_mode == MODE_READ) && (op_fifo_size == 32));
	wire engine_complete = engine_busy && (engine_cycles_left == 1);
	wire engine_result_push = engine_complete &&
	                          (engine_command[31:30] == MODE_READ);

	// Wishbone and command-engine state share one clocked process so simultaneous
	// FIFO enqueue/dequeue events update each occupancy counter exactly once.
  always @(posedge CLKin or posedge RSTin) begin
	  if (RSTin) begin
		
		  DO <= 32'd0;
			core_ack <= 1'b0;
			
			ip_fifo_size <= 6'd0;
			op_fifo_size <= 6'd0;
			ip_fifo_addr <= 5'd0;
			ip_fifo_addr_1 <= 5'd0;
			op_fifo_addr <= 5'd0;
			op_fifo_addr_1 <= 5'd0;
			engine_busy <= 1'b0;
			engine_cycles_left <= 0;
			engine_command <= 32'd0;

		end else begin
		  
			core_ack <= 1'b0;
			
			// WB WRITE
			if (wb_write_accept) begin
			  core_ack <= 1'b1;
				ip_fifo[ip_fifo_addr] <= DI;
				ip_fifo_addr <= ip_fifo_addr + 5'd1;
			
		  // WB READ
			end else if (EN && !W_RB) begin
			  core_ack <= 1'b1;
			  if (op_fifo_size > 0) begin
				  DO <= op_fifo[op_fifo_addr_1];
				  op_fifo_addr_1 <= op_fifo_addr_1 + 5'd1;
			  end else begin
				  DO <= 32'hDEAD_C0DE;
			  end
			end

			// Start the next queued command when the engine is idle. A READ waits
			// here if the result FIFO is full; unsupported modes are consumed.
			if (engine_start) begin
			  ip_fifo_addr_1 <= ip_fifo_addr_1 + 5'd1;
			  case (fifo_head_mode)
			    MODE_PROGRAM: begin
			      engine_command <= ip_fifo[ip_fifo_addr_1];
			      engine_cycles_left <= WR_Dly;
			      engine_busy <= 1'b1;
			    end
			    MODE_READ: begin
			      engine_command <= ip_fifo[ip_fifo_addr_1];
			      engine_cycles_left <= RD_Dly;
			      engine_busy <= 1'b1;
			    end
			    default: begin
			      engine_busy <= 1'b0;
			      engine_cycles_left <= 0;
			    end
			  endcase
			end else if (engine_busy) begin
			  if (engine_cycles_left > 1) begin
			    engine_cycles_left <= engine_cycles_left - 1;
			  end else begin
			    engine_busy <= 1'b0;
			    engine_cycles_left <= 0;
			    if (engine_command[31:30] == MODE_PROGRAM) begin
			      array_mem[engine_command[29:25]][engine_command[24:20]] <=
			        (engine_command[7:0] > 8'h7F);
			    end else if (engine_command[31:30] == MODE_READ) begin
			      op_fifo[op_fifo_addr] <=
			        {31'd0, array_mem[engine_command[29:25]][engine_command[24:20]]};
			      op_fifo_addr <= op_fifo_addr + 5'd1;
			    end
			  end
			end

			case ({wb_write_accept, engine_start})
			  2'b10: ip_fifo_size <= ip_fifo_size + 6'd1;
			  2'b01: ip_fifo_size <= ip_fifo_size - 6'd1;
			  default: ip_fifo_size <= ip_fifo_size;
			endcase

			case ({engine_result_push, wb_result_pop})
			  2'b10: op_fifo_size <= op_fifo_size + 6'd1;
			  2'b01: op_fifo_size <= op_fifo_size - 6'd1;
			  default: op_fifo_size <= op_fifo_size;
			endcase
		end
  end
	`endif
	
	initial begin
	 	// init array to 0
		for (arry_row = 0; arry_row < 32; arry_row = arry_row + 1) begin
       for (arry_col = 0; arry_col < 32; arry_col = arry_col + 1) begin
         array_mem[arry_row][arry_col] = 1'b0;
       end
     end
	end

endmodule
`endcelldefine


