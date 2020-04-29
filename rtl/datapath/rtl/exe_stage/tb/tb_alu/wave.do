onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_module/tb_data_rs1_i
add wave -noupdate /tb_module/tb_data_rs2_i
add wave -noupdate /tb_module/tb_instr_type_i
add wave -noupdate /tb_module/tb_result_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4271 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 258
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
WaveRestoreZoom {397 ns} {488 ns}
