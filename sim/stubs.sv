// Stand-ins for the parts of the MiSTer framework and the PLLs, so that the whole core can be run in the simulator.
// The testbench sets what the menu and the keys would: dut.hps_io.status, joystick_0, ps2_key, sdram_sz.
`timescale 1ns/1ps

module hps_io #(parameter CONF_STR = "")
(
	input              clk_sys,
	inout       [45:0] HPS_BUS,
	output reg [127:0] status,
	input      [127:0] status_in,
	input              status_set,
	input       [15:0] status_menumask,
	output       [1:0] buttons,
	output reg  [15:0] sdram_sz,
	output reg         forced_scandoubler,
	output reg  [31:0] joystick_0,
	output reg  [10:0] ps2_key,
	input        [2:0] ps2_kbd_led_use,
	input        [2:0] ps2_kbd_led_status
);
initial begin
	status = 0;
	sdram_sz = 16'h8000 | 16'd1;          // 32 MB, set
	forced_scandoubler = 0;
	joystick_0 = 0;
	ps2_key = 0;
end
always @(posedge clk_sys) if (status_set) status <= status_in;      // the menu takes what the core sets
assign buttons = 0;
endmodule

// 100 MHz while it is not held in reset, and locked a while after it is let go
module pll
(
	input  wire        refclk,
	input  wire        rst,
	output wire        outclk_0,
	output reg         locked,
	input  wire [63:0] reconfig_to_pll,
	output wire [63:0] reconfig_from_pll
);
reg clk = 0;
reg run = 0;
integer n = 0;
assign reconfig_from_pll = 64'd0;
assign outclk_0 = clk;
always #5 if (run) clk = ~clk; else clk = 0;
always @(posedge refclk or posedge rst) begin
	if (rst) begin
		run <= 0;
		locked <= 0;
		n <= 0;
	end else begin
		run <= 1;
		n <= n + 1;
		if (n > 30) locked <= 1;
	end
end
initial begin locked = 0; end
endmodule

module pll_cfg
(
	input         mgmt_clk,
	input         mgmt_reset,
	output        mgmt_waitrequest,
	input         mgmt_read,
	output [31:0] mgmt_readdata,
	input         mgmt_write,
	input   [5:0] mgmt_address,
	input  [31:0] mgmt_writedata,
	output [63:0] reconfig_to_pll,
	input  [63:0] reconfig_from_pll
);
assign mgmt_waitrequest = 0;
assign mgmt_readdata = 0;
assign reconfig_to_pll = 0;
endmodule

// 27 MHz
module vpll
(
	input  wire refclk,
	input  wire rst,
	output wire outclk_0
);
reg clk = 0;
assign outclk_0 = clk;
always #18.5185 clk = ~clk;
endmodule
