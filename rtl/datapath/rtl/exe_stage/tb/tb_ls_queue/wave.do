onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_ls_queue/tb_clk_i
add wave -noupdate /tb_ls_queue/tb_rstn_i
add wave -noupdate /tb_ls_queue/tb_valid_i
add wave -noupdate /tb_ls_queue/tb_addr_i
add wave -noupdate /tb_ls_queue/tb_data_i
add wave -noupdate /tb_ls_queue/tb_mem_op_i
add wave -noupdate /tb_ls_queue/tb_mem_format_i
add wave -noupdate /tb_ls_queue/tb_amo_op_i
add wave -noupdate /tb_ls_queue/tb_rd_i
add wave -noupdate /tb_ls_queue/tb_flush_i
add wave -noupdate /tb_ls_queue/tb_read_head_i
add wave -noupdate /tb_ls_queue/tb_addr_o
add wave -noupdate /tb_ls_queue/tb_data_o
add wave -noupdate /tb_ls_queue/tb_mem_op_o
add wave -noupdate /tb_ls_queue/tb_mem_format_o
add wave -noupdate /tb_ls_queue/tb_amo_op_o
add wave -noupdate /tb_ls_queue/tb_rd_o
add wave -noupdate /tb_ls_queue/tb_ls_queue_entry_o
add wave -noupdate /tb_ls_queue/tb_full_o
add wave -noupdate /tb_ls_queue/tb_empty_o
add wave -noupdate /tb_ls_queue/load_store_queue_inst/data_table
add wave -noupdate /tb_ls_queue/load_store_queue_inst/addr_table
add wave -noupdate /tb_ls_queue/load_store_queue_inst/control_table
add wave -noupdate /tb_ls_queue/load_store_queue_inst/head
add wave -noupdate /tb_ls_queue/load_store_queue_inst/tail
add wave -noupdate /tb_ls_queue/load_store_queue_inst/num
add wave -noupdate /tb_ls_queue/load_store_queue_inst/write_enable
add wave -noupdate /tb_ls_queue/load_store_queue_inst/read_enable
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
WaveRestoreZoom {0 ns} {6 ns}
