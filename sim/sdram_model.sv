// A behavioural SDR SDRAM for simulation: 4 banks, burst of 4, CAS latency 3, auto precharge. It complains (and counts) when the controller breaks
// the protocol, and it can be given faults: data lines stuck at a value, and a range of rows where one data bit is wrong.
// The memory holds 16 columns x 1024 rows x 4 banks: the simulation tests only a small area (sdram.v SIM_N).
`timescale 1ns/1ps

module sdram_model
#(
	parameter [15:0] STUCK_MASK = 16'h0000,    // data lines that read as STUCK_VAL
	parameter [15:0] STUCK_VAL  = 16'h0000,
	parameter        BAD_ROW0   = 1,            // rows BAD_ROW0..BAD_ROW1 read with data bit BAD_BIT wrong (BAD_ROW0 > BAD_ROW1: none)
	parameter        BAD_ROW1   = 0,
	parameter        BAD_BIT    = 5
)
(
	input         clk,
	input  [15:0] xor_mask,                         // data lines that read wrong, whatever is stored (a clock that is too fast for them)
	input         row_fault_en,                     // the row fault (BAD_ROW0..BAD_ROW1) is only there while this is high
	input         cs_n, ras_n, cas_n, we_n,
	input   [1:0] ba,
	input  [12:0] a,
	inout  [15:0] dq
);

reg [15:0] mem [0:65535];                      // {bank, row[9:0], col[3:0]}
reg [12:0] row_open [0:3];
reg        is_open  [0:3];
reg  [3:0] close_in [0:3];                    // auto precharge: clocks until the bank closes

integer errors = 0, refreshes = 0, reads = 0, writes = 0;
reg [2:0] cl = 3;
integer bl = 4;
reg [15:0] dq_out = 0;
reg        dq_oe  = 0;
assign dq = dq_oe ? dq_out : 16'bz;

reg  [7:0] dly_v;
reg [15:0] dly_d [0:7];

// a write in progress
reg  [3:0] wr_left = 0;
reg  [1:0] wr_ba;
reg  [12:0] wr_row;
reg  [9:0] wr_col;

integer k;
initial begin
	for (k = 0; k < 4; k = k + 1) begin is_open[k] = 0; close_in[k] = 0; row_open[k] = 0; end
	for (k = 0; k < 65536; k = k + 1) mem[k] = 16'h0000;
	dly_v = 0;
end

function [15:0] rd_word(input [1:0] b, input [12:0] r, input [9:0] c);
	reg [15:0] d;
	begin
		d = mem[{b, r[9:0], c[3:0]}];
		d = (d & ~STUCK_MASK) | (STUCK_VAL & STUCK_MASK);
		if (row_fault_en && BAD_ROW0 <= BAD_ROW1 && r >= BAD_ROW0 && r <= BAD_ROW1) d = d ^ (16'h1 << BAD_BIT);
		d = d ^ xor_mask;
		rd_word = d;
	end
endfunction

always @(posedge clk) begin
	// the data going out
	dq_oe  <= dly_v[0];
	dq_out <= dly_d[0];
	for (k = 0; k < 7; k = k + 1) begin
		dly_v[k] <= dly_v[k + 1];
		dly_d[k] <= dly_d[k + 1];
	end
	dly_v[7] <= 0;

	// banks closing after an auto precharge
	for (k = 0; k < 4; k = k + 1) if (close_in[k] != 0) begin
		close_in[k] <= close_in[k] - 1'd1;
		if (close_in[k] == 1) is_open[k] <= 0;
	end

	// a write goes on: one word a clock
	if (wr_left != 0) begin
		mem[{wr_ba, wr_row[9:0], wr_col[3:0] + (3'd4 - wr_left[2:0])}] <= dq;
		wr_left <= wr_left - 1'd1;
	end

	if (!cs_n) case ({ras_n, cas_n, we_n})
		3'b011: begin                                // ACTIVE
			if (is_open[ba]) begin errors = errors + 1; $display("%0t model: ACTIVE on a bank that is open (bank %0d)", $time, ba); end
			is_open[ba]  <= 1;
			row_open[ba] <= a;
		end
		3'b101: begin                                // READ
			reads = reads + 1;
			if (!is_open[ba]) begin errors = errors + 1; $display("%0t model: READ of a bank that is not open (bank %0d)", $time, ba); end
			for (k = 0; k < 4; k = k + 1) begin
				dly_v[cl + k - 1] <= 1;
				dly_d[cl + k - 1] <= rd_word(ba, row_open[ba], a[9:0] + k[9:0]);
			end
			if (a[10]) close_in[ba] <= 4'd6;
		end
		3'b100: begin                                // WRITE (the first word is on the bus now)
			writes = writes + 1;
			if (!is_open[ba]) begin errors = errors + 1; $display("%0t model: WRITE of a bank that is not open (bank %0d)", $time, ba); end
			mem[{ba, row_open[ba][9:0], a[3:0]}] <= dq;
			wr_left <= 4'd3;
			wr_ba   <= ba;
			wr_row  <= row_open[ba];
			wr_col  <= a[9:0];
			// (the next words follow at 1, 2 and 3 clocks: wr_left counts them, starting at the second word)
			if (a[10]) close_in[ba] <= 4'd6;
		end
		3'b010: begin                                // PRECHARGE
			if (a[10]) for (k = 0; k < 4; k = k + 1) is_open[k] <= 0;
			else is_open[ba] <= 0;
		end
		3'b001: refreshes = refreshes + 1;           // AUTO REFRESH
		3'b000: begin                                // LOAD MODE REGISTER
			cl = a[6:4];
			bl = (a[2:0] == 3'd2) ? 4 : (a[2:0] == 3'd1) ? 2 : (a[2:0] == 3'd3) ? 8 : 1;
			if (cl != 3 || bl != 4) begin errors = errors + 1; $display("%0t model: mode register CL=%0d BL=%0d (this model does CL3 BL4)", $time, cl, bl); end
		end
		default: ;
	endcase
end

endmodule
