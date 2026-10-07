// made by tools/make_clk.py from the original MemTest core's table: the 64 clocks of the SDRAM test, 167 MHz down to 45 MHz.
// freq10 is the clock in tenths of a MHz; m, k and c are the PLL settings that make it (the PLL is reconfigured with them).
module clk_steps
(
	input       [5:0] pos,
	output reg [11:0] freq10,
	output reg [31:0] m,
	output reg [31:0] k,
	output reg [31:0] c
);

always @* begin
	case (pos)
		6'd0: begin freq10 = 12'd1670; m = 32'h00808; k = 32'hB33332DD; c = 32'h20302; end
		6'd1: begin freq10 = 12'd1600; m = 32'h00808; k = 32'h00000001; c = 32'h20302; end
		6'd2: begin freq10 = 12'd1500; m = 32'h20807; k = 32'h00000001; c = 32'h20302; end
		6'd3: begin freq10 = 12'd1490; m = 32'h00404; k = 32'hF0A3D6B4; c = 32'h20201; end
		6'd4: begin freq10 = 12'd1480; m = 32'h00404; k = 32'hE147ADBF; c = 32'h20201; end
		6'd5: begin freq10 = 12'd1470; m = 32'h00404; k = 32'hD1EB851F; c = 32'h20201; end
		6'd6: begin freq10 = 12'd1460; m = 32'h00404; k = 32'hC28F5C29; c = 32'h20201; end
		6'd7: begin freq10 = 12'd1450; m = 32'h00404; k = 32'hB33332DD; c = 32'h20201; end
		6'd8: begin freq10 = 12'd1440; m = 32'h00404; k = 32'hA3D709E8; c = 32'h20201; end
		6'd9: begin freq10 = 12'd1430; m = 32'h00404; k = 32'h947AE148; c = 32'h20201; end
		6'd10: begin freq10 = 12'd1420; m = 32'h00404; k = 32'h851EB852; c = 32'h20201; end
		6'd11: begin freq10 = 12'd1410; m = 32'h00404; k = 32'h75C28F06; c = 32'h20201; end
		6'd12: begin freq10 = 12'd1400; m = 32'h00707; k = 32'h00000001; c = 32'h20302; end
		6'd13: begin freq10 = 12'd1390; m = 32'h00404; k = 32'h570A3D71; c = 32'h20201; end
		6'd14: begin freq10 = 12'd1380; m = 32'h00404; k = 32'h47AE147B; c = 32'h20201; end
		6'd15: begin freq10 = 12'd1370; m = 32'h00404; k = 32'h3851EA2E; c = 32'h20201; end
		6'd16: begin freq10 = 12'd1360; m = 32'h00404; k = 32'h28F5C239; c = 32'h20201; end
		6'd17: begin freq10 = 12'd1350; m = 32'h00404; k = 32'h1999999A; c = 32'h20201; end
		6'd18: begin freq10 = 12'd1340; m = 32'h00505; k = 32'hB851EB2F; c = 32'h00202; end
		6'd19: begin freq10 = 12'd1330; m = 32'h00505; k = 32'hA3D709E8; c = 32'h00202; end
		6'd20: begin freq10 = 12'd1320; m = 32'h00505; k = 32'h8F5C28F6; c = 32'h00202; end
		6'd21: begin freq10 = 12'd1310; m = 32'h00505; k = 32'h7AE14758; c = 32'h00202; end
		6'd22: begin freq10 = 12'd1300; m = 32'h00505; k = 32'h66666611; c = 32'h00202; end
		6'd23: begin freq10 = 12'd1290; m = 32'h00505; k = 32'h51EB851F; c = 32'h00202; end
		6'd24: begin freq10 = 12'd1280; m = 32'h00505; k = 32'h3D70A381; c = 32'h00202; end
		6'd25: begin freq10 = 12'd1270; m = 32'h00505; k = 32'h28F5C239; c = 32'h00202; end
		6'd26: begin freq10 = 12'd1260; m = 32'h00505; k = 32'h147AE148; c = 32'h00202; end
		6'd27: begin freq10 = 12'd1250; m = 32'h00505; k = 32'h00000001; c = 32'h00202; end
		6'd28: begin freq10 = 12'd1240; m = 32'h20504; k = 32'hEB851E62; c = 32'h00202; end
		6'd29: begin freq10 = 12'd1230; m = 32'h20504; k = 32'hD70A3D71; c = 32'h00202; end
		6'd30: begin freq10 = 12'd1220; m = 32'h20504; k = 32'hC28F5C29; c = 32'h00202; end
		6'd31: begin freq10 = 12'd1210; m = 32'h20504; k = 32'hAE147A8B; c = 32'h00202; end
		6'd32: begin freq10 = 12'd1200; m = 32'h00707; k = 32'h66666611; c = 32'h00303; end
		6'd33: begin freq10 = 12'd1100; m = 32'h20706; k = 32'h333332DD; c = 32'h00303; end
		6'd34: begin freq10 = 12'd1000; m = 32'h00404; k = 32'h00000001; c = 32'h00202; end
		6'd35: begin freq10 = 12'd900; m = 32'h00707; k = 32'h66666666; c = 32'h00404; end
		6'd36: begin freq10 = 12'd800; m = 32'h00707; k = 32'h66666666; c = 32'h20504; end
		6'd37: begin freq10 = 12'd700; m = 32'h00707; k = 32'h00000001; c = 32'h00505; end
		6'd38: begin freq10 = 12'd690; m = 32'h00404; k = 32'h47AE147B; c = 32'h00303; end
		6'd39: begin freq10 = 12'd680; m = 32'h00404; k = 32'h28F5C28F; c = 32'h00303; end
		6'd40: begin freq10 = 12'd670; m = 32'h00505; k = 32'hB851EB85; c = 32'h00404; end
		6'd41: begin freq10 = 12'd660; m = 32'h00505; k = 32'h8F5C28F6; c = 32'h00404; end
		6'd42: begin freq10 = 12'd650; m = 32'h20706; k = 32'h00000001; c = 32'h00505; end
		6'd43: begin freq10 = 12'd640; m = 32'h00606; k = 32'hCCCCCCCD; c = 32'h00505; end
		6'd44: begin freq10 = 12'd630; m = 32'h00606; k = 32'h9999999A; c = 32'h00505; end
		6'd45: begin freq10 = 12'd625; m = 32'h00404; k = 32'hC0000000; c = 32'h20403; end
		6'd46: begin freq10 = 12'd620; m = 32'h00606; k = 32'h66666666; c = 32'h00505; end
		6'd47: begin freq10 = 12'd610; m = 32'h00606; k = 32'h33333333; c = 32'h00505; end
		6'd48: begin freq10 = 12'd600; m = 32'h00404; k = 32'h66666611; c = 32'h20403; end
		6'd49: begin freq10 = 12'd590; m = 32'h00404; k = 32'h428F5C29; c = 32'h20403; end
		6'd50: begin freq10 = 12'd580; m = 32'h00404; k = 32'h1EB851EC; c = 32'h20403; end
		6'd51: begin freq10 = 12'd570; m = 32'h20504; k = 32'h1EB851EC; c = 32'h00404; end
		6'd52: begin freq10 = 12'd560; m = 32'h00505; k = 32'h147AE148; c = 32'h20504; end
		6'd53: begin freq10 = 12'd550; m = 32'h00404; k = 32'hCCCCCCCD; c = 32'h00404; end
		6'd54: begin freq10 = 12'd540; m = 32'h00404; k = 32'hA3D709E8; c = 32'h00404; end
		6'd55: begin freq10 = 12'd530; m = 32'h00404; k = 32'h7AE14758; c = 32'h00404; end
		6'd56: begin freq10 = 12'd520; m = 32'h00404; k = 32'h51EB851F; c = 32'h00404; end
		6'd57: begin freq10 = 12'd510; m = 32'h00404; k = 32'h28F5C239; c = 32'h00404; end
		6'd58: begin freq10 = 12'd500; m = 32'h00404; k = 32'h00000001; c = 32'h00404; end
		6'd59: begin freq10 = 12'd490; m = 32'h00404; k = 32'hD1EB851F; c = 32'h20504; end
		6'd60: begin freq10 = 12'd480; m = 32'h00404; k = 32'hA3D709E8; c = 32'h20504; end
		6'd61: begin freq10 = 12'd470; m = 32'h00404; k = 32'h75C28F06; c = 32'h20504; end
		6'd62: begin freq10 = 12'd460; m = 32'h00404; k = 32'h47AE147B; c = 32'h20504; end
		default: begin freq10 = 12'd450; m = 32'h00404; k = 32'h1999999A; c = 32'h20504; end
	endcase
end

endmodule
