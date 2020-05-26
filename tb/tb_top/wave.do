onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/valid_fetch
add wave -noupdate -expand -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/id_cu_i
add wave -noupdate -expand -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/wb_cu_i
add wave -noupdate -expand -group {Control Unit} -expand /tb_top/top_drac_inst/datapath_inst/control_unit_inst/pipeline_ctrl_o
add wave -noupdate -expand -group {Control Unit} /tb_top/top_drac_inst/datapath_inst/control_unit_inst/cu_if_o
add wave -noupdate -group {PC Stages} /tb_top/top_drac_inst/datapath_inst/stage_if_id_d.pc_inst
add wave -noupdate -group {PC Stages} /tb_top/top_drac_inst/datapath_inst/stage_id_rr_d.pc
add wave -noupdate -group {PC Stages} /tb_top/top_drac_inst/datapath_inst/stage_rr_exe_d.instr.pc
add wave -noupdate -group {PC Stages} /tb_top/top_drac_inst/datapath_inst/stage_rr_exe_q.instr.pc
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/rstn_i
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/soft_rstn_i
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/control_int
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/cu_if_int
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/pc_jump_if_int
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/stage_if_id_d
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/stage_if_id_q
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/stage_id_rr_d
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/stage_id_rr_q
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/stage_rr_exe_d
add wave -noupdate -group datapath -expand -subitemconfig {/tb_top/top_drac_inst/datapath_inst/stage_rr_exe_q.instr -expand} /tb_top/top_drac_inst/datapath_inst/stage_rr_exe_q
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/wb_cu_int
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/id_cu_int
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/jal_id_if_int
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/stall_exe_out
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/exe_to_wb_exe
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/exe_to_wb_wb
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/wb_to_exe_exe
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/io_base_addr
add wave -noupdate -group datapath /tb_top/top_drac_inst/datapath_inst/clk_i
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/clk_i
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/rstn_i
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/stall_i
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/pc_jump_i
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/req_cpu_icache_o
add wave -noupdate -group if_stage -expand -subitemconfig {/tb_top/top_drac_inst/datapath_inst/if_stage_inst/fetch_o.inst -expand} /tb_top/top_drac_inst/datapath_inst/if_stage_inst/fetch_o
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/next_pc
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/pc
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/ex_addr_misaligned_int
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/ex_if_addr_fault_int
add wave -noupdate -group if_stage /tb_top/top_drac_inst/datapath_inst/if_stage_inst/ex_if_page_fault_int
add wave -noupdate -group id_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/id_decode_inst/imm_value
add wave -noupdate -expand -group rr_stage -expand /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/registers
add wave -noupdate -expand -group rr_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/clk_i
add wave -noupdate -expand -group rr_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/write_enable_i
add wave -noupdate -expand -group rr_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/write_addr_i
add wave -noupdate -expand -group rr_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/write_data_i
add wave -noupdate -expand -group rr_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/read_addr1_i
add wave -noupdate -expand -group rr_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/read_addr2_i
add wave -noupdate -expand -group rr_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/read_data1_o
add wave -noupdate -expand -group rr_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/rr_stage_inst/read_data2_o
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/clk_i
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/from_rr_i.instr.pc
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/from_rr_i.instr.rd
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/from_rr_i.instr.rs1
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/from_rr_i.instr.rs2
add wave -noupdate -expand -group exe_stage -radix hexadecimal /tb_top/top_drac_inst/datapath_inst/exe_stage_inst/rs1_data_bypass
add wave -noupdate -expand -group Commit /tb_top/top_drac_inst/datapath_inst/cu_if_int
add wave -noupdate -expand -group Commit /tb_top/top_drac_inst/datapath_inst/pc_jump_if_int
add wave -noupdate -expand -group Commit /tb_top/top_drac_inst/datapath_inst/wb_cu_int
add wave -noupdate -expand -group Commit -expand /tb_top/top_drac_inst/datapath_inst/exe_to_wb_wb
add wave -noupdate -expand -group Commit /tb_top/top_drac_inst/datapath_inst/wb_to_exe_exe
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {15 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 139
configure wave -valuecolwidth 108
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
WaveRestoreZoom {77 ns} {100 ns}
