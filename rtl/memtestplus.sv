// MemTest+ for MiSTer: SDRAM module test with a screen that says what it is looking at.
//
// A new core, not a fork. The write / read / compare flow and the table of PLL clocks are from MiSTer-devel/MemTest_MiSTer
// by Sorgelig (GPL v2 or later); the screen, video timing, patterns, error finding and scan are new.
//
// Clock domains: CLK_50M (keys, scan, timers, screen text), clk_ram (SDRAM clock, 167 down to 45 MHz via PLL reconfiguration:
// the tester) and videoclk (27 MHz: video timing and renderer). The tester's counts reach CLK_50M through a request / acknowledge
// handshake, so a number is never read half changed.

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;

assign VGA_SL         = 0;
assign VGA_F1         = 0;
assign VGA_SCALER     = 0;
assign VGA_DISABLE    = 0;
assign VIDEO_ARX      = 13'd4;
assign VIDEO_ARY      = 13'd3;
assign HDMI_FREEZE    = 0;
assign HDMI_BLACKOUT  = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S   = 0;
assign AUDIO_L   = 0;
assign AUDIO_R   = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign LED_USER  = 0;
assign BUTTONS   = 0;

assign SDRAM_CKE = 1;

`include "build_id.v"
localparam CONF_STR =
{
	"MemTestPlus;;",
	"O[4:2],Pattern,Random,Walking 1/0,Address,Checkerboard,All in turn;",
	"O[7:5],Test time,10 min,1 min,2 min,5 min,30 min,60 min;",
	"O[10:8],Video,Auto,NTSC 480p,NTSC 240p,PAL 576p,PAL 288p;",
	"O[12:11],Chips,Both,1,2;",
	"-;",
	"T[0],Restart auto scan;",
	"J1,Auto scan;",
	"jn,B;",
	"jp,A;",
	"V,v",`BUILD_DATE
};

wire [127:0] status;
wire   [1:0] buttons;
wire  [10:0] ps2_key;
wire  [31:0] joystick_0;
wire  [15:0] sdram_sz;
wire         forced_scandoubler;
wire [127:0] status_next;             // the menu with the previous / next Chips choice (left / right keys)
reg          chip_set = 0, chip_back = 0;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(CLK_50M),
	.HPS_BUS(HPS_BUS),

	.status(status),
	.status_in(status_next),
	.status_set(chip_set),
	.status_menumask(16'd0),
	.buttons(buttons),
	.sdram_sz(sdram_sz),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joystick_0),
	.ps2_key(ps2_key),
	.ps2_kbd_led_use(3'd0),
	.ps2_kbd_led_status(3'd0)
);

// SIM (simulation): a second is 1000 clocks, the test area is small and the waits are short
`ifdef SIM
localparam [25:0] SEC_END    = 26'd999;
localparam [26:0] T_RECFG    = 27'd2000;
localparam [26:0] T_RESET    = 27'd4000;
localparam [15:0] SETTLE_END = 16'd20000;
`else
localparam [25:0] SEC_END    = 26'd49999999;
localparam [26:0] T_RECFG    = 27'd1000000;
localparam [26:0] T_RESET    = 27'd100000000;
localparam [15:0] SETTLE_END = 16'hFFFF;
`endif

localparam [11:0] GOOD_CLOCK = 12'd1300;        // good boards are stable from 130.0 MHz

localparam [2:0] R_TESTING = 3'd0, R_PASS = 3'd1, R_SLOW = 3'd2, R_FAIL = 3'd3, R_NO_MODULE = 3'd4;
localparam [4:0] M_PASS = 5'd0, M_SLOW = 5'd1, M_FAIL_ALL = 5'd2, M_NO_MODULE = 5'd3, M_ERRORS_HERE = 5'd4, M_TEST_AUTO = 5'd5, M_TEST_HAND = 5'd11;

// ---- the settings of the menu
wire [1:0] sz      = sdram_sz[15] ? sdram_sz[1:0] : 2'd0;           // 0 none, 1 32 MB, 2 64 MB, 3 128 MB
wire [2:0] pat_set = (status[4:2] > 3'd4) ? 3'd0 : status[4:2];     // 0 random, 1 walking, 2 address, 3 checkerboard, 4 all in turn
wire [1:0] chip    = (sz == 2'd3 && status[12:11] != 2'd3) ? status[12:11] : 2'd0;   // 0 both chips of a 128 MB module, 1 first, 2 second
assign status_next = {status[127:13], chip_back ? ((chip == 2'd0) ? 2'd2 : chip - 1'd1) : ((chip == 2'd2) ? 2'd0 : chip + 1'd1), status[10:0]};

reg [2:0] stab;                                                      // test length: 0 to 5 = 1, 2, 5, 10, 30, 60 min
always @* begin
	case (status[7:5])
		3'd1:    stab = 3'd0;
		3'd2:    stab = 3'd1;
		3'd3:    stab = 3'd2;
		3'd4:    stab = 3'd4;
		3'd5:    stab = 3'd5;
		default: stab = 3'd3;
	endcase
end

reg [5:0] stab_mins;
always @* begin
	case (stab)
		3'd0:    stab_mins = 6'd1;
		3'd1:    stab_mins = 6'd2;
		3'd2:    stab_mins = 6'd5;
		3'd3:    stab_mins = 6'd10;
		3'd4:    stab_mins = 6'd30;
		default: stab_mins = 6'd60;
	endcase
end

reg [1:0] vcode;                                                     // {50 Hz, 31 kHz}: 0 NTSC 240p, 1 NTSC 480p, 2 PAL 288p, 3 PAL 576p
always @* begin
	case (status[10:8])
		3'd1:    vcode = 2'd1;
		3'd2:    vcode = 2'd0;
		3'd3:    vcode = 2'd3;
		3'd4:    vcode = 2'd2;
		default: vcode = {1'b0, forced_scandoubler};
	endcase
end

// ---- the SDRAM clock
reg   [5:0] pos = 0;                  // the step of the clock table: 0 is 167 MHz, 63 is 45 MHz
wire [11:0] freq10;                   // the clock in tenths of a MHz
wire [31:0] cfg_m, cfg_k, cfg_c;

clk_steps clk_steps (.pos(pos), .freq10(freq10), .m(cfg_m), .k(cfg_k), .c(cfg_c));

wire clk_ram, locked, pll_reset;
wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;

pll pll
(
	.*,
	.refclk(CLK_50M),
	.rst(pll_reset | RESET),
	.outclk_0(clk_ram)
);

wire        mgmt_waitrequest;
wire        mgmt_write;
wire  [5:0] mgmt_address;
wire [31:0] mgmt_writedata;

pll_cfg pll_cfg
(
	.*,
	.mgmt_clk(CLK_50M),
	.mgmt_reset(RESET),
	.mgmt_read(1'b0),
	.mgmt_readdata()
);

reg  rec_start = 0;                   // a pulse: set the clock of step pos and restart the test
wire rc_busy;

pll_recfg pll_recfg
(
	.clk(CLK_50M),
	.start(rec_start),
	.locked(locked),
	.waitrequest(mgmt_waitrequest),
	.m(cfg_m),
	.k(cfg_k),
	.c(cfg_c),
	.write(mgmt_write),
	.address(mgmt_address),
	.writedata(mgmt_writedata),
	.pll_reset(pll_reset),
	.busy(rc_busy)
);

wire busy_any = rec_start | rc_busy;

// ---- the tester, held in reset while the clock is set and when there is no module
reg  [1:0] recfg_s = 2'b11, lock_s = 2'b00, rst_s = 2'b11, hold_q = 2'b11;
reg [26:0] timeout = T_RECFG;
reg        reset = 1;

always @(posedge clk_ram) begin
	recfg_s <= {recfg_s[0], busy_any};
	lock_s  <= {lock_s[0], locked};
	rst_s   <= {rst_s[0], RESET};
	hold_q  <= {hold_q[0], (sz == 2'd0)};

	if (timeout) timeout <= timeout - 1'd1;
	reset <= (|timeout) | hold_q[1];

	if ((recfg_s[1] || ~lock_s[1]) && timeout < T_RECFG) timeout <= T_RECFG;
	if (rst_s[1]) timeout <= T_RESET;
end

wire [31:0] passcount, failcount;
wire [15:0] dq_err;
wire [63:0] reg_done, reg_err;
wire        first_valid;
wire [25:0] first_idx;
wire [63:0] rowg_err;

`ifdef SIM
tester #(.SIM_N(14), .RESET_CYCLES(200)) my_memtst
`else
tester my_memtst
`endif
(
	.clk(clk_ram),
	.rst_n(~reset),
	.sz(sz),
	.chip(chip),
	.pattern(pat_set),

	.passcount(passcount),
	.failcount(failcount),
	.dq_err(dq_err),
	.reg_done(reg_done),
	.reg_err(reg_err),
	.first_valid(first_valid),
	.first_idx(first_idx),
	.rowg_err(rowg_err),

	.DRAM_CLK(SDRAM_CLK),
	.DRAM_DQ(SDRAM_DQ),
	.DRAM_ADDR(SDRAM_A),
	.DRAM_LDQM(SDRAM_DQML),
	.DRAM_UDQM(SDRAM_DQMH),
	.DRAM_WE_N(SDRAM_nWE),
	.DRAM_CS_N(SDRAM_nCS),
	.DRAM_RAS_N(SDRAM_nRAS),
	.DRAM_CAS_N(SDRAM_nCAS),
	.DRAM_BA_0(SDRAM_BA[0]),
	.DRAM_BA_1(SDRAM_BA[1])
);

// ---- what the tester counted, to CLK_50M: request / acknowledge
reg         req_t = 0, ack_t = 0;
reg   [1:0] req_s = 0, ack_s = 0;

reg  [31:0] sn_pass, sn_fail;
reg  [15:0] sn_dq;
reg  [63:0] sn_done, sn_err;
reg         sn_fv;
reg  [25:0] sn_fidx;
reg  [63:0] sn_rowg;

always @(posedge clk_ram) begin
	req_s <= {req_s[0], req_t};
	if (req_s[1] != ack_t) begin
		sn_pass <= passcount;
		sn_fail <= failcount;
		sn_dq   <= dq_err;
		sn_done <= reg_done;
		sn_err  <= reg_err;
		sn_fv   <= first_valid;
		sn_fidx <= first_idx;
		sn_rowg <= rowg_err;
		ack_t   <= req_s[1];
	end
end

reg  [15:0] settle = 0;               // the clock was set a moment ago: for a millisecond the numbers are not trusted
wire        live = (settle == SETTLE_END) && (sz != 2'd0);

reg  [31:0] s_pass = 0, s_fail = 0;
reg  [15:0] s_dq = 0;
reg  [63:0] s_done = 0, s_err = 0;
reg         s_fv = 0;
reg  [25:0] s_fidx = 0;
reg  [63:0] s_rowg = 0;
reg         pend = 0, req_fresh = 0, snap_new = 0, snap_ok = 0;

always @(posedge CLK_50M) begin
	ack_s    <= {ack_s[0], ack_t};
	snap_new <= 0;

	if (busy_any) settle <= 0;
	else if (settle != SETTLE_END) settle <= settle + 1'd1;

	if (ack_s[1] == req_t) begin
		if (pend) begin
			s_pass   <= sn_pass;
			s_fail   <= sn_fail;
			s_dq     <= sn_dq;
			s_done   <= sn_done;
			s_err    <= sn_err;
			s_fv     <= sn_fv;
			s_fidx   <= sn_fidx;
			s_rowg   <= sn_rowg;
			snap_new <= 1;
			snap_ok  <= req_fresh && live;
			pend     <= 0;
		end else begin
			req_t     <= ~req_t;
			req_fresh <= live;
			pend      <= 1;
		end
	end
end

// ---- the control: keys, the scan, the timers
reg [127:0] st = 0;                   // for every step of the clock table, 2 bits: 0 not tested, 1 passed, 2 errors
reg         auto = 1;                 // the auto scan (from 167 MHz downwards), or the clock as set by hand
reg         scan_fail = 0;            // the auto scan got to the lowest clock and still had errors
reg         fresh = 0;                // a snapshot of this clock's run has arrived since the clock was set
reg         seen_err = 0;             // errors were seen at this clock, in the pass pass_at_err: the scan goes on when that pass is over
reg  [31:0] pass_at_err = 0;
reg         rw_en = 0;                // write the record of step rw_step (what the snapshot s_* says)
reg   [5:0] rw_step = 0;

reg  [25:0] tick_t = 0, tick_c = 0;
reg   [5:0] ts = 0, tm = 0, cs = 0;
reg   [6:0] th = 0, cm = 0;
reg   [5:0] rm = 6'd10, rs = 0;       // time left of the test at this clock (counts down while cm, cs count up)

reg         old_stb = 0, old_trig = 0;
reg  [31:0] old_joy = 0;
reg   [2:0] old_patv = 0, old_stab = 0;
reg   [1:0] old_chip = 0;
reg   [1:0] old_sz = 0;

always @(posedge CLK_50M) begin
	reg ev_up, ev_dn, ev_auto, ev_left, ev_right, go_clock, go_clear;

	rec_start <= 0;
	rw_en     <= 0;
	ev_up = 0; ev_dn = 0; ev_auto = 0; ev_left = 0; ev_right = 0; go_clock = 0; go_clear = 0;

	old_stb  <= ps2_key[10];
	old_joy  <= joystick_0;
	old_trig <= status[0] | buttons[1];
	old_patv <= pat_set;
	old_stab <= stab;
	old_chip <= chip;
	old_sz   <= sz;

	if (old_stb != ps2_key[10] && ps2_key[9]) begin
		case (ps2_key[7:0])
			8'h75: ev_up      = 1;
			8'h72: ev_dn      = 1;
			8'h6B: ev_left    = 1;
			8'h74: ev_right   = 1;
			8'h32: ev_auto    = 1;                // B
			8'h5A: ev_auto    = 1;                // Enter
		endcase
	end
	if (~old_joy[3] && joystick_0[3]) ev_up      = 1;
	if (~old_joy[2] && joystick_0[2]) ev_dn      = 1;
	if (~old_joy[1] && joystick_0[1]) ev_left    = 1;
	if (~old_joy[0] && joystick_0[0]) ev_right   = 1;
	if (~old_joy[4] && joystick_0[4]) ev_auto    = 1;
	if (~old_trig && (status[0] | buttons[1])) ev_auto = 1;

	if (ev_up && pos > 0) begin
		pos      <= pos - 1'd1;
		auto     <= 0;
		go_clock  = 1;
	end
	if (ev_dn && pos < 63) begin
		pos      <= pos + 1'd1;
		auto     <= 0;
		go_clock  = 1;
	end
	if (ev_auto) begin
		pos      <= 0;
		auto     <= 1;
		go_clear  = 1;
	end
	chip_set  <= (ev_left || ev_right) && sz == 2'd3;
	chip_back <= ev_left;
	if (old_patv != pat_set || old_stab != stab || old_chip != chip || old_sz != sz) begin
		if (auto) pos <= 0;
		go_clear = 1;
	end

	// what the test found at this clock
	if (!go_clock && !go_clear && snap_new && snap_ok && live) begin
		fresh <= 1;
		if (s_fail != 0) begin
			st[pos*2 +: 2] <= 2'd2;
			rw_en   <= 1;
			rw_step <= pos;
			if (!seen_err) begin
				seen_err    <= 1;
				pass_at_err <= s_pass;
			end else if (auto && s_pass != pass_at_err) begin
				if (pos < 63) begin
					pos      <= pos + 1'd1;
					go_clock  = 1;
				end else scan_fail <= 1;
			end
		end else if (s_pass != 0 && rm == 0 && rs == 0) begin
			if (st[pos*2 +: 2] == 2'd0) st[pos*2 +: 2] <= 2'd1;
		end
	end

	// the time, while the test is running
	if (live) begin
		tick_t <= tick_t + 1'd1;
		if (tick_t == SEC_END) begin
			tick_t <= 0;
			if (ts == 6'd59) begin
				ts <= 0;
				if (tm == 6'd59) begin
					tm <= 0;
					if (th != 7'd99) th <= th + 1'd1;
				end else tm <= tm + 1'd1;
			end else ts <= ts + 1'd1;
		end

		tick_c <= tick_c + 1'd1;
		if (tick_c == SEC_END) begin
			tick_c <= 0;
			if (cs == 6'd59) begin
				cs <= 0;
				if (cm != 7'd99) cm <= cm + 1'd1;
			end else cs <= cs + 1'd1;
			if (rs != 0) rs <= rs - 1'd1;
			else if (rm != 0) begin
				rm <= rm - 1'd1;
				rs <= 6'd59;
			end
		end
	end

	if (s_fail != 0) begin                // stable for: the time without errors at this clock
		tick_c <= 0;
		cs     <= 0;
		cm     <= 0;
		rm     <= stab_mins;
		rs     <= 0;
	end

	if (go_clock || go_clear) begin
		seen_err  <= 0;
		fresh     <= 0;
		rec_start <= 1;
		tick_c    <= 0;
		cs        <= 0;
		cm        <= 0;
		rm        <= stab_mins;
		rs        <= 0;
	end
	if (go_clear) begin
		st        <= 0;
		scan_fail <= 0;
		tick_t    <= 0;
		ts        <= 0;
		tm        <= 0;
		th        <= 0;
	end
end

// ---- the best clock: the fastest that passed
reg       best_ok;
reg [5:0] best_pos;
integer   bi;
always @* begin
	best_ok  = 0;
	best_pos = 0;
	for (bi = 63; bi >= 0; bi = bi - 1)
		if (st[bi*2 +: 2] == 2'd1) begin
			best_ok  = 1;
			best_pos = bi[5:0];
		end
end

wire [11:0] best10;
clk_steps clk_best (.pos(best_pos), .freq10(best10), .m(), .k(), .c());

// ---- the result and its words
wire [1:0] cur_st = st[pos*2 +: 2];

reg [2:0] result;
reg [4:0] msg;
always @* begin
	result = R_TESTING;
	msg    = M_TEST_AUTO + stab;
	if (sz == 2'd0) begin
		result = R_NO_MODULE;
		msg    = M_NO_MODULE;
	end else if (auto) begin
		if (scan_fail) begin
			result = R_FAIL;
			msg    = M_FAIL_ALL;
		end else if (best_ok) begin
			result = (best10 >= GOOD_CLOCK) ? R_PASS : R_SLOW;
			msg    = (best10 >= GOOD_CLOCK) ? M_PASS : M_SLOW;
		end
	end else begin
		msg = M_TEST_HAND + stab;
		if (cur_st == 2'd1) begin
			result = (freq10 >= GOOD_CLOCK) ? R_PASS : R_SLOW;
			msg    = (freq10 >= GOOD_CLOCK) ? M_PASS : M_SLOW;
		end else if (cur_st == 2'd2) begin
			result = R_FAIL;
			msg    = M_ERRORS_HERE;
		end
	end
end

// ---- the weak links: what went wrong at the clocks that failed
wire [191:0] ms_f10;
wire         lim_ok, lim_fv;
wire  [11:0] lim_f10, wo_f10;
wire  [15:0] lim_mask;
wire  [63:0] lim_rowg;
wire  [25:0] lim_fidx;

weak_links weak_links
(
	.clk(CLK_50M),
	.st(st),
	.wr_en(rw_en),
	.wr_step(rw_step),
	.wr_pass(s_pass != 0),
	.wr_dq(s_dq),
	.wr_rowg(s_rowg),
	.wr_fv(s_fv),
	.wr_fidx(s_fidx),
	.cur_step(pos),
	.cur_dq(s_dq),
	.cur_pass(fresh && s_pass != 0),
	.ms_f10(ms_f10),
	.lim_ok(lim_ok),
	.lim_f10(lim_f10),
	.lim_mask(lim_mask),
	.lim_rowg(lim_rowg),
	.lim_fv(lim_fv),
	.lim_fidx(lim_fidx),
	.wo_f10(wo_f10)
);

reg  [3:0] lowest;                    // the lowest numbered line that limits the clock
integer    ki;
always @* begin
	lowest = 0;
	for (ki = 15; ki >= 0; ki = ki - 1)
		if (lim_mask[ki]) lowest = ki[3:0];
end

// where the errors of the limit were: the number of groups of 128 rows, the first and the last
reg  [6:0] rg_n;
reg  [5:0] rg_lo, rg_hi;
integer    gi;
always @* begin
	rg_n  = 0;
	rg_lo = 0;
	rg_hi = 0;
	for (gi = 63; gi >= 0; gi = gi - 1)
		if (lim_rowg[gi]) begin
			rg_n  = rg_n + 1'd1;
			rg_lo = gi[5:0];
		end
	for (gi = 0; gi < 64; gi = gi + 1)
		if (lim_rowg[gi]) rg_hi = gi[5:0];
end
wire area_one = (rg_n != 0) && (rg_n <= 7'd8) && ((rg_hi - rg_lo) <= 6'd15);   // one area: at most 8 row groups, none more than 16 groups apart

wire  [1:0] e_chip_no, e_bank;
wire [12:0] e_row;
wire  [9:0] e_col;

err_locate err_locate (.idx(lim_fidx), .sz(sz), .chip(chip), .chip_no(e_chip_no), .bank(e_bank), .row(e_row), .col(e_col));

// ---- the values the screen shows (32'hFFFFFFFF shows dashes)
localparam [31:0] NONE = 32'hFFFFFFFF;

// the message and the fields after it must agree for a whole composer pass, so they read these
wire        ui_new;
reg         testing_q = 0;
reg   [4:0] msg_q     = 0;
always @(posedge CLK_50M) if (ui_new) begin
	testing_q <= (result == R_TESTING);
	msg_q     <= msg;
end

reg [127:0] v_adrmap, v_dqmap;
integer     vi;
always @* begin
	v_adrmap = 128'd0;
	v_dqmap  = 128'd0;
	for (vi = 0; vi < 64; vi = vi + 1)
		v_adrmap[vi*2 +: 2] = s_err[vi] ? 2'd2 : s_done[vi] ? 2'd1 : 2'd0;
	for (vi = 0; vi < 16; vi = vi + 1)         // a data line is red until it has worked at a clock, then green
		v_dqmap[vi*2 +: 2] = (ms_f10[vi*12 +: 12] != 12'd0) ? 2'd0 : 2'd2;
end

wire        have   = (sz != 2'd0);
wire        l_have = have && lim_ok;
wire        e_have = l_have && lim_fv;

function [31:0] ms_value(input [11:0] f10);
	ms_value = (have && f10 != 12'd0) ? f10 / 12'd10 : NONE;
endfunction

wire [31:0] v_size    = {30'd0, sz};
wire [31:0] v_chips   = {30'd0, (sz == 2'd3) ? chip : 2'd3};
wire [31:0] v_pattern = {29'd0, pat_set};
wire [31:0] v_video   = {30'd0, vcode};
wire [31:0] v_clock   = freq10 / 12'd10;
wire [31:0] v_mode    = {31'd0, ~auto};
wire [31:0] v_stab    = {29'd0, stab};
wire [31:0] v_th      = {25'd0, th};
wire [31:0] v_tm      = {26'd0, tm};
wire [31:0] v_ts      = {26'd0, ts};
wire [31:0] v_cm      = {25'd0, cm};
wire [31:0] v_cs      = {26'd0, cs};
wire [31:0] v_passes  = have ? s_pass : 32'd0;
wire [31:0] v_errors  = have ? s_fail : 32'd0;
wire [31:0] v_errtag  = {31'd0, have && (s_fail != 0)};
wire [31:0] v_best    = best_ok ? best10 / 12'd10 : NONE;
wire [31:0] v_result  = {29'd0, result};
wire [31:0] v_rm      = testing_q ? {26'd0, rm} : NONE;
wire [31:0] v_rs      = testing_q ? {26'd0, rs} : NONE;
wire [31:0] v_msg     = {27'd0, msg_q};

// what follows the message while testing: the clock, " MHz clock", the time left and " remaining"
wire [31:0] v_ci = testing_q ? v_clock : NONE;
wire [31:0] v_ct = {31'd0, testing_q};
wire [31:0] v_rc = {31'd0, testing_q};
wire [31:0] v_rt = {31'd0, testing_q};

wire [31:0] v_ms0  = ms_value(ms_f10[0*12 +: 12]);
wire [31:0] v_ms1  = ms_value(ms_f10[1*12 +: 12]);
wire [31:0] v_ms2  = ms_value(ms_f10[2*12 +: 12]);
wire [31:0] v_ms3  = ms_value(ms_f10[3*12 +: 12]);
wire [31:0] v_ms4  = ms_value(ms_f10[4*12 +: 12]);
wire [31:0] v_ms5  = ms_value(ms_f10[5*12 +: 12]);
wire [31:0] v_ms6  = ms_value(ms_f10[6*12 +: 12]);
wire [31:0] v_ms7  = ms_value(ms_f10[7*12 +: 12]);
wire [31:0] v_ms8  = ms_value(ms_f10[8*12 +: 12]);
wire [31:0] v_ms9  = ms_value(ms_f10[9*12 +: 12]);
wire [31:0] v_ms10 = ms_value(ms_f10[10*12 +: 12]);
wire [31:0] v_ms11 = ms_value(ms_f10[11*12 +: 12]);
wire [31:0] v_ms12 = ms_value(ms_f10[12*12 +: 12]);
wire [31:0] v_ms13 = ms_value(ms_f10[13*12 +: 12]);
wire [31:0] v_ms14 = ms_value(ms_f10[14*12 +: 12]);
wire [31:0] v_ms15 = ms_value(ms_f10[15*12 +: 12]);

wire [31:0] v_wl      = l_have ? {28'd0, lowest} : NONE;
wire [31:0] v_fails   = l_have ? lim_f10 / 12'd10 : NONE;
wire [31:0] v_without = l_have ? wo_f10 / 12'd10 : NONE;
wire [31:0] v_wav     = {30'd0, !l_have ? 2'd0 : area_one ? 2'd1 : 2'd2};
wire [31:0] v_e_chip  = e_have ? {30'd0, e_chip_no} : NONE;
wire [31:0] v_e_bank  = e_have ? {30'd0, e_bank}    : NONE;
wire [31:0] v_e_row   = e_have ? {19'd0, e_row}     : NONE;
wire [31:0] v_e_col   = e_have ? {22'd0, e_col}     : NONE;

// ---- the screen: the text (written by the composer at 50 MHz), the video timing and the renderer (27 MHz)
wire        ui_we;
wire [11:0] ui_waddr;
wire  [7:0] ui_wchar, ui_wattr;

ui_composer ui_composer
(
	.clk(CLK_50M),
`include "ui_conn.vh"
	.new_pass(ui_new),
	.we(ui_we),
	.waddr(ui_waddr),
	.wchar(ui_wchar),
	.wattr(ui_wattr)
);

wire videoclk;

vpll vpll
(
	.refclk(CLK_50M),
	.rst(1'b0),
	.outclk_0(videoclk)
);

reg [1:0] vc1 = 0, vc2 = 0;
always @(posedge videoclk) begin
	vc1 <= vcode;
	vc2 <= vc1;
end

wire        t_ce, t_hs, t_vs, t_de;
wire  [9:0] t_x, t_y, t_lines;

video_timing video_timing
(
	.clk(videoclk),
	.pal(vc2[1]),
	.sd(vc2[0]),
	.ce_pix(t_ce),
	.hs(t_hs),
	.vs(t_vs),
	.de(t_de),
	.x(t_x),
	.y(t_y),
	.lines(t_lines)
);

text_render text_render
(
	.clk(videoclk),
	.ce_pix(t_ce),
	.tall(vc2[0]),

	.hs_in(t_hs),
	.vs_in(t_vs),
	.de_in(t_de),
	.x_in(t_x),
	.y_in(t_y),
	.lines_in(t_lines),

	.wclk(CLK_50M),
	.we(ui_we),
	.waddr(ui_waddr),
	.wchar(ui_wchar),
	.wattr(ui_wattr),

	.hs(VGA_HS),
	.vs(VGA_VS),
	.de(VGA_DE),
	.r(VGA_R),
	.g(VGA_G),
	.b(VGA_B)
);

assign CLK_VIDEO = videoclk;
assign CE_PIXEL  = t_ce;

endmodule
