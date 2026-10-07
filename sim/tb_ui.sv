// Simulation of the screen: video timing + composer + text renderer, with the #demo values of ui/layout.txt.
//   writes the third frame as a PPM, and measures the timing of the syncs:
//   iverilog -g2012 -I rtl -I sim -o sim/tb_ui.vvp sim/tb_ui.sv rtl/video_timing.sv rtl/text_render.sv rtl/ui_composer.sv
//   vvp sim/tb_ui.vvp +pal=0 +sd=1 +out=build/frame.ppm
`timescale 1ns/1ps

module tb_ui;

reg clk   = 0;      // video clock 27 MHz
reg clk50 = 0;      // the composer's clock
always #18.5185 clk   = ~clk;
always #10      clk50 = ~clk50;

integer pal_i = 0, sd_i = 1;
reg pal, sd;
reg [1023:0] outname;
integer fd = 0;
initial begin
	if (!$value$plusargs("pal=%d", pal_i)) pal_i = 0;
	if (!$value$plusargs("sd=%d", sd_i)) sd_i = 1;
	if (!$value$plusargs("out=%s", outname)) outname = "build/frame.ppm";
	pal = pal_i[0];
	sd  = sd_i[0];
end

wire        ce, hs, vs, de;
wire  [9:0] x, y, lines;
video_timing vt (.clk(clk), .pal(pal), .sd(sd), .ce_pix(ce), .hs(hs), .vs(vs), .de(de), .x(x), .y(y), .lines(lines));

`include "ui_demo.vh"
wire        we;
wire [11:0] waddr;
wire  [7:0] wchar, wattr;
ui_composer comp
(
	.clk(clk50),
`include "ui_conn.vh"
	.we(we), .waddr(waddr), .wchar(wchar), .wattr(wattr)
);

wire        hs_o, vs_o, de_o;
wire  [7:0] r, g, b;
text_render tr
(
	.clk(clk), .ce_pix(ce), .tall(lines >= 10'd400),
	.hs_in(hs), .vs_in(vs), .de_in(de), .x_in(x), .y_in(y), .lines_in(lines),
	.wclk(clk50), .we(we), .waddr(waddr), .wchar(wchar), .wattr(wattr),
	.hs(hs_o), .vs(vs_o), .de(de_o), .r(r), .g(g), .b(b)
);

// ---- measurements and the picture
integer frame = 0;
real t_hs_fall, t_vs_fall, hs_period, vs_period, hs_width, vs_width;
integer pix_in_line, lines_in_frame, last_pix, last_lines;
reg hs_d, vs_d, de_d;
reg capturing = 0;

initial begin
	hs_d = 1; vs_d = 1; de_d = 0; pix_in_line = 0; lines_in_frame = 0;
	#1;
end

always @(posedge clk) if (ce) begin
	hs_d <= hs_o; vs_d <= vs_o; de_d <= de_o;
	if (de_o) pix_in_line = pix_in_line + 1;
	if (de_d && !de_o) begin
		last_pix = pix_in_line;
		pix_in_line = 0;
		lines_in_frame = lines_in_frame + 1;
	end
	if (hs_d && !hs_o) begin
		hs_period = $realtime - t_hs_fall;
		t_hs_fall = $realtime;
	end
	if (!hs_d && hs_o) hs_width = $realtime - t_hs_fall;
	if (vs_d && !vs_o) begin
		vs_period = $realtime - t_vs_fall;
		t_vs_fall = $realtime;
		last_lines = lines_in_frame;
		lines_in_frame = 0;
		frame = frame + 1;
		if (capturing) begin
			$fclose(fd);
			capturing = 0;
			$display("timing: line %0.3f us (%0.3f kHz), hsync %0.3f us, active %0d pixels", hs_period / 1000.0, 1.0e6 / hs_period, hs_width / 1000.0, last_pix);
			$display("        frame %0.3f ms (%0.3f Hz), vsync %0.3f us, active %0d lines", vs_period / 1.0e6, 1.0e9 / vs_period, vs_width / 1000.0, last_lines);
			$finish;
		end
		if (frame == 3) begin
			fd = $fopen(outname, "w");
			$fwrite(fd, "P3\n720 %0d\n255\n", lines);
			capturing = 1;
		end
	end
	if (!vs_d && vs_o) vs_width = $realtime - t_vs_fall;
	if (capturing && de_o) $fwrite(fd, "%0d %0d %0d\n", r, g, b);
end

initial begin
	#400000000;       // 400 ms: more than enough for four frames
	$display("timed out");
	$finish;
end

endmodule
