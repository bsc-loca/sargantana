onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_mem_unit/tb_clk_i
add wave -noupdate /tb_mem_unit/tb_rstn_i
add wave -noupdate -expand /tb_mem_unit/tb_interface_i
add wave -noupdate /tb_mem_unit/tb_kill_i
add wave -noupdate /tb_mem_unit/tb_ls_queue_entry_o
add wave -noupdate /tb_mem_unit/module_inst/load_store_queue_inst/head
add wave -noupdate /tb_mem_unit/module_inst/load_store_queue_inst/tail
add wave -noupdate /tb_mem_unit/module_inst/load_store_queue_inst/num
add wave -noupdate /tb_mem_unit/tb_flush_i
add wave -noupdate /tb_mem_unit/module_inst/load_store_queue_inst/read_enable
add wave -noupdate /tb_mem_unit/module_inst/load_store_queue_inst/write_enable
add wave -noupdate /tb_mem_unit/tb_ready_from_dcache
add wave -noupdate /tb_mem_unit/tb_valid_to_dcache
add wave -noupdate /tb_mem_unit/tb_data_rs1_to_dcache
add wave -noupdate /tb_mem_unit/tb_data_rs2_to_dcache
add wave -noupdate /tb_mem_unit/tb_instr_type_to_dcache
add wave -noupdate /tb_mem_unit/tb_mem_op_to_dcache
add wave -noupdate /tb_mem_unit/tb_rd_to_dcache
add wave -noupdate /tb_mem_unit/tb_imm_to_dcache
add wave -noupdate /tb_mem_unit/tb_data_o
add wave -noupdate /tb_mem_unit/tb_ready_o
add wave -noupdate /tb_mem_unit/tb_lock_o
add wave -noupdate /tb_mem_unit/tb_dmem_req_valid_o
add wave -noupdate /tb_mem_unit/tb_lock_from_dcache
add wave -noupdate /tb_mem_unit/tb_dmem_req_cmd_o
add wave -noupdate /tb_mem_unit/tb_dmem_req_addr_o
add wave -noupdate /tb_mem_unit/tb_dmem_op_type_o
add wave -noupdate /tb_mem_unit/tb_dmem_req_data_o
add wave -noupdate /tb_mem_unit/tb_dmem_req_tag_o
add wave -noupdate /tb_mem_unit/tb_dmem_req_invalidate_lr_o
add wave -noupdate /tb_mem_unit/tb_dmem_req_kill_o
add wave -noupdate /tb_mem_unit/tb_dmem_resp_replay_i
add wave -noupdate /tb_mem_unit/tb_dmem_resp_data_i
add wave -noupdate /tb_mem_unit/tb_dmem_resp_valid_i
add wave -noupdate /tb_mem_unit/tb_dmem_resp_nack_i
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 401
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
WaveRestoreZoom {0 ns} {8 ns}
