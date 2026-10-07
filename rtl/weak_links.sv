// What went wrong at the clocks that failed, kept for every step of the clock table.
//
// The control writes a record for the clock under test whenever it has errors. This module reads the records again and again and works out
//   ms_f10[l]   per data line, the clock where it first worked: the first tested clock after the last one where it was wrong (0: not yet)
//   lim_*       the limit: the slowest clock that failed, and what was wrong at it
//   wo_f10      "without it": the first clock where every line other than the limit's lines is fine (the step after the last one where
//               one of them was wrong; the first clock tested if none was)
// st holds 2 bits per step: 0 not tested, 1 passed, 2 errors. A step with errors is only trusted for the lines that were clean when a
// whole pass had finished (the record's pass bit). The clock under test counts as a step of its own once its first pass is done.

module weak_links
(
	input              clk,
	input      [127:0] st,

	input              wr_en,
	input        [5:0] wr_step,
	input              wr_pass,
	input       [15:0] wr_dq,
	input       [63:0] wr_rowg,
	input              wr_fv,
	input       [25:0] wr_fidx,

	input        [5:0] cur_step,
	input       [15:0] cur_dq,
	input              cur_pass,

	output reg [191:0] ms_f10,        // 16 x 12 bits, line 0 in the lowest bits
	output reg         lim_ok,
	output reg  [11:0] lim_f10,
	output reg  [15:0] lim_mask,
	output reg  [63:0] lim_rowg,
	output reg         lim_fv,
	output reg  [25:0] lim_fidx,
	output reg  [11:0] wo_f10
);

reg [107:0] rec [0:63];
reg   [5:0] ra = 0;
reg [107:0] rq = 0;

always @(posedge clk) begin
	if (wr_en) rec[wr_step] <= {wr_pass, wr_dq, wr_rowg, wr_fv, wr_fidx};
	rq <= rec[ra];
end

wire [15:0] q_dq   = rq[106:91];
wire [63:0] q_rowg = rq[90:27];
wire        q_fv   = rq[26];
wire [25:0] q_fidx = rq[25:0];
wire        q_pass = rq[107];

reg   [5:0] i = 0;
wire [11:0] f10;
clk_steps clk_i (.pos(i), .freq10(f10), .m(), .k(), .c());

wire [1:0] sti = st[i*2 +: 2];

localparam [3:0] S_A_ADDR = 4'd0, S_A_WAIT = 4'd1, S_A_USE = 4'd2, S_B_ADDR = 4'd3, S_B_WAIT = 4'd4, S_B_USE = 4'd5, S_DONE = 4'd6;
reg [3:0] state = S_A_ADDR;

reg [191:0] acc_ms;
reg         acc_lim_ok;
reg  [11:0] acc_lim_f10;
reg  [15:0] acc_lim_mask;
reg  [63:0] acc_lim_rowg;
reg         acc_lim_fv;
reg  [25:0] acc_lim_fidx;
reg         acc_oth_ok;
reg  [11:0] acc_oth_f10;
reg         acc_first_ok;
reg  [11:0] acc_first_f10;
reg         after_oth;                 // the step just visited had errors on a line other than the limit's

integer l;
reg     bad, clean;

always @(posedge clk) begin
	case (state)
		// pass A: where every line first worked, and the limit
		S_A_ADDR: begin
			ra    <= i;
			state <= S_A_WAIT;
		end
		S_A_WAIT: state <= S_A_USE;
		S_A_USE: begin
			for (l = 0; l < 16; l = l + 1) begin
				bad   = 0;
				clean = 0;
				if (sti == 2'd2) begin
					bad   = q_dq[l];
					clean = q_pass && !q_dq[l];
				end else if (sti == 2'd1) begin
					clean = 1;
				end else if (i == cur_step && cur_pass) begin
					bad   = cur_dq[l];
					clean = !cur_dq[l];
				end
				if (bad) acc_ms[l*12 +: 12] <= 12'd0;
				else if (clean && acc_ms[l*12 +: 12] == 12'd0) acc_ms[l*12 +: 12] <= f10;
			end
			if (sti == 2'd2) begin
				acc_lim_ok   <= 1;
				acc_lim_f10  <= f10;
				acc_lim_mask <= q_dq;
				acc_lim_rowg <= q_rowg;
				acc_lim_fv   <= q_fv;
				acc_lim_fidx <= q_fidx;
			end
			if (i == 6'd63) begin
				i     <= 0;
				state <= S_B_ADDR;
			end else begin
				i     <= i + 1'd1;
				state <= S_A_ADDR;
			end
		end

		// pass B: the clock after the last one where a line other than the limit's was wrong, and the first clock tested
		S_B_ADDR: begin
			ra    <= i;
			state <= S_B_WAIT;
		end
		S_B_WAIT: state <= S_B_USE;
		S_B_USE: begin
			if (sti != 2'd0 && !acc_first_ok) begin
				acc_first_ok  <= 1;
				acc_first_f10 <= f10;
			end
			if (after_oth) begin
				acc_oth_f10 <= f10;
				after_oth   <= 0;
			end
			if (sti == 2'd2 && (q_dq & ~acc_lim_mask) != 16'd0) begin
				acc_oth_ok  <= 1;
				acc_oth_f10 <= f10;
				after_oth   <= 1;
			end
			if (i == 6'd63) begin
				i     <= 0;
				state <= S_DONE;
			end else begin
				i     <= i + 1'd1;
				state <= S_B_ADDR;
			end
		end

		// the results change all at once
		S_DONE: begin
			ms_f10   <= acc_ms;
			lim_ok   <= acc_lim_ok;
			lim_f10  <= acc_lim_f10;
			lim_mask <= acc_lim_mask;
			lim_rowg <= acc_lim_rowg;
			lim_fv   <= acc_lim_fv;
			lim_fidx <= acc_lim_fidx;
			wo_f10   <= acc_oth_ok ? acc_oth_f10 : acc_first_f10;
			acc_ms        <= 192'd0;
			acc_lim_ok    <= 0;
			acc_lim_f10   <= 0;
			acc_lim_mask  <= 0;
			acc_lim_rowg  <= 0;
			acc_lim_fv    <= 0;
			acc_lim_fidx  <= 0;
			acc_oth_ok    <= 0;
			acc_oth_f10   <= 0;
			acc_first_ok  <= 0;
			acc_first_f10 <= 0;
			after_oth     <= 0;
			state         <= S_A_ADDR;
		end

	endcase
end

initial begin
	acc_ms = 0; acc_lim_ok = 0; acc_lim_f10 = 0; acc_lim_mask = 0; acc_lim_rowg = 0;
	acc_lim_fv = 0; acc_lim_fidx = 0; acc_oth_ok = 0; acc_oth_f10 = 0; acc_first_ok = 0; acc_first_f10 = 0; after_oth = 0;
	ms_f10 = 0; lim_ok = 0; lim_f10 = 0; lim_mask = 0; lim_rowg = 0; lim_fv = 0; lim_fidx = 0; wo_f10 = 0;
end

endmodule
