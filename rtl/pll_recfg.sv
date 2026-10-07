// Sets the SDRAM clock: writes the M, K, N and C settings of the PLL through pll_cfg of the MiSTer framework and pulses the PLL's reset.
// The sequence and its pacing (a step every 8 clocks while the PLL is locked and not busy) are those of the original MemTest core.
// start begins it; busy is high until it is done.

module pll_recfg
(
	input             clk,            // 50 MHz
	input             start,          // a pulse
	input             locked,
	input             waitrequest,
	input      [31:0] m,
	input      [31:0] k,
	input      [31:0] c,

	output reg        write,
	output reg  [5:0] address,
	output reg [31:0] writedata,
	output reg        pll_reset,
	output reg        busy
);

reg [7:0] state = 0;

always @(posedge clk) begin
	write <= 0;

	if (start) begin
		state <= 0;
		busy  <= 1;
	end else if (((locked && !waitrequest) || pll_reset) && busy) begin
		state <= state + 1'd1;
		if (!state[2:0]) begin
			case (state[7:3])
				0: begin address <= 0; writedata <= 0;      write <= 1; end   // start
				1: begin address <= 4; writedata <= m;      write <= 1; end   // M
				2: begin address <= 7; writedata <= k;      write <= 1; end   // K
				3: begin address <= 3; writedata <= 'h10000; write <= 1; end  // N (bypassed)
				4: begin address <= 5; writedata <= c;      write <= 1; end   // C0
				5: begin address <= 9; writedata <= 1;      write <= 1; end   // charge pump
				6: begin address <= 8; writedata <= 7;      write <= 1; end   // bandwidth
				7: begin address <= 2; writedata <= 0;      write <= 1; end   // apply
				8: pll_reset <= 1;
				9: pll_reset <= 0;
				10: busy <= 0;
			endcase
		end
	end
end

initial begin
	pll_reset = 0;
	busy      = 1;     // the first clock is set as soon as the PLL is locked
	write     = 0;
end

endmodule
