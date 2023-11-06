onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_top/top_drac_inst/CLK
add wave -noupdate /tb_top/tb_rstn_i
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/id_cu_i
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/ir_cu_i
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/rr_cu_i
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/exe_cu_i
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/wb_cu_i
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/pipeline_ctrl_o
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/cu_if_o
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/cu_ir_o
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/cu_rr_o
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/cu_wb_o
add wave -noupdate -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/cu_commit_o
add wave -noupdate -group {PC Stages} /tb_top/top_drac_inst/datapath_inst/stage_if_1_if_2_q.pc_inst
add wave -noupdate -group {PC Stages} /tb_top/top_drac_inst/datapath_inst/stage_if_2_id_q.pc_inst
add wave -noupdate -group {PC Stages} /tb_top/top_drac_inst/datapath_inst/stage_ir_rr_d.instr.pc
add wave -noupdate -group {PC Stages} /tb_top/top_drac_inst/datapath_inst/stage_ir_rr_q.instr.pc
add wave -noupdate -group {PC Stages} -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/stage_rr_exe_q.instr.pc
add wave -noupdate -group Icache /tb_top/top_drac_inst/icache_interface_inst/icache_access_needed_int
add wave -noupdate -group Icache /tb_top/top_drac_inst/icache_interface_inst/buffer_miss_int
add wave -noupdate -group Icache /tb_top/top_drac_inst/icache_interface_inst/do_request_int
add wave -noupdate -group Icache /tb_top/top_drac_inst/icache_interface_inst/icache_resp_datablock_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/clk_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/rstn_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/req_cpu_dcache_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_resp_replay_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_resp_data_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_ready_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_resp_valid_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_resp_tag_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_resp_nack_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_xcpt_ma_st_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_xcpt_ma_ld_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_xcpt_pf_st_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_xcpt_pf_ld_i
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_valid_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_cmd_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_addr_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_op_type_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_data_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_tag_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_invalidate_lr_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_kill_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/resp_dcache_cpu_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_is_store_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_is_load_o
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/mem_xcpt
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/io_address_space
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/kill_io_resp
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/kill_mem_ope
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_req_addr_64
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/type_of_op
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_xcpt_ma_st_reg
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_xcpt_ma_ld_reg
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_xcpt_pf_st_reg
add wave -noupdate -group Dcache /tb_top/top_drac_inst/dcache_interface_inst/dmem_xcpt_pf_ld_reg
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/clk_i
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/rstn_i
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/soft_rstn_i
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/control_int
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/cu_if_int
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/pc_jump_if_int
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/stage_ir_rr_d
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/stage_ir_rr_q
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/stage_rr_exe_d
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/stage_rr_exe_q
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/wb_cu_int
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/id_cu_int
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/jal_id_if_int
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/datapath_inst/io_base_addr
add wave -noupdate -group DATAPATH /tb_top/top_drac_inst/icache_interface_inst/icache_resp_valid_i
add wave -noupdate -group {ID STAGE} -radix hexadecimal -childformat {{{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[63]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[62]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[61]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[60]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[59]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[58]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[57]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[56]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[55]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[54]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[53]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[52]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[51]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[50]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[49]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[48]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[47]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[46]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[45]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[44]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[43]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[42]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[41]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[40]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[39]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[38]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[37]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[36]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[35]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[34]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[33]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[32]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[31]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[30]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[29]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[28]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[27]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[26]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[25]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[24]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[23]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[22]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[21]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[20]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[19]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[18]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[17]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[16]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[15]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[14]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[13]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[12]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[11]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[10]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[9]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[8]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[7]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[6]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[5]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[4]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[3]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[2]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[1]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[0]} -radix hexadecimal}} -subitemconfig {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[63]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[62]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[61]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[60]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[59]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[58]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[57]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[56]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[55]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[54]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[53]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[52]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[51]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[50]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[49]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[48]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[47]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[46]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[45]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[44]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[43]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[42]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[41]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[40]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[39]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[38]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[37]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[36]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[35]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[34]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[33]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[32]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[31]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[30]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[29]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[28]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[27]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[26]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[25]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[24]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[23]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[22]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[21]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[20]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[19]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[18]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[17]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[16]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[15]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[14]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[13]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[12]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[11]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[10]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[9]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[8]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[7]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[6]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[5]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[4]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[3]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[2]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[1]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value[0]} {-height 17 -radix hexadecimal}} /tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value
add wave -noupdate -group {ID STAGE} -childformat {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst -radix hexadecimal -childformat {{{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[31]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[30]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[29]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[28]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[27]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[26]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[25]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[24]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[23]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[22]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[21]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[20]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[19]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[18]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[17]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[16]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[15]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[14]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[13]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[12]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[11]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[10]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[9]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[8]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[7]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[6]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[5]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[4]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[3]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[2]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[1]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[0]} -radix hexadecimal}}}} -subitemconfig {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst {-height 17 -radix hexadecimal -childformat {{{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[31]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[30]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[29]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[28]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[27]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[26]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[25]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[24]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[23]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[22]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[21]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[20]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[19]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[18]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[17]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[16]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[15]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[14]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[13]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[12]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[11]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[10]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[9]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[8]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[7]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[6]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[5]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[4]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[3]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[2]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[1]} -radix hexadecimal} {{/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[0]} -radix hexadecimal}}} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[31]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[30]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[29]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[28]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[27]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[26]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[25]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[24]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[23]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[22]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[21]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[20]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[19]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[18]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[17]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[16]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[15]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[14]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[13]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[12]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[11]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[10]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[9]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[8]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[7]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[6]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[5]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[4]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[3]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[2]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[1]} {-height 17 -radix hexadecimal} {/tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst[0]} {-height 17 -radix hexadecimal}} /tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i
add wave -noupdate -group {ID STAGE} /tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.pc_inst
add wave -noupdate -group {ID STAGE} -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.inst
add wave -noupdate -group {ID STAGE} /tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.valid
add wave -noupdate -group {ID STAGE} /tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.bpred
add wave -noupdate -group {ID STAGE} /tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_i.ex
add wave -noupdate -group {ID STAGE} /tb_top/top_drac_inst/datapath_inst/id_decode_inst/decode_instr_o
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/clk_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/rstn_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/read_head_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/add_free_register_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/free_register_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/do_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/do_recover_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/delete_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/recover_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/commit_roll_back_i
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/new_register_o
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/checkpoint_o
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/out_of_checkpoints_o
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/empty_o
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/head
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/tail
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/version_head
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/version_tail
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/num_registers
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/num_checkpoints
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/write_enable
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/read_enable
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/checkpoint_enable
add wave -noupdate -group {IR STAGE} -group {Free list} /tb_top/top_drac_inst/datapath_inst/free_list_inst/register_table
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/clk_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/rstn_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/read_src1_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/read_src2_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/old_dst_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/write_dst_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/new_dst_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/ready_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/vaddr_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/paddr_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/recover_commit_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/commit_old_dst_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/commit_write_dst_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/commit_new_dst_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/do_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/do_recover_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/delete_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/recover_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/src1_o
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/rdy1_o
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/src2_o
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/rdy2_o
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/old_dst_o
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/checkpoint_o
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/out_of_checkpoints_o
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/version_head
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/version_tail
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/num_checkpoints
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/write_enable
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/read_enable
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/checkpoint_enable
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/commit_write_enable
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/ready_enable
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/rdy1
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/rdy2
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/ready_table
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/register_table
add wave -noupdate -group {IR STAGE} -group {Rename Table} /tb_top/top_drac_inst/datapath_inst/rename_table_inst/commit_table
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/clk_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/rstn_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/read_head_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/add_free_register_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/free_register_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/do_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/do_recover_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/delete_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/recover_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/commit_roll_back_i
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/new_register_o
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/checkpoint_o
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/out_of_checkpoints_o
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/empty_o
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/head
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/tail
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/version_head
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/version_tail
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/num_registers
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/num_checkpoints
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/write_enable
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/read_enable
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/checkpoint_enable
add wave -noupdate -group {IR STAGE} -group {SIMD Free list} /tb_top/top_drac_inst/datapath_inst/simd_free_list_inst/register_table
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/clk_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/rstn_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/read_src1_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/read_src2_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/old_dst_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/write_dst_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/new_dst_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/ready_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/vaddr_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/paddr_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/recover_commit_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/commit_old_dst_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/commit_write_dst_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/commit_new_dst_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/do_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/do_recover_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/delete_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/recover_checkpoint_i
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/src1_o
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/rdy1_o
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/src2_o
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/rdy2_o
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/old_dst_o
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/rdy_old_dst_o
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/checkpoint_o
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/out_of_checkpoints_o
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/version_head
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/version_tail
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/num_checkpoints
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/write_enable
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/read_enable
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/checkpoint_enable
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/commit_write_enable
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/ready_enable
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/rdy1
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/rdy2
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/ready_table
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/register_table
add wave -noupdate -group {IR STAGE} -group {SIMD Rename Table} /tb_top/top_drac_inst/datapath_inst/simd_rename_table_inst/commit_table
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/clk_i
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/write_enable_i
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/write_addr_i
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/write_data_i
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/read_addr1_i
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/read_addr2_i
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/read_data1_o
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/read_data2_o
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/registers
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/bypass_data1
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/bypass_data2
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/bypass1
add wave -noupdate -group {RR STAGE} -group REGFILE /tb_top/top_drac_inst/datapath_inst/regfile/bypass2
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/clk_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/write_enable_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/write_addr_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/write_data_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/read_addr1_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/read_addr2_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/read_addr_old_vd_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/read_addrm_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/use_mask_i
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/read_data1_o
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/read_data2_o
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/read_data_old_vd_o
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/read_mask_o
add wave -noupdate -group {RR STAGE} -group VREGFILE -expand /tb_top/top_drac_inst/datapath_inst/vregfile/registers
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/bypass_data1
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/bypass_data2
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/bypass_data_old_vd
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/bypass_mask
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/bypass1
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/bypass2
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/bypass_old_vd
add wave -noupdate -group {RR STAGE} -group VREGFILE /tb_top/top_drac_inst/datapath_inst/vregfile/bypassm
add wave -noupdate -group {EXE STAGE} -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/clk_i
add wave -noupdate -group {EXE STAGE} -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/from_rr_i.instr.pc
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group ALU /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/alu_inst/instruction_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group ALU /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/alu_inst/instruction_o
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group ALU /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/alu_inst/data_rs1
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group ALU /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/alu_inst/data_rs2
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/clk_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/rstn_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/kill_mul_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/instruction_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/instruction_o
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/data_src1
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/data_src2
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/same_sign
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/int_32_0_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/int_32_0_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/int_32_1_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/neg_def_0_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/neg_def_0_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/neg_def_1_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/type_0_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/type_0_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/type_1_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/src1_def_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/src1_def_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/src2_def_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/src2_def_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_low_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_high_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_low_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_high_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_128
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_128_def
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_32_aux
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_32
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/result_64
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/instruction_0_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/instruction_0_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/instruction_1_q
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/instruction_s1
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {MUL UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mul_unit_inst/instruction_s2
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/clk_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/rstn_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/kill_div_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/instruction_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/instruction_o
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/data_src1
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/data_src2
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/dividend_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/divisor_d
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/dividend_quotient_32
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/dividend_quotient_64
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/remanent_32
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {DIV UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/div_unit_inst/remanent_64
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/instruction_i
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/instruction_o
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/data_rs1
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/data_rs2
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/equal
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/less
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/less_u
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/branch_taken
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/target
add wave -noupdate -group {EXE STAGE} -group {ARITH PIPELINE} -group {BRANCH UNIT} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/branch_unit_inst/result
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/clk_i
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/rstn_i
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/kill_i
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/flush_i
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/io_base_addr_i
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_i
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/resp_dcache_cpu_i
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/commit_store_or_amo_i
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/req_cpu_dcache_o
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_o
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/exception_mem_commit_o
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/mem_commit_stall_o
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/mem_gl_index_o
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/lock_o
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/empty_o
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/data_src1
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/data_src2
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/source_dcache
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/is_STORE_or_AMO_s0_d
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/is_STORE_or_AMO_s1_d
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/is_STORE_or_AMO_s1_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/is_STORE_or_AMO_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/is_STORE_or_AMO_to_wb
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/flush_store
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/flush_store_nack
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/store_on_fly
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/mem_commit_stall_s0
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/full_lsq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/empty_lsq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/flush_to_lsq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/read_next_lsq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/reset_next_lsq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/advance_exec_lsq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/advance_head_lsq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_to_lsq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_to_dcache
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/stored_instr_to_dcache
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_to_wb
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_s1_d
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_s1_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/io_s1_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/io_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/tag_id
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/tag_id_s1_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/tag_id_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt_s1_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt_ma_st_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt_ma_ld_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt_pf_st_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt_pf_ld_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt_addr_s1_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/xcpt_addr_s2_q
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/exception_to_wb
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_to_pmrq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/instruction_from_pmrq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/advance_head_prmq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/full_pmrq
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/data_to_wb
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/state
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/next_state
add wave -noupdate -group {EXE STAGE} -group {MEM PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_unit_inst/mem_commit_stall_s1
add wave -noupdate -group {EXE STAGE} -group {SIMD PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/simd_unit_inst/instruction_i
add wave -noupdate -group {EXE STAGE} -group {SIMD PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/simd_unit_inst/vs1_elements
add wave -noupdate -group {EXE STAGE} -group {SIMD PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/simd_unit_inst/vs2_elements
add wave -noupdate -group {EXE STAGE} -group {SIMD PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/simd_unit_inst/vd_elements
add wave -noupdate -group {EXE STAGE} -group {SIMD PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/simd_unit_inst/data_vd
add wave -noupdate -group {EXE STAGE} -group {SIMD PIPELINE} /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/simd_unit_inst/data_rd
add wave -noupdate -group {EXE STAGE} -group Writeback /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/arith_to_scalar_wb_o
add wave -noupdate -group {EXE STAGE} -group Writeback /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_to_scalar_wb_o
add wave -noupdate -group {EXE STAGE} -group Writeback /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/simd_to_scalar_wb_o
add wave -noupdate -group {EXE STAGE} -group Writeback /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/simd_to_simd_wb_o
add wave -noupdate -group {EXE STAGE} -group Writeback /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/mem_to_simd_wb_o
add wave -noupdate -group Commit /tb_top/top_drac_inst/datapath_inst/cu_if_int
add wave -noupdate -group Commit /tb_top/top_drac_inst/datapath_inst/pc_jump_if_int
add wave -noupdate -group Commit /tb_top/top_drac_inst/datapath_inst/wb_cu_int
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/SIZE
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/LINE_SIZE
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/ADDR_SIZE
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/DELAY
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/HEX_LOAD_ADDR
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/BASE
add wave -noupdate -group {Perfect memory write} /tb_top/top_drac_inst/DMEM_REQ_BITS_DATA
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/clk_i
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/rstn_i
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/addr_i
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/valid_i
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/tag_i
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/wr_ena_i
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/wr_data_i
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/word_size_i
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/line_o
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/ready_o
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/valid_o
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/tag_o
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/memory
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/counter
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/next_counter
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/addr_int
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/line_d
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/line_q
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/addr_d
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/addr_q
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/addr_int_d
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/addr_int_q
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/word_size_d
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/word_size_q
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/valid_d
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/valid_q
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/tag_d
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/tag_q
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/state
add wave -noupdate -group {Perfect memory write} /tb_top/perfect_memory_hex_write_inst/next_state
add wave -noupdate /tb_top/l1_vpn_request
add wave -noupdate /tb_top/l1_request_paddr
add wave -noupdate /tb_top/l1_request_valid
add wave -noupdate /tb_top/perfect_memory_hex_inst/request_q
add wave -noupdate /tb_top/perfect_memory_hex_inst/addr_int
add wave -noupdate -radix hexadecimal /tb_top/perfect_memory_hex_inst/line_o
add wave -noupdate /tb_top/perfect_memory_hex_inst/memory
add wave -noupdate /tb_top/perfect_memory_hex_inst/counter
add wave -noupdate /tb_top/l2_response_valid
add wave -noupdate /tb_top/l2_response_seqnum
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 3} {1578 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 178
configure wave -valuecolwidth 221
configure wave -justifyvalue left
configure wave -signalnamewidth 1
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
WaveRestoreZoom {7969 ns} {8011 ns}
