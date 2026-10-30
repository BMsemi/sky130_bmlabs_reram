`timescale 1ns/1ps

module sky130_bmlabs_reram__cim32x32wb (
 
 `ifdef USE_POWER_PINS
   inout         VDDC1,            // 1.8 V digital supply; connect to vccd1
   inout         VDDC2,            // 1.8 V digital supply; connect to vccd2
   inout         VDDA1,            // 3.3 V analog supply; connect to vdda1
   inout         VDDA2,            // 3.3 V analog supply; connect to vdda2
   inout         VSS,              // common ground; connect to vssd1
 `endif
 
    // Clocks & resets
    input         user_clk,       // user clock
    input         user_rst,       // user reset (Active Low)
    input         wb_clk_i,       // Wishbone clock
    input         wb_rst_i,       // Wishbone reset (Active High)

    // Wishbone inputs
    input         wbs_stb_i,      // Wishbone strobe
    input         wbs_cyc_i,      // Wishbone cycle indicator
    input         wbs_we_i,       // Wishbone write enable
    input  [3:0]  wbs_sel_i,      // Wishbone byte select
    input  [31:0] wbs_dat_i,      // Wishbone write data
    input  [31:0] wbs_adr_i,      // Wishbone address

    // Wishbone outputs
    output [31:0] wbs_dat_o,      // Wishbone read data
    output        wbs_ack_o,      // Wishbone acknowledge

    // Scan/Test Pins
    input         ScanInCC,       // Scan enable
    input         ScanInDL,       // Data scan chain input (user_clk domain)
    input         ScanInDR,       // Data scan chain input (wb_clk domain)
    input         TM,             // Test mode
    output        ScanOutCC,      // Data scan chain output

    // Analog Pins
    inout         Iref,           // 100 uA current reference
    
    inout         Vcc_read,       // 0.3 V read rail
    inout         Vcomp,          // 0.6 V comparator/reference bias
    inout         Bias_comp2,     // 0.6 V comparator bias
    inout         Vcc_wl_read,    // 0.7 V wordline read rail
    inout         Vcc_wl_set,     // 1.8 V wordline set rail
    
    inout         Vbias,          // 1.8 V analog bias
    inout         Vcc_wl_reset,   // 2.6 V wordline reset rail
    inout         Vcc_set,        // 3.3 V array set rail
    inout         dc_bias
);

endmodule
