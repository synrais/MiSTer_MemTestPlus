// MemTest+ video timing: NTSC and PAL, 15 kHz (240p / 288p) and 31 kHz (480p / 576p).
//
// clk is 27 MHz. At 31 kHz a pixel is one clock; at 15 kHz it is two (13.5 MHz pixels, as in BT.601). 720 pixels across.
//
//                     NTSC 480p   NTSC 240p   PAL 576p    PAL 288p
//   pixels per line   858         858         864         864
//   lines per frame   525         262         625         312
//   active lines      480         240         576         288
//   horizontal sync   62          62          64          64        (pixels, after a front porch of 16 / 16 / 12 / 12)
//   vertical sync     6           3           5           3         (lines,  after a front porch of  9 /  4 /  5 /  3)
//   line rate         31.469 kHz  15.734 kHz  31.250 kHz  15.625 kHz
//   frame rate        59.94 Hz    60.05 Hz    50.00 Hz    50.08 Hz
//
// Both syncs are negative. x and y count the active picture; de is high inside it. All outputs change on a pixel (ce_pix).

module video_timing
(
	input             clk,        // 27 MHz
	input             pal,        // 1 = 50 Hz
	input             sd,         // 1 = 31 kHz (480p / 576p), 0 = 15 kHz (240p / 288p)

	output reg        ce_pix,     // a new pixel
	output reg        hs,         // negative
	output reg        vs,         // negative
	output reg        de,
	output reg [9:0]  x,          // 0..719 in the active picture
	output reg [9:0]  y,          // 0..active lines - 1
	output     [9:0]  lines       // active lines of this mode: 240, 288, 480 or 576
);

wire [9:0] h_total  = pal ? 10'd864 : 10'd858;
wire [9:0] h_sync0  = pal ? 10'd732 : 10'd736;                  // where the sync starts
wire [9:0] h_sync1  = pal ? 10'd796 : 10'd798;                  // and where it ends (the first pixel after it)

// lines: active, front porch, sync, total
reg [9:0] v_act, v_fp, v_sync, v_tot;
always @* begin
	case ({pal, sd})
		2'b00: begin v_act = 240; v_fp = 4; v_sync = 3; v_tot = 262; end   // NTSC 240p
		2'b01: begin v_act = 480; v_fp = 9; v_sync = 6; v_tot = 525; end   // NTSC 480p
		2'b10: begin v_act = 288; v_fp = 3; v_sync = 3; v_tot = 312; end   // PAL 288p
		2'b11: begin v_act = 576; v_fp = 5; v_sync = 5; v_tot = 625; end   // PAL 576p
	endcase
end
assign lines = v_act;

reg [9:0] hc = 0, vc = 0;
reg       half = 0;

always @(posedge clk) begin
	// the pixel enable: every clock at 31 kHz, every other one at 15 kHz
	half   <= ~half;
	ce_pix <= sd ? 1'b1 : half;

	if (ce_pix) begin
		hc <= (hc == h_total - 1'd1) ? 10'd0 : hc + 1'd1;
		if (hc == h_total - 1'd1) vc <= (vc >= v_tot - 1'd1) ? 10'd0 : vc + 1'd1;

		// the picture
		x  <= (hc < 720) ? hc : 10'd0;
		y  <= (vc < v_act) ? vc : 10'd0;
		de <= (hc < 720) && (vc < v_act);

		// the syncs (negative: low while they last)
		hs <= ~((hc >= h_sync0) && (hc < h_sync1));
		vs <= ~((vc >= v_act + v_fp) && (vc < v_act + v_fp + v_sync));
	end
end

endmodule
