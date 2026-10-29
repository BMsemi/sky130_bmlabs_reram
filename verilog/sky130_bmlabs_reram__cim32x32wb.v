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
    input         Iref,           // 100 ÂµA current reference
    
    input         Vcc_read,       // 0.3 V read rail
    input         Vcomp,          // 0.6 V comparator/reference bias
    input         Bias_comp2,     // 0.6 V comparator bias
    input         Vcc_wl_read,    // 0.7 V wordline read rail
    input         Vcc_wl_set,     // 1.8 V wordline set rail
    
    input         Vbias,          // 1.8 V analog bias
    input         Vcc_wl_reset,   // 2.6 V wordline reset rail
    input         Vcc_set,        // 3.3 V array set rail
    input         dc_bias
);

endmodule
