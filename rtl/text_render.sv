// MemTest+ text screen: 80 x 28 cells of 8 x 16 pixels (8 x 8 on a 15 kHz picture), 16 colours, centred in the 720 pixel picture.
//
// Cells are in a RAM that the composer fills (its write port is on the composer's clock). A cell is a character (a glyph of the font ROMs,
// which tools/make_ui.py made) and an attribute: background[7:4] and foreground[3:0], colours of the palette in ui_pal.vh.
//
// The picture runs through four pixel steps (every register, the memories too, on ce_pix): cell address, character and attribute,
// glyph row, colour. hs, vs and de are delayed to match.

module text_render
(
	input             clk,         // video clock
	input             ce_pix,
	input             tall,        // 16 line glyphs (480p / 576p); 0 = 8 line glyphs (240p / 288p)

	input             hs_in,
	input             vs_in,
	input             de_in,
	input       [9:0] x_in,
	input       [9:0] y_in,
	input       [9:0] lines_in,    // active lines

	// the cells: written by the composer
	input             wclk,
	input             we,
	input      [11:0] waddr,
	input       [7:0] wchar,
	input       [7:0] wattr,

	output reg        hs,
	output reg        vs,
	output reg        de,
	output reg  [7:0] r,
	output reg  [7:0] g,
	output reg  [7:0] b
);

`include "ui_pal.vh"

// ---- the cells: written as 80 x 28 in rows 128 apart, read for the picture
reg [7:0] cchar [0:4095];
reg [7:0] cattr [0:4095];
initial begin
	$readmemh("rtl/ui_char.hex", cchar);
	$readmemh("rtl/ui_attr.hex", cattr);
end
always @(posedge wclk) if (we) begin
	cchar[waddr] <= wchar;
	cattr[waddr] <= wattr;
end

// ---- the glyphs
reg [7:0] font16 [0:4095];
reg [7:0] font8  [0:2047];
initial begin
	$readmemh("rtl/font16.hex", font16);
	$readmemh("rtl/font8.hex",  font8);
end

// ---- where in the text the pixel is
wire [9:0] text_h = tall ? 10'd448 : 10'd224;
wire [9:0] ytop   = (lines_in - text_h) >> 1;
wire       in_x   = (x_in >= 10'd40) && (x_in < 10'd680);
wire       in_y   = (y_in >= ytop) && (y_in < ytop + text_h);
wire [9:0] tx     = x_in - 10'd40;
wire [9:0] ty     = y_in - ytop;
wire [4:0] row    = tall ? ty[8:4] : ty[7:3];
wire [6:0] col    = tx[9:3];

// Four steps, every register (the memories' too) moving on ce_pix only, so that it is the same at 15 and 31 kHz:
//   0 the cell's address   1 its character and attribute   2 the glyph row   3 the colour
reg  [11:0] a0;
reg   [2:0] px0, px1, px2;
reg   [3:0] gy0, gy1;
reg         in0, hs0, vs0, de0;
reg   [7:0] ch1, at1, at2, bits2;
reg         in1, hs1, vs1, de1;
reg         in2, hs2, vs2, de2;

always @(posedge clk) if (ce_pix) begin
	// 0
	a0   <= {row, col};
	px0  <= tx[2:0];
	gy0  <= tall ? ty[3:0] : {1'b0, ty[2:0]};
	in0  <= in_x && in_y && de_in;
	hs0  <= hs_in;
	vs0  <= vs_in;
	de0  <= de_in;

	// 1
	ch1  <= cchar[a0];
	at1  <= cattr[a0];
	px1  <= px0;
	gy1  <= gy0;
	in1  <= in0;
	hs1  <= hs0;
	vs1  <= vs0;
	de1  <= de0;

	// 2
	bits2 <= tall ? font16[{ch1, gy1}] : font8[{ch1, gy1[2:0]}];
	at2   <= at1;
	px2   <= px1;
	in2   <= in1;
	hs2   <= hs1;
	vs2   <= vs1;
	de2   <= de1;
end

// 3: the colour
wire        on  = bits2[3'd7 - px2];
wire [23:0] rgb = in2 ? ui_pal(on ? at2[3:0] : at2[7:4]) : (de2 ? ui_pal(4'd0) : 24'h000000);

always @(posedge clk) if (ce_pix) begin
	r  <= rgb[23:16];
	g  <= rgb[15:8];
	b  <= rgb[7:0];
	hs <= hs2;
	vs <= vs2;
	de <= de2;
end

endmodule
