onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_module/tb_clk_i
add wave -noupdate /tb_module/tb_rstn_i
add wave -noupdate -radix hexadecimal /tb_module/tb_pc_fetch_i
add wave -noupdate -radix hexadecimal /tb_module/tb_pc_execution_i
add wave -noupdate -radix hexadecimal /tb_module/tb_branch_addr_result_exec_i
add wave -noupdate /tb_module/tb_branch_taken_result_exec_i
add wave -noupdate /tb_module/tb_is_branch_EX_i
add wave -noupdate /tb_module/tb_push_return_address_i
add wave -noupdate /tb_module/tb_branch_predict_taken_o
add wave -noupdate -radix hexadecimal /tb_module/tb_branch_predict_addr_o
add wave -noupdate /tb_module/module_inst/bimodal_predictor_inst/readed_state_pht
add wave -noupdate /tb_module/module_inst/is_branch_valid_bit
add wave -noupdate /tb_module/module_inst/is_branch_table
add wave -noupdate /tb_module/module_inst/bimodal_predictor_inst/pattern_history_table
add wave -noupdate /tb_module/module_inst/bimodal_predictor_inst/branch_target_buffer
add wave -noupdate /tb_module/tb_branch_predict_is_branch_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2568 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 304
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
WaveRestoreZoom {2565 ns} {2571 ns}
