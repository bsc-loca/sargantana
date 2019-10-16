onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_module/tb_clk_i
add wave -noupdate /tb_module/tb_valid_i
add wave -noupdate /tb_module/tb_kill_i
add wave -noupdate /tb_module/tb_csr_eret_i
add wave -noupdate /tb_module/tb_data_op1_i
add wave -noupdate /tb_module/tb_data_op2_i
add wave -noupdate /tb_module/tb_imm_i
add wave -noupdate /tb_module/tb_mem_op_i
add wave -noupdate /tb_module/tb_mem_format_i
add wave -noupdate /tb_module/tb_amo_op_i
add wave -noupdate /tb_module/tb_funct3_i
add wave -noupdate /tb_module/tb_rd_i
add wave -noupdate /tb_module/tb_io_base_addr_i
add wave -noupdate /tb_module/tb_dmem_resp_replay_i
add wave -noupdate /tb_module/tb_dmem_resp_data_i
add wave -noupdate /tb_module/tb_dmem_req_ready_i
add wave -noupdate /tb_module/tb_dmem_resp_valid_i
add wave -noupdate /tb_module/tb_dmem_resp_nack_i
add wave -noupdate /tb_module/tb_dmem_xcpt_ma_st_i
add wave -noupdate /tb_module/tb_dmem_xcpt_ma_ld_i
add wave -noupdate /tb_module/tb_dmem_xcpt_pf_st_i
add wave -noupdate /tb_module/tb_dmem_xcpt_pf_ld_i
add wave -noupdate -expand -group State /tb_module/module_inst/state
add wave -noupdate -expand -group State /tb_module/module_inst/next_state
add wave -noupdate -expand -group output /tb_module/tb_dmem_req_valid_o
add wave -noupdate -expand -group output /tb_module/tb_dmem_req_cmd_o
add wave -noupdate -expand -group output /tb_module/tb_dmem_req_addr_o
add wave -noupdate -expand -group output /tb_module/tb_dmem_op_type_o
add wave -noupdate -expand -group output /tb_module/tb_dmem_req_data_o
add wave -noupdate -expand -group output /tb_module/tb_dmem_req_tag_o
add wave -noupdate -expand -group output /tb_module/tb_dmem_req_invalidate_lr_o
add wave -noupdate -expand -group output /tb_module/tb_dmem_req_kill_o
add wave -noupdate -expand -group output /tb_module/tb_ready_o
add wave -noupdate -expand -group output /tb_module/tb_data_o
add wave -noupdate -expand -group output /tb_module/tb_lock_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 241
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
WaveRestoreZoom {0 ns} {15 ns}
