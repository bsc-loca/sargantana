onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_mul_unit/tb_clk_i
add wave -noupdate /tb_mul_unit/tb_rstn_i
add wave -noupdate /tb_mul_unit/tb_source_1
add wave -noupdate /tb_mul_unit/tb_source_2
add wave -noupdate /tb_mul_unit/tb_mul_result
add wave -noupdate /tb_mul_unit/tb_lock_mul
add wave -noupdate /tb_mul_unit/tb_ready_mul
add wave -noupdate -radix ascii /tb_mul_unit/tb_test_name
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {6 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
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
WaveRestoreZoom {3999 ns} {4005 ns}
