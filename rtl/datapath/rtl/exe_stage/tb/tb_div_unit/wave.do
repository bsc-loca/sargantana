onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_div_unit/tb_clk_i
add wave -noupdate /tb_div_unit/tb_kill_div_i
add wave -noupdate /tb_div_unit/tb_request_i
add wave -noupdate /tb_div_unit/tb_src1_i
add wave -noupdate /tb_div_unit/tb_src2_i
add wave -noupdate /tb_div_unit/tb_quo_o
add wave -noupdate /tb_div_unit/tb_rmd_o
add wave -noupdate /tb_div_unit/tb_stall_o
add wave -noupdate /tb_div_unit/module_inst/state_d
add wave -noupdate -radix ascii /tb_div_unit/tb_test_name
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {21 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 178
configure wave -valuecolwidth 142
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {17970 ns} {18006 ns}
