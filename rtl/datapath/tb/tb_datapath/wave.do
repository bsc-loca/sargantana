onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group {Control Unit} /tb_datapath/datapath_inst/control_unit_inst/clk_i
add wave -noupdate -expand -group {Control Unit} /tb_datapath/datapath_inst/control_unit_inst/rstn_i
add wave -noupdate -expand -group {Control Unit} /tb_datapath/datapath_inst/control_unit_inst/valid_fetch
add wave -noupdate -expand -group {Control Unit} /tb_datapath/datapath_inst/control_unit_inst/id_cu_i
add wave -noupdate -expand -group {Control Unit} /tb_datapath/datapath_inst/control_unit_inst/wb_cu_i
add wave -noupdate -expand -group {Control Unit} /tb_datapath/datapath_inst/control_unit_inst/pipeline_ctrl_o
add wave -noupdate -expand -group {Control Unit} /tb_datapath/datapath_inst/control_unit_inst/cu_if_o
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/rstn_i
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/soft_rstn_i
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/req_icache_cpu_i
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/req_dcache_cpu_i
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/req_cpu_icache_o
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/control_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/cu_if_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/pc_jump_if_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_if_id_d
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_if_id_q
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_id_rr_d
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_id_rr_q
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_rr_exe_d
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_rr_exe_q
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/wb_instr_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/wb_cu_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/id_cu_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/jal_id_if_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stall_exe_out
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/exe_to_wb_exe
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/exe_to_wb_wb
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/wb_to_exe_exe
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/io_base_addr
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/clk_i
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/clk_i
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/rstn_i
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/stall_i
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/next_pc_sel_i
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/pc_jump_i
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/req_icache_cpu_i
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/req_cpu_icache_o
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/fetch_o
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/next_pc
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/pc
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/ex_addr_misaligned_int
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/ex_if_addr_fault_int
add wave -noupdate -expand -group if_stage /tb_datapath/datapath_inst/if_stage_inst/ex_if_page_fault_int
add wave -noupdate -expand -group id_stage -radix hexadecimal -childformat {{/tb_datapath/datapath_inst/id_decode_inst/decode_i.pc_inst -radix hexadecimal} {/tb_datapath/datapath_inst/id_decode_inst/decode_i.inst -radix hexadecimal} {/tb_datapath/datapath_inst/id_decode_inst/decode_i.valid -radix hexadecimal} {/tb_datapath/datapath_inst/id_decode_inst/decode_i.bpred -radix hexadecimal} {/tb_datapath/datapath_inst/id_decode_inst/decode_i.ex -radix hexadecimal}} -expand -subitemconfig {/tb_datapath/datapath_inst/id_decode_inst/decode_i.pc_inst {-height 17 -radix hexadecimal} /tb_datapath/datapath_inst/id_decode_inst/decode_i.inst {-height 17 -radix hexadecimal} /tb_datapath/datapath_inst/id_decode_inst/decode_i.valid {-height 17 -radix hexadecimal} /tb_datapath/datapath_inst/id_decode_inst/decode_i.bpred {-height 17 -radix hexadecimal} /tb_datapath/datapath_inst/id_decode_inst/decode_i.ex {-height 17 -radix hexadecimal}} /tb_datapath/datapath_inst/id_decode_inst/decode_i
add wave -noupdate -expand -group id_stage -radix hexadecimal /tb_datapath/datapath_inst/id_decode_inst/decode_instr_o
add wave -noupdate -expand -group id_stage -radix hexadecimal /tb_datapath/datapath_inst/id_decode_inst/imm_value
add wave -noupdate -expand -group id_stage -radix hexadecimal /tb_datapath/datapath_inst/id_decode_inst/illegal_instruction
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/clk_i
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/rstn_i
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/write_enable_i
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/write_addr_i
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/write_data_i
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/read_addr1_i
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/read_addr2_i
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/read_data1_o
add wave -noupdate -group rr_stage -radix hexadecimal /tb_datapath/datapath_inst/rr_stage_inst/read_data2_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/clk_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/rstn_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/from_rr_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/from_wb_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/io_base_addr_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_resp_replay_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_resp_data_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_req_ready_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_resp_valid_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_resp_nack_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_xcpt_ma_st_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_xcpt_ma_ld_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_xcpt_pf_st_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_xcpt_pf_ld_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/to_wb_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/stall_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_req_valid_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_req_cmd_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_req_addr_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_op_type_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_req_data_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_req_tag_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_req_invalidate_lr_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_req_kill_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/dmem_lock_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/rs1_data_bypass
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/rs2_data_bypass
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/rs2_data_def
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/result_alu
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/result_mul
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/stall_mul
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/ready_mul
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/result_div
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/result_rmd
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/stall_div
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/ready_div
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/taken_branch
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/target_branch
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/result_branch
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/reg_data_branch
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/ready_mem
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/result_mem
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/stall_mem
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/kill_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_datapath/datapath_inst/exe_stage_inst/csr_eret_i
add wave -noupdate -group tb -expand /tb_datapath/tb_icache_fetch_i
add wave -noupdate -group tb -expand /tb_datapath/tb_fetch_icache_o
add wave -noupdate -group tb /tb_datapath/tb_addr_i
add wave -noupdate -group tb /tb_datapath/tb_line_o
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/clk_i
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/rstn_i
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/clk_i
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/rstn_i
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/addr_i
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/addr_int
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/valid_i
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/line_o
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/ready_o
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/counter
add wave -noupdate -expand -group {Perfect Memory Hex} /tb_datapath/perfect_memory_hex_inst/next_counter
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {16 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 452
configure wave -valuecolwidth 185
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
WaveRestoreZoom {0 ns} {10 ns}
