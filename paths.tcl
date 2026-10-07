# Reports the timing paths that limit the design; run by build_seeds.bat inside the build container.
project_open memtestplus
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 8 -detail full_path -to_clock [get_clocks {FPGA_CLK2_50}] -file /out/paths.txt
report_timing -setup -npaths 4 -detail full_path -to_clock [get_clocks {emu|pll|pll_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] -file /out/paths.txt -append
project_close
