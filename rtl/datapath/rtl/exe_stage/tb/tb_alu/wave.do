onerror {resume}
add wave -noupdate -radix hexadecimal /tb_module/tb_instr_i.data_rs1;
add wave -noupdate -radix hexadecimal /tb_module/tb_instr_i.data_rs2;
add wave -noupdate -radix ascii /tb_module/tb_instr_i.instr.instr_type;
add wave -noupdate -radix hexadecimal /tb_module/tb_instr_o.result;
add wave -noupdate -radix ascii /tb_module/tb_test_name
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
WaveRestoreZoom {1114 ns} {1205 ns}
