// made by tools/make_ui.py: which signal each field reads
localparam UI_OPS = 52;
always @* begin
	ui_val = 128'd0;
	case (ui_src)
		0: ui_val = {96'd0, v_size};
		1: ui_val = {96'd0, v_chips};
		2: ui_val = {96'd0, v_clock};
		3: ui_val = {96'd0, v_pattern};
		4: ui_val = {96'd0, v_mode};
		5: ui_val = {96'd0, v_video};
		6: ui_val = {96'd0, v_th};
		7: ui_val = {96'd0, v_tm};
		8: ui_val = {96'd0, v_ts};
		9: ui_val = {96'd0, v_passes};
		10: ui_val = {96'd0, v_cm};
		11: ui_val = {96'd0, v_cs};
		12: ui_val = {96'd0, v_errors};
		13: ui_val = {96'd0, v_errtag};
		14: ui_val = {96'd0, v_stab};
		15: ui_val = {96'd0, v_result};
		16: ui_val = {96'd0, v_rm};
		17: ui_val = {96'd0, v_rs};
		18: ui_val = {96'd0, v_best};
		19: ui_val = v_dqmap;
		20: ui_val = {96'd0, v_ms0};
		21: ui_val = {96'd0, v_ms1};
		22: ui_val = {96'd0, v_ms2};
		23: ui_val = {96'd0, v_ms3};
		24: ui_val = {96'd0, v_ms4};
		25: ui_val = {96'd0, v_ms5};
		26: ui_val = {96'd0, v_ms6};
		27: ui_val = {96'd0, v_ms7};
		28: ui_val = {96'd0, v_ms8};
		29: ui_val = {96'd0, v_ms9};
		30: ui_val = {96'd0, v_ms10};
		31: ui_val = {96'd0, v_ms11};
		32: ui_val = {96'd0, v_ms12};
		33: ui_val = {96'd0, v_ms13};
		34: ui_val = {96'd0, v_ms14};
		35: ui_val = {96'd0, v_ms15};
		36: ui_val = {96'd0, v_wl};
		37: ui_val = {96'd0, v_fails};
		38: ui_val = {96'd0, v_without};
		39: ui_val = {96'd0, v_e_chip};
		40: ui_val = {96'd0, v_e_bank};
		41: ui_val = {96'd0, v_e_row};
		42: ui_val = {96'd0, v_e_col};
		43: ui_val = {96'd0, v_wav};
		44: ui_val = v_adrmap;
		45: ui_val = {96'd0, v_msg};
		46: ui_val = {96'd0, v_ci};
		47: ui_val = {96'd0, v_ct};
		48: ui_val = {96'd0, v_rc};
		49: ui_val = {96'd0, v_rt};
		default: ui_val = 128'd0;
	endcase
end
