onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_if_stage/tb_clk_i
add wave -noupdate -expand -group tb -radix ascii /tb_if_stage/tb_test_name
add wave -noupdate -expand -group tb /tb_if_stage/tb_rstn_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_reset_addr_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_stall_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_cu_if_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_invalidate_icache_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_invalidate_buffer_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_pc_jump_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_resp_icache_cpu_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_exe_if_branch_pred_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_retry_fetch_i
add wave -noupdate -expand -group tb /tb_if_stage/tb_req_cpu_icache_o
add wave -noupdate -expand -group tb -expand /tb_if_stage/tb_fetch_o
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/clk_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/rstn_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/reset_addr_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/stall_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/cu_if_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/invalidate_icache_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/invalidate_buffer_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/pc_jump_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/resp_icache_cpu_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/exe_if_branch_pred_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/retry_fetch_i
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/req_cpu_icache_o
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/fetch_o
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/next_pc
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/pc
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/ex_addr_misaligned_int
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/ex_if_addr_fault_int
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/ex_if_page_fault_int
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/branch_predict_is_branch
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/branch_predict_taken
add wave -noupdate -group if_stage /tb_if_stage/if_stage_inst/branch_predict_addr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 201
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
WaveRestoreZoom {50 ns} {80 ns}
