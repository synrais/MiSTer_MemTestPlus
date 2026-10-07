// Simulation of the tester against the behavioural SDRAM (a small area, 2^14 words):
//   iverilog -g2012 -I rtl -P tb_tester.PATTERN=1 -P tb_tester.STUCK_MASK=8 ... -o sim/tb_tester.vvp sim/tb_tester.sv sim/sdram_model.sv sim/altera_stub.v rtl/tester.sv rtl/sdram.v rtl/err_locate.sv
`timescale 1ns/1ps

module tb_tester
#(
	parameter [15:0] STUCK_MASK = 16'h0000,
	parameter [15:0] STUCK_VAL  = 16'h0000,
	parameter        BAD_ROW0   = 1,
	parameter        BAD_ROW1   = 0,
	parameter        BAD_BIT    = 5,
	parameter  [2:0] PATTERN    = 3'd0,
	parameter        PASSES     = 4
);

reg clk = 0;
always #5 clk = ~clk;
reg rst_n = 0;
initial begin
	#300 rst_n = 1;
end

wire [31:0] passcount, failcount;
wire [15:0] dq_err;
wire [63:0] reg_done, reg_err;
wire        first_valid;
wire [25:0] first_idx;
wire [63:0] rowg_err;

wire        DRAM_CLK, DRAM_LDQM, DRAM_UDQM, DRAM_WE_N, DRAM_CAS_N, DRAM_RAS_N, DRAM_CS_N, DRAM_BA_0, DRAM_BA_1;
wire [12:0] DRAM_ADDR;
wire [15:0] DRAM_DQ;

tester #(.SIM_N(14), .RESET_CYCLES(200)) dut
(
	.clk(clk), .rst_n(rst_n), .sz(2'd1), .chip(2'd0), .pattern(PATTERN),
	.passcount(passcount), .failcount(failcount), .dq_err(dq_err), .reg_done(reg_done), .reg_err(reg_err),
	.first_valid(first_valid), .first_idx(first_idx), .rowg_err(rowg_err),
	.DRAM_CLK(DRAM_CLK), .DRAM_DQ(DRAM_DQ), .DRAM_ADDR(DRAM_ADDR), .DRAM_LDQM(DRAM_LDQM), .DRAM_UDQM(DRAM_UDQM),
	.DRAM_WE_N(DRAM_WE_N), .DRAM_CAS_N(DRAM_CAS_N), .DRAM_RAS_N(DRAM_RAS_N), .DRAM_CS_N(DRAM_CS_N),
	.DRAM_BA_0(DRAM_BA_0), .DRAM_BA_1(DRAM_BA_1)
);

sdram_model #(.STUCK_MASK(STUCK_MASK), .STUCK_VAL(STUCK_VAL), .BAD_ROW0(BAD_ROW0), .BAD_ROW1(BAD_ROW1), .BAD_BIT(BAD_BIT)) mem
(
	.clk(DRAM_CLK), .xor_mask(16'h0), .row_fault_en(1'b1), .cs_n(DRAM_CS_N), .ras_n(DRAM_RAS_N), .cas_n(DRAM_CAS_N), .we_n(DRAM_WE_N),
	.ba({DRAM_BA_1, DRAM_BA_0}), .a(DRAM_ADDR), .dq(DRAM_DQ)
);

wire [1:0] e_chip, e_bank;
wire [12:0] e_row;
wire [9:0] e_col;
err_locate loc (.idx(first_idx), .sz(2'd1), .chip(2'd0), .chip_no(e_chip), .bank(e_bank), .row(e_row), .col(e_col));

integer pats_seen [0:3];
integer i;
initial for (i = 0; i < 4; i = i + 1) pats_seen[i] = 0;
reg [31:0] last_pass = 0;
always @(posedge clk) if (passcount != last_pass) begin
	last_pass <= passcount;
	if (passcount != 0) pats_seen[dut.pat] <= pats_seen[dut.pat] + 1;
end

initial begin
	#200000000;
	$display("RESULT timeout passes=%0d", passcount);
	$finish;
end

always @(posedge clk) if (passcount >= PASSES) begin
	$display("RESULT rowg=%016h", rowg_err);
	$display("RESULT pattern=%0d passes=%0d fails=%0d dq_err=%04h done=%016h err=%016h first=%0d at chip %0d bank %0d row %0d col %0d model_errors=%0d refreshes=%0d reads=%0d writes=%0d seen=%0d/%0d/%0d/%0d",
		PATTERN, passcount, failcount, dq_err, reg_done, reg_err, first_valid ? first_idx : -1, e_chip, e_bank, e_row, e_col,
		mem.errors, mem.refreshes, mem.reads, mem.writes, pats_seen[0], pats_seen[1], pats_seen[2], pats_seen[3]);
	$finish;
end

endmodule
