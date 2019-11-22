onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_rename_table/rename_table_inst/clk_i
add wave -noupdate /tb_rename_table/rename_table_inst/rstn_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/read_src1_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/read_src2_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/old_dst_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/write_dst_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/new_dst_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/do_checkpoint_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/do_recover_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/delete_checkpoint_i
add wave -noupdate -expand -group INPUT /tb_rename_table/rename_table_inst/recover_checkpoint_i
add wave -noupdate -expand -group OUTPUT /tb_rename_table/rename_table_inst/src1_o
add wave -noupdate -expand -group OUTPUT /tb_rename_table/rename_table_inst/src2_o
add wave -noupdate -expand -group OUTPUT /tb_rename_table/rename_table_inst/old_dst_o
add wave -noupdate -expand -group OUTPUT /tb_rename_table/rename_table_inst/checkpoint_o
add wave -noupdate -expand -group OUTPUT /tb_rename_table/rename_table_inst/out_of_checkpoints_o
add wave -noupdate -expand -group Intern /tb_rename_table/rename_table_inst/version_head
add wave -noupdate -expand -group Intern /tb_rename_table/rename_table_inst/version_tail
add wave -noupdate -expand -group Intern /tb_rename_table/rename_table_inst/num_checkpoints
add wave -noupdate -expand -group Intern /tb_rename_table/rename_table_inst/write_enable
add wave -noupdate -expand -group Intern /tb_rename_table/rename_table_inst/read_enable
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {6 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 395
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
WaveRestoreZoom {0 ns} {22 ns}
