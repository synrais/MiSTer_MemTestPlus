// made by tools/make_ui.py
function automatic [23:0] ui_pal(input [3:0] i);
	case (i)
		4'd0: ui_pal = 24'h090E20; // navy
		4'd1: ui_pal = 24'h1C3A78; // title
		4'd2: ui_pal = 24'hE2E9F6; // text
		4'd3: ui_pal = 24'h808FAF; // dim
		4'd4: ui_pal = 24'h54CCEC; // cyan
		4'd5: ui_pal = 24'h4AD670; // green
		4'd6: ui_pal = 24'hF45454; // red
		4'd7: ui_pal = 24'hFCC040; // amber
		4'd8: ui_pal = 24'h424D64; // grey
		4'd9: ui_pal = 24'h3E5E9C; // border
		default: ui_pal = 24'h000000;
	endcase
endfunction
