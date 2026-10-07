// Writes the fields of the screen that change (numbers, words, maps) into the character RAM of text_render, a cell at a time, going round
// the list made by tools/make_ui.py (rtl/ui_ops.hex). An operation is one 40 bit word: kind[39:36] source[35:30] address[29:18] width[17:11] aux[10:0].
//   number  (kind 0: leading zeros blank, kind 1: kept)  decimal digits; 32'hFFFFFFFF shows dashes; aux[0]: green from 130 and red below,
//                       aux[1]: the colour of the last number that had aux[0] (the decimal of a speed), aux[2]: left aligned,
//                       aux[3]: nothing is written when the number is 32'hFFFFFFFF
//   string  (kind 2)  one of the words of the field, in its own colour; a character 8'h00 is not written (the cell keeps what is there)
//   an address of 12'hFFF in the operation means: start at the cell after the last one written (a field that follows a word of unknown length)
//   map     (kind 3)  a row of cells, 2 bits each; aux[10:8] is the kind (1 address map, 2 data lines), aux[7:0] the distance between cells

module ui_composer
(
	input             clk,
`include "ui_ports.vh"
	output reg        new_pass,           // a pulse as the list is started again: what the fields follow is then kept for the whole pass
	output reg        we,
	output reg [11:0] waddr,
	output reg  [7:0] wchar,
	output reg  [7:0] wattr
);

`include "ui_defs.vh"

reg [127:0] ui_val;
reg   [5:0] ui_src;
`include "ui_src.vh"

reg  [7:0] static_attr [0:4095];     // the colours of the cells the fields are written over
reg  [7:0] strings     [0:2047];
reg  [7:0] strattr     [0:2047];
reg [39:0] ops         [0:63];
initial begin
	$readmemh("rtl/ui_attr.hex",    static_attr);
	$readmemh("rtl/ui_strings.hex", strings);
	$readmemh("rtl/ui_strattr.hex", strattr);
	$readmemh("rtl/ui_ops.hex",     ops);
end

localparam S_FETCH = 4'd0, S_WAIT = 4'd1, S_DECODE = 4'd2, S_DABBLE = 4'd3, S_CELL = 4'd4, S_WRITE = 4'd5, S_NEXT = 4'd6;

reg  [3:0] state = S_FETCH;
reg  [5:0] opi = 0;
reg [39:0] op;
wire [3:0]  kind  = op[39:36];
wire [11:0] base  = op[29:18];
wire [6:0]  width = op[17:11];
wire [10:0] aux   = op[10:0];

reg [127:0] mapv;
reg  [31:0] value;
reg  [39:0] bcd;
reg  [31:0] sh;
reg   [5:0] cnt;
reg   [6:0] i;
reg  [11:0] addr;
reg  [11:0] last = 0;                 // the cell after the last one written
reg         seen, none, hot;
reg   [7:0] stattr_q, sattr_q, schar_q;
reg   [3:0] lz;                       // the zeros in front of the number (it is shifted left by them when it is left aligned)

// one step of the double dabble: add 3 to every digit of 5 or more
function [39:0] add3(input [39:0] b);
	integer k;
	begin
		add3 = b;
		for (k = 0; k < 10; k = k + 1)
			if (b[k*4 +: 4] >= 5) add3[k*4 +: 4] = b[k*4 +: 4] + 4'd3;
	end
endfunction

function [3:0] map_colour(input [2:0] mk, input [1:0] st);
	if (mk == 3'd2) map_colour = (st == 2'd0) ? UI_C_GREEN : UI_C_RED;
	else            map_colour = (st == 2'd0) ? UI_C_GREY : (st == 2'd1) ? UI_C_GREEN : UI_C_RED;
endfunction

// the zeros in front of the number, all but the last digit
function [3:0] lead(input [39:0] b, input [6:0] w);
	integer q;
	reg     go;
	begin
		lead = 0;
		go   = 1;
		for (q = 9; q >= 0; q = q - 1)
			if (go && q < w) begin
				if (b[q*4 +: 4] == 4'd0 && q != 0) lead = lead + 1'd1;
				else go = 0;
			end
	end
endfunction

wire [10:0] sidx = aux + value[10:0] * width + i;     // the character of the word in the string table
wire        skip = (kind == 4'd2) ? (schar_q == 8'h00) : (kind[3:1] == 0 && aux[3] && none);     // this cell is left as it is

always @(posedge clk) begin
	we       <= 0;
	new_pass <= 0;
	ui_src <= op[35:30];

	case (state)
		S_FETCH: begin
			op    <= ops[opi];
			if (opi == 0) new_pass <= 1;
			state <= S_WAIT;
		end

		S_WAIT: state <= S_DECODE;                    // the source number reaches the value multiplexer

		S_DECODE: begin
			value <= ui_val[31:0];
			mapv  <= ui_val;
			none  <= (ui_val[31:0] == 32'hFFFFFFFF) && (kind[3:1] == 0);
			if (aux[0]) hot <= (ui_val[31:0] >= 130);
			i     <= 0;
			seen  <= 0;
			addr  <= (base == 12'hFFF) ? last : base;
			bcd   <= 0;
			sh    <= ui_val[31:0];
			cnt   <= 0;
			state <= (kind[3:1] == 0 && ui_val[31:0] != 32'hFFFFFFFF) ? S_DABBLE : S_CELL;
		end

		S_DABBLE: begin
			{bcd, sh} <= {add3(bcd), sh} << 1;
			cnt       <= cnt + 1'd1;
			if (cnt == 31) state <= S_CELL;
		end

		S_CELL: begin                                 // look up what the cell needs
			stattr_q <= static_attr[addr];
			sattr_q  <= strattr[sidx];
			schar_q  <= strings[sidx];
			lz       <= lead(bcd, width);
			state    <= S_WRITE;
		end

		S_WRITE: begin
			we    <= !skip;
			if (!skip) last <= addr + 1'd1;
			waddr <= addr;
			case (kind)
				4'd0, 4'd1: begin
					begin : digit
						reg [6:0] k;
						reg [3:0] d;
						k = i + (aux[2] ? lz : 4'd0);
						d = bcd[(width - 1 - k) * 4 +: 4];
						if (none) wchar <= "-";
						else if (k >= width) wchar <= 8'h20;
						else begin
							wchar <= ((kind == 4'd0) && !aux[2] && !seen && d == 0 && i != width - 1) ? 8'h20 : (8'h30 + d);
							if (d != 0) seen <= 1;
						end
					end
					wattr <= (aux[1:0] != 0 && !none) ? {stattr_q[7:4], hot ? UI_C_GREEN : UI_C_RED} : stattr_q;
				end
				4'd2: begin
					wchar <= schar_q;
					wattr <= sattr_q;
				end
				default: begin
					wchar <= UI_G_CELL;
					wattr <= {stattr_q[7:4], map_colour(aux[10:8], mapv[i*2 +: 2])};
				end
			endcase
			state <= S_NEXT;
		end

		S_NEXT: begin
			i    <= i + 1'd1;
			addr <= addr + ((kind == 4'd3) ? aux[7:0] : 12'd1);
			if (i + 1'd1 >= width) begin
				opi   <= (opi + 1'd1 >= UI_OPS) ? 6'd0 : opi + 1'd1;
				state <= S_FETCH;
			end else state <= S_CELL;
		end

	endcase
end

endmodule
