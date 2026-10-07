// The word number in the area being tested as the chip, bank, row and column of the module. The controller (sdram.v) takes the address
// of a 4 word burst as [23] chip select, [22:15] column bits 9..2, [14:2] row, [1:0] bank (the word in the burst is column bits 1..0),
// and when only the second chip of a 128 MB module is tested (chip = 2) it starts at 24'h800000.

module err_locate
(
	input      [25:0] idx,
	input       [1:0] sz,
	input       [1:0] chip,

	output      [1:0] chip_no,    // 1 or 2 (the first or the second chip of a 128 MB module; 1 for the others)
	output      [1:0] bank,
	output     [12:0] row,
	output      [9:0] col
);

wire [23:0] burst = {idx[25:2]} + ((chip == 2'd2) ? 24'h800000 : 24'd0);

assign chip_no = (sz == 2'd3 && burst[23]) ? 2'd2 : 2'd1;
assign bank    = burst[1:0];
assign row     = burst[14:2];
assign col     = {burst[22:15], idx[1:0]};

endmodule
