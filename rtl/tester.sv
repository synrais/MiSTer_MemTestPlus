// Writes the whole area of the module with a data pattern, reads it back, compares, and starts again.
// The write / read / compare flow is that of MiSTer-devel/MemTest_MiSTer (rtl/tester.v, Copyright (C) 2017-2019 Sorgelig, GPL v2 or later).
//
// Patterns: random (the original), walking ones and zeros, each word's own address, a checkerboard that flips every word. Every pattern
// but random is inverted on every second pass, so that every cell is tried both ways.
// Counted since the test was restarted: failcount (words that came back wrong), dq_err (the data lines that were wrong), reg_done / reg_err
// (the area in 64 parts that were read / had errors), first_idx (the word number of the first error), and the groups of 128 rows that
// had errors.

module tester #(parameter SIM_N = 0, parameter RESET_CYCLES = 5000000)
(
	input             clk,
	input             rst_n,

	input       [1:0] sz,
	input       [1:0] chip,
	input       [2:0] pattern,     // 0 random, 1 walking, 2 address, 3 checkerboard, 4 all in turn

	output reg [31:0] passcount,
	output reg [31:0] failcount,
	output reg [15:0] dq_err,
	output reg [63:0] reg_done,
	output reg [63:0] reg_err,
	output reg        first_valid,
	output reg [25:0] first_idx,
	output reg [63:0] rowg_err,    // groups of 128 rows: rows 0 to 127, 128 to 255, ...

	output            DRAM_CLK,
	inout      [15:0] DRAM_DQ,
	output     [12:0] DRAM_ADDR,
	output            DRAM_LDQM, DRAM_UDQM,
	output            DRAM_WE_N,
	output            DRAM_CAS_N,
	output            DRAM_RAS_N,
	output            DRAM_CS_N,
	output            DRAM_BA_0,
	output            DRAM_BA_1
);

// ---- the data
reg  [16:0] lfsr = 17'h1ACE1, saved = 17'h1ACE1;
reg  [25:0] idx = 0, idx_n = 1;       // the word we are at, and the next one
reg  [15:0] gen = 0;                  // the pattern's data for idx (everything but random)
reg   [1:0] pat = 0;                  // 0 random, 1 walking, 2 address, 3 checkerboard
reg         inv = 0;                  // this pass is inverted

function [15:0] patdata(input [1:0] p, input [25:0] i, input invert);
	reg [15:0] base;
	begin
		case (p)
			2'd1:    base = i[4] ? ~(16'h0001 << i[3:0]) : (16'h0001 << i[3:0]);
			2'd2:    base = i[15:0] ^ {6'd0, i[25:16]};
			default: base = i[0] ? 16'hAAAA : 16'h5555;
		endcase
		patdata = invert ? ~base : base;
	end
endfunction

reg save, restore, load;              // one clock strobes
wire dram_ready;
wire [15:0] dram_rdat;

// The data of the current word goes out through registers of their own, one to the SDRAM (which sits next to the pins) and one for the compare.
wire [16:0] lfsr_next = {(lfsr[0] ^ lfsr[2] ^ !lfsr), lfsr[16:1]};
wire [16:0] lfsr_n    = restore ? saved : dram_ready ? lfsr_next : lfsr;
wire [15:0] gen_n     = load ? patdata(pat, 26'd0, inv) : dram_ready ? patdata(pat, idx_n, inv) : gen;
wire [15:0] out_n     = (pat == 2'd0) ? lfsr_n[15:0] : gen_n;
(* preserve *) reg [15:0] wdat_r = 0;
(* preserve *) reg [15:0] exp_r  = 0;
always @(posedge clk) begin
	wdat_r <= out_n;
	exp_r  <= out_n;
end

always @(posedge clk) begin
	if (dram_ready) begin             // a word was written or read
		idx   <= idx_n;
		idx_n <= idx_n + 1'd1;
		gen   <= patdata(pat, idx_n, inv);
		lfsr  <= lfsr_next;
	end
	if (save)    saved <= lfsr;
	if (restore) lfsr  <= saved;
	if (load) begin                   // the start of a write or a read: the first word again
		idx   <= 0;
		idx_n <= 1;
		gen   <= patdata(pat, 26'd0, inv);
	end
end

// ---- the SDRAM
reg dram_start, dram_rnw;
wire dram_done;
reg sdram_rst_n = 0;

sdram #(.SIM_N(SIM_N)) my_dram
(
	.rst_n(sdram_rst_n),
	.clk(clk),
	.sz(sz),
	.chip(chip),
	.start(dram_start),
	.rnw(dram_rnw),
	.done(dram_done),
	.ready(dram_ready),
	.rdat(dram_rdat),
	.wdat(wdat_r),
	.DRAM_CLK(DRAM_CLK),
	.DRAM_DQ(DRAM_DQ),
	.DRAM_ADDR(DRAM_ADDR),
	.DRAM_CS_N(DRAM_CS_N),
	.DRAM_RAS_N(DRAM_RAS_N),
	.DRAM_CAS_N(DRAM_CAS_N),
	.DRAM_WE_N(DRAM_WE_N),
	.DRAM_LDQM(DRAM_LDQM),
	.DRAM_UDQM(DRAM_UDQM),
	.DRAM_BA_0(DRAM_BA_0),
	.DRAM_BA_1(DRAM_BA_1)
);

// ---- the sequence
localparam RESET        = 4'h0;
localparam INIT1        = 4'h1;
localparam INIT2        = 4'h2;
localparam BEGIN_WRITE1 = 4'h3;
localparam BEGIN_WRITE2 = 4'h4;
localparam BEGIN_WRITE3 = 4'h5;
localparam BEGIN_WRITE4 = 4'h6;
localparam WRITE        = 4'h7;
localparam BEGIN_READ1  = 4'h8;
localparam BEGIN_READ2  = 4'h9;
localparam BEGIN_READ3  = 4'hA;
localparam BEGIN_READ4  = 4'hB;
localparam READ         = 4'hC;
localparam END_READ     = 4'hD;
localparam INC_PASSES   = 4'hE;

reg [3:0] curr_state = RESET, next_state;

always @* begin
	case (curr_state)
		RESET:        next_state = INIT1;
		INIT1:        next_state = dram_done ? INIT2 : INIT1;
		INIT2:        next_state = BEGIN_WRITE1;
		BEGIN_WRITE1: next_state = BEGIN_WRITE2;
		BEGIN_WRITE2: next_state = BEGIN_WRITE3;
		BEGIN_WRITE3: next_state = BEGIN_WRITE4;
		BEGIN_WRITE4: next_state = WRITE;
		WRITE:        next_state = dram_done ? BEGIN_READ1 : WRITE;
		BEGIN_READ1:  next_state = BEGIN_READ2;
		BEGIN_READ2:  next_state = BEGIN_READ3;
		BEGIN_READ3:  next_state = BEGIN_READ4;
		BEGIN_READ4:  next_state = READ;
		READ:         next_state = dram_done ? END_READ : READ;
		END_READ:     next_state = INC_PASSES;
		INC_PASSES:   next_state = BEGIN_WRITE1;
		default:      next_state = RESET;
	endcase
end

reg        check = 0;                 // errors are counted while this is set
reg        reset_req = 1;
reg [31:0] rst_cnt;

// the pattern of a pass, from the setting and the pass number
wire [1:0] pat_now = (pattern == 3'd4) ? passcount[1:0] : (pattern == 3'd0) ? 2'd0 : pattern[1:0];
wire       inv_now = (pat_now == 2'd0) ? 1'b0 : (pattern == 3'd4) ? passcount[2] : passcount[0];

always @(posedge clk) begin
	curr_state <= (reset_req & dram_done) ? RESET : next_state;
	save    <= 0;
	restore <= 0;
	load    <= 0;

	// the counts; a reset, below, wins over them
	if (e2) begin
		if (failcount != 32'hFFFFFFFE) failcount <= failcount + 1'd1;      // stops counting rather than wrapping round
		dq_err         <= dq_err | x2;
		reg_err[rg2]   <= 1'b1;
		rowg_err[rw2]  <= 1'b1;
		if (!first_valid) begin
			first_valid <= 1'b1;
			first_idx   <= ix2;
		end
	end
	if (v2) reg_done[rg2] <= 1'b1;

	if (~rst_n) begin
		reset_req <= 1;
		rst_cnt   <= 0;
	end

	if (~rst_n || reset_req) begin
		check       <= 0;
		passcount   <= 0;
		failcount   <= 0;
		dq_err      <= 0;
		reg_done    <= 0;
		reg_err     <= 0;
		rowg_err    <= 0;
		first_valid <= 0;
	end

	case (curr_state)
		RESET: begin
			check      <= 0;
			dram_start <= 0;
			reset_req  <= 0;
			sdram_rst_n<= 0;
			rst_cnt    <= 0;
			if (rst_cnt < RESET_CYCLES) begin
				rst_cnt    <= rst_cnt + 1;
				curr_state <= RESET;
			end
		end

		INIT1: begin
			dram_start  <= 0;
			sdram_rst_n <= 1;
		end

		BEGIN_WRITE1: begin
			pat      <= pat_now;
			inv      <= inv_now;
			save     <= 1;
			dram_rnw <= 0;
		end
		BEGIN_WRITE2: begin
			load       <= 1;
			dram_start <= 1;
		end
		BEGIN_WRITE3: dram_start <= 0;

		BEGIN_READ1: begin
			restore  <= 1;
			dram_rnw <= 1;
		end
		BEGIN_READ2: begin
			load       <= 1;
			dram_start <= 1;
		end
		BEGIN_READ3: begin
			dram_start <= 0;
			check      <= 1;
		end

		END_READ:   check <= 0;
		INC_PASSES: passcount <= passcount + 1'd1;
	endcase
end

// ---- the compare pipeline: 1 the word read and the one expected, 2 how it is wrong and where, then the counts above
reg        v1, v2, e2;
reg [15:0] rd1, ex1, x2;
reg [25:0] ix1, ix2;
reg  [5:0] rg2;
reg  [5:0] rw2;                       // the group of 128 rows of the word

wire [4:0]  area_bits = (SIM_N != 0) ? SIM_N[4:0] : (sz == 2'd3) ? ((chip == 2'd0) ? 5'd26 : 5'd25) : (sz == 2'd2) ? 5'd25 : 5'd24;
wire [25:0] rg_shift  = ix1 >> (area_bits - 5'd6);

always @(posedge clk) begin
	v1  <= check & dram_ready;
	rd1 <= dram_rdat;
	ex1 <= exp_r;
	ix1 <= idx;

	v2  <= v1;
	e2  <= v1 & (rd1 != ex1);
	x2  <= rd1 ^ ex1;
	ix2 <= ix1;
	rg2 <= rg_shift[5:0];
	rw2  <= ix1[16:11];
end

endmodule
