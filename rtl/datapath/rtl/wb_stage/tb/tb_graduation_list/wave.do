onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_graduation_list/tb_clk_i
add wave -noupdate /tb_graduation_list/tb_rstn_i
add wave -noupdate /tb_graduation_list/tb_instruction_i
add wave -noupdate /tb_graduation_list/tb_instruction_o
add wave -noupdate -position end sim:/tb_graduation_list/module_inst/*
add wave -noupdate -position end sim:/tb_graduation_list/module_inst/entries
add wave -noupdate -position end sim:/tb_graduation_list/module_inst/read_enable
add wave -noupdate -position end sim:/tb_graduation_list/module_inst/num
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
WaveRestoreZoom {9966 ns} {10002 ns}
