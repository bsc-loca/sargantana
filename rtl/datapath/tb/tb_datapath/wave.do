onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/clk_i
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/rstn_i
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/req_icache_cpu_i
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/req_cpu_icache_o
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stall_if_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stall_id_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stall_rr_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/next_pc_sel_if_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/pc_commit_if_int
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_if_id_d
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_if_id_q
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_id_rr_d
add wave -noupdate -expand -group datapath /tb_datapath/datapath_inst/stage_id_rr_q
add wave -noupdate -group if_stage -radix hexadecimal /tb_datapath/datapath_inst/if_stage_inst/clk_i
add wave -noupdate -group if_stage -radix hexadecimal /tb_datapath/datapath_inst/if_stage_inst/rstn_i
add wave -noupdate -group if_stage -radix hexadecimal /tb_datapath/datapath_inst/if_stage_inst/stall_i
add wave -noupdate -group if_stage -radix hexadecimal /tb_datapath/datapath_inst/if_stage_inst/next_pc_sel_i
add wave -noupdate -group if_stage -radix hexadecimal /tb_datapath/datapath_inst/if_stage_inst/pc_commit_i
add wave -noupdate -group if_stage -radix hexadecimal -childformat {{/tb_datapath/datapath_inst/if_stage_inst/req_icache_cpu_i.valid -radix hexadecimal} {/tb_datapath/datapath_inst/if_stage_inst/req_icache_cpu_i.data -radix hexadecimal} {/tb_datapath/datapath_inst/if_stage_inst/req_icache_cpu_i.ex -radix hexadecimal}} -subitemconfig {/tb_datapath/datapath_inst/if_stage_inst/req_icache_cpu_i.valid {-height 17 -radix hexadecimal} /tb_datapath/datapath_inst/if_stage_inst/req_icache_cpu_i.data {-height 17 -radix hexadecimal} /tb_datapath/datapath_inst/if_stage_inst/req_icache_cpu_i.ex {-height 17 -radix hexadecimal}} /tb_datapath/datapath_inst/if_stage_inst/req_icache_cpu_i
add wave -noupdate -group if_stage -radix hexadecimal -childformat {{/tb_datapath/datapath_inst/if_stage_inst/req_cpu_icache_o.valid -radix hexadecimal} {/tb_datapath/datapath_inst/if_stage_inst/req_cpu_icache_o.vaddr -radix hexadecimal}} -subitemconfig {/tb_datapath/datapath_inst/if_stage_inst/req_cpu_icache_o.valid {-height 17 -radix hexadecimal} /tb_datapath/datapath_inst/if_stage_inst/req_cpu_icache_o.vaddr {-height 17 -radix hexadecimal}} /tb_datapath/datapath_inst/if_stage_inst/req_cpu_icache_o
add wave -noupdate -group if_stage -radix hexadecimal /tb_datapath/datapath_inst/if_stage_inst/fetch_o
add wave -noupdate -group if_stage -radix hexadecimal /tb_datapath/datapath_inst/if_stage_inst/next_pc
add wave -noupdate -group if_stage -radix hexadecimal /tb_datapath/datapath_inst/if_stage_inst/pc
add wave -noupdate -group id_stage /tb_datapath/datapath_inst/id_decode_inst/decode_i
add wave -noupdate -group id_stage /tb_datapath/datapath_inst/id_decode_inst/decode_instr_o
add wave -noupdate -group id_stage /tb_datapath/datapath_inst/id_decode_inst/imm_value
add wave -noupdate -group id_stage /tb_datapath/datapath_inst/id_decode_inst/illegal_instruction
add wave -noupdate -group tb -expand /tb_datapath/tb_icache_fetch_i
add wave -noupdate -group tb -expand /tb_datapath/tb_fetch_icache_o
add wave -noupdate -group tb /tb_datapath/tb_addr_i
add wave -noupdate -group tb /tb_datapath/tb_line_o
add wave -noupdate -group {Perfect Memory} /tb_datapath/perfect_memory_inst/clk_i
add wave -noupdate -group {Perfect Memory} /tb_datapath/perfect_memory_inst/rstn_i
add wave -noupdate -group {Perfect Memory} /tb_datapath/perfect_memory_inst/addr_i
add wave -noupdate -group {Perfect Memory} /tb_datapath/perfect_memory_inst/line_o
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
WaveRestoreCursors {{Cursor 1} {6 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 319
configure wave -valuecolwidth 217
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
WaveRestoreZoom {2 ns} {21 ns}
