onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_free_list/tb_clk_i
add wave -noupdate /tb_free_list/tb_rstn_i
add wave -noupdate /tb_free_list/tb_read_head_i
add wave -noupdate /tb_free_list/tb_add_free_register_i
add wave -noupdate /tb_free_list/tb_free_register_i
add wave -noupdate /tb_free_list/tb_new_register_o
add wave -noupdate /tb_free_list/tb_empty_o
add wave -noupdate /tb_free_list/free_list_inst/head
add wave -noupdate /tb_free_list/free_list_inst/tail
add wave -noupdate /tb_free_list/free_list_inst/num
add wave -noupdate /tb_free_list/free_list_inst/register_table
add wave -noupdate /tb_free_list/free_list_inst/write_enable
add wave -noupdate /tb_free_list/free_list_inst/read_enable
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {6 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 194
configure wave -valuecolwidth 153
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
WaveRestoreZoom {0 ns} {27 ns}
