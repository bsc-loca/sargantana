onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_free_list/tb_clk_i
add wave -noupdate /tb_free_list/tb_rstn_i
add wave -noupdate /tb_free_list/tb_read_head_i
add wave -noupdate /tb_free_list/tb_add_free_register_i
add wave -noupdate /tb_free_list/tb_free_register_i
add wave -noupdate /tb_free_list/free_list_inst/do_checkpoint_i
add wave -noupdate /tb_free_list/free_list_inst/do_recover_i
add wave -noupdate /tb_free_list/free_list_inst/delete_checkpoint_i
add wave -noupdate /tb_free_list/free_list_inst/recover_checkpoint_i
add wave -noupdate /tb_free_list/free_list_inst/new_register_o
add wave -noupdate /tb_free_list/free_list_inst/out_of_checkpoints_o
add wave -noupdate /tb_free_list/tb_new_register_o
add wave -noupdate /tb_free_list/tb_empty_o
add wave -noupdate -expand /tb_free_list/free_list_inst/head
add wave -noupdate -expand /tb_free_list/free_list_inst/tail
add wave -noupdate -expand /tb_free_list/free_list_inst/num
add wave -noupdate /tb_free_list/free_list_inst/version_head
add wave -noupdate /tb_free_list/free_list_inst/version_tail
add wave -noupdate -subitemconfig {{/tb_free_list/free_list_inst/register_table[0]} -expand {/tb_free_list/free_list_inst/register_table[1]} -expand {/tb_free_list/free_list_inst/register_table[2]} -expand} /tb_free_list/free_list_inst/register_table
add wave -noupdate /tb_free_list/free_list_inst/write_enable
add wave -noupdate /tb_free_list/free_list_inst/read_enable
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {217 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 281
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
WaveRestoreZoom {194 ns} {219 ns}
