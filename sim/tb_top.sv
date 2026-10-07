// The whole core in the simulator (framework and PLLs replaced by sim/stubs.sv, the SDRAM by sim/sdram_model.sv).
// The memory is made to fail while the clock step is below 5 (as if 167 .. 148 MHz were too fast for it), the way a real module can.
`timescale 1ns/1ps

module tb_top;

reg CLK_50M = 0;
always #10 CLK_50M = ~CLK_50M;
reg RESET = 1;
initial #400 RESET = 0;

`include "tb_top_ports.vh"

emu dut
(
`include "tb_top_conn.vh"
);

reg inject_all = 0;
reg [1:0] fault_mode = 0;    // 0: data bit 0 wrong below step 5   1: a weak line (DQ5 wrong down to step 4, DQ9 and DQ0 only down to step 2)   2: a few bad rows (and DQ3) below step 5
wire [15:0] xm = inject_all ? 16'hFFFF :
                 (fault_mode == 0) ? ((dut.pos < 6'd5) ? 16'h0001 : 16'h0000) :
                 (fault_mode == 1) ? ((dut.pos < 6'd3) ? 16'h0221 : (dut.pos < 6'd5) ? 16'h0020 : 16'h0000) : 16'h0000;
wire rfe = (fault_mode == 2) && (dut.pos < 6'd5);

sdram_model #(.BAD_ROW0(300), .BAD_ROW1(303), .BAD_BIT(3)) mem
(
	.clk(SDRAM_CLK), .xor_mask(xm), .row_fault_en(rfe), .cs_n(SDRAM_nCS), .ras_n(SDRAM_nRAS), .cas_n(SDRAM_nCAS), .we_n(SDRAM_nWE),
	.ba(SDRAM_BA), .a(SDRAM_A), .dq(SDRAM_DQ)
);

task press(input [7:0] code);
	begin
		dut.hps_io.ps2_key = {~dut.hps_io.ps2_key[10], 1'b1, 1'b0, code};
		#1000;
	end
endtask

task show(input [255:0] tag);
	begin
		$display("[%0t us] %0s: pos=%0d (%0d.%0d MHz) auto=%0d result=%0d msg=%0d st[0..9]=%0d%0d%0d%0d%0d%0d%0d%0d%0d%0d best_ok=%0d best=%0d time=%0d:%0d:%0d at_clock=%0d:%0d passes=%0d errors=%0d live=%0d scan_fail=%0d",
			$time / 1000, tag, dut.pos, dut.freq10 / 10, dut.freq10 % 10, dut.auto, dut.result, dut.msg,
			dut.st[1:0], dut.st[3:2], dut.st[5:4], dut.st[7:6], dut.st[9:8], dut.st[11:10], dut.st[13:12], dut.st[15:14], dut.st[17:16], dut.st[19:18],
			dut.best_ok, dut.best10, dut.th, dut.tm, dut.ts, dut.cm, dut.cs, dut.s_pass, dut.s_fail, dut.live, dut.scan_fail);
		$display("      countdown: v_rm=%0d v_rs=%0d (result %0d)", dut.v_rm, dut.v_rs, dut.result);
		$display("      limit: ok=%0d f10=%0d mask=%04h lowest=%0d  without it: f10=%0d  area: rowg=%016h one=%0d lo=%0d hi=%0d  first: valid=%0d idx=%0d",
			dut.lim_ok, dut.lim_f10, dut.lim_mask, dut.lowest, dut.wo_f10, dut.lim_rowg, dut.area_one, dut.rg_lo, dut.rg_hi, dut.lim_fv, dut.lim_fidx);
		$display("      max speed per line (15..0): %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
			dut.ms_f10[191:180], dut.ms_f10[179:168], dut.ms_f10[167:156], dut.ms_f10[155:144], dut.ms_f10[143:132], dut.ms_f10[131:120], dut.ms_f10[119:108], dut.ms_f10[107:96],
			dut.ms_f10[95:84], dut.ms_f10[83:72], dut.ms_f10[71:60], dut.ms_f10[59:48], dut.ms_f10[47:36], dut.ms_f10[35:24], dut.ms_f10[23:12], dut.ms_f10[11:0]);
	end
endtask

// what is on the screen, as text (box and block glyphs as #)
task screen;
	integer r, c;
	reg [7:0] ch;
	begin
		for (r = 0; r < 28; r = r + 1) begin
			for (c = 0; c < 80; c = c + 1) begin
				ch = dut.text_render.cchar[r * 128 + c];
				if (ch >= 8'h20 && ch < 8'h7F) $write("%c", ch); else $write("#");
			end
			$write("\n");
		end
	end
endtask

// the message line must end where it should: blank after its text up to the cell before the right edge, and the edge itself as on the other lines
task check_edge;
	integer c;
	reg     bad;
	begin
		bad = (dut.text_render.cchar[21 * 128 + 79] != dut.text_render.cchar[23 * 128 + 79]);
		for (c = 60; c < 79; c = c + 1) if (dut.text_render.cchar[21 * 128 + c] != 8'h20) bad = 1;
		$display("message line edge: %0s", bad ? "BAD" : "ok");
	end
endtask

// the colour (foreground index, as a hex digit) of the cells of a map row, to see what the map shows
task colours(input integer r, input integer c0, input integer n, input integer step);
	integer i;
	begin
		for (i = 0; i < n; i = i + 1) $write("%h", dut.text_render.cattr[r * 128 + c0 + i * step][3:0]);
		$write("\n");
	end
endtask

task look(input [255:0] tag);
	begin
		#300000;                                  // (the composer takes about 100 us to go round the whole screen)
		show(tag);
		screen;
		check_edge;
		$write("address map colours "); colours(19, 8, 64, 1);
		$write("data line colours   "); colours(14, 9, 16, 4);
	end
endtask

task wait_for(input integer what, input integer limit_us);
	integer t;
	begin
		t = 0;
		while (t < limit_us && !((what == 1 && dut.result == 3'd1) || (what == 2 && dut.result == 3'd3) || (what == 3 && dut.st[15:14] == 2'd1) || (what == 4 && dut.result == 3'd4))) begin
			#1000;
			t = t + 1;
		end
		if (t >= limit_us) $display("   (gave up waiting after %0d us)", limit_us);
	end
endtask

initial begin
	#2000;
	dut.hps_io.status[7:5] = 3'd1;        // stable time 1 min
	$display("scenario 1: auto scan, memory fails above step 5");
	wait_for(1, 40000);
	look("after the scan");

	$display("scenario 2: manual, DOWN twice (pos 5 -> 7), wait for the stable time at step 7 (st[7])");
	press(8'h72);
	press(8'h72);
	show("after DOWN DOWN");
	wait_for(3, 20000);
	show("manual, stable");

	$display("scenario 2b: the memory starts failing at the manual clock");
	inject_all = 1;
	#1500000;
	show("manual, errors");
	inject_all = 0;

	$display("scenario 3: B, the memory fails at every clock");
	inject_all = 1;
	press(8'h32);
	wait_for(2, 90000);
	look("scan, all fail");
	inject_all = 0;

	$display("scenario 4: no module");
	dut.hps_io.sdram_sz = 16'h8000;
	wait_for(4, 2000);
	look("no module");

	$display("scenario 5: a module again, the pattern is changed to ALL IN TURN: the test starts again");
	dut.hps_io.sdram_sz = 16'h8001;
	#200000;
	dut.hps_io.status[4:2] = 3'd4;
	#2000;
	show("pattern changed");
	wait_for(1, 40000);
	look("after the new scan");

	$display("scenario 6: 128 MB module: the menu option Chips (both / 1 / 2), and the keys right and left, which go round them through the menu");
	dut.hps_io.sdram_sz = 16'h8003;
	#200000;
	show("128 MB");
	dut.hps_io.status[12:11] = 2'd1; #2000; $display("   menu Chips = 1: chip=%0d v_chips=%0d", dut.chip, dut.v_chips);
	dut.hps_io.status[12:11] = 2'd2; #2000; $display("   menu Chips = 2: chip=%0d v_chips=%0d", dut.chip, dut.v_chips);
	press(8'h74); #2000; $display("   key right: chip=%0d v_chips=%0d (menu bits %0d)", dut.chip, dut.v_chips, dut.hps_io.status[12:11]);
	press(8'h74); #2000; $display("   key right: chip=%0d v_chips=%0d (menu bits %0d)", dut.chip, dut.v_chips, dut.hps_io.status[12:11]);
	press(8'h74); #2000; $display("   key right: chip=%0d v_chips=%0d (menu bits %0d)", dut.chip, dut.v_chips, dut.hps_io.status[12:11]);
	press(8'h6B); #2000; $display("   key left: chip=%0d v_chips=%0d (menu bits %0d)", dut.chip, dut.v_chips, dut.hps_io.status[12:11]);
	press(8'h6B); #2000; $display("   key left: chip=%0d v_chips=%0d (menu bits %0d)", dut.chip, dut.v_chips, dut.hps_io.status[12:11]);
	press(8'h6B); #2000; $display("   key left: chip=%0d v_chips=%0d (menu bits %0d)", dut.chip, dut.v_chips, dut.hps_io.status[12:11]);
	dut.hps_io.status[12:11] = 2'd0;

	$display("scenario 8: a weak line: DQ5 is wrong down to 148 MHz, DQ9 and DQ0 only down to 150 MHz, from 149 MHz on only DQ5 -> expect limit DQ5, without it 150.0 (the last other line wrong)");
	dut.hps_io.status[4:2] = 3'd0;
	fault_mode = 1;
	dut.hps_io.joystick_0 = 32'h10; #2000; dut.hps_io.joystick_0 = 0; #2000;
	wait_for(1, 60000);
	look("weak line");

	$display("scenario 9: bad rows 300..303 (and DQ3) below step 5 -> expect one area (the row group 2)");
	fault_mode = 2;
	dut.hps_io.joystick_0 = 32'h10; #2000; dut.hps_io.joystick_0 = 0; #2000;
	wait_for(1, 60000);
	look("bad rows");
	fault_mode = 0;

	$display("scenario 7: the pad: UP and DOWN (joystick bits 3 and 2), LEFT and RIGHT (bits 1 and 0) and the button");
	wait_for(1, 40000);
	dut.hps_io.joystick_0 = 32'h4; #2000; dut.hps_io.joystick_0 = 0; #2000;
	show("pad down");
	dut.hps_io.joystick_0 = 32'h8; #2000; dut.hps_io.joystick_0 = 0; #2000;
	show("pad up");
	dut.hps_io.joystick_0 = 32'h1; #2000; dut.hps_io.joystick_0 = 0; #2000;
	$display("   pad right: chip=%0d v_chips=%0d (menu bits %0d)", dut.chip, dut.v_chips, dut.hps_io.status[12:11]);
	dut.hps_io.joystick_0 = 32'h2; #2000; dut.hps_io.joystick_0 = 0; #2000;
	$display("   pad left: chip=%0d v_chips=%0d (menu bits %0d)", dut.chip, dut.v_chips, dut.hps_io.status[12:11]);
	dut.hps_io.joystick_0 = 32'h4; #2000; dut.hps_io.joystick_0 = 0; #2000;
	press(8'h5A); #2000; $display("   key ENTER: auto=%0d pos=%0d", dut.auto, dut.pos);
	$finish;
end

initial begin
	#400000000;
	$display("TIMEOUT");
	$finish;
end

endmodule
