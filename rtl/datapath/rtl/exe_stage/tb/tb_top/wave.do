onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_module/tb_clk_i
add wave -noupdate /tb_module/tb_from_rr_i.instr.instr_type
add wave -noupdate /tb_module/tb_from_rr_i.instr.unit
add wave -noupdate /tb_module/tb_from_rr_i.instr.mem_op
add wave -noupdate /tb_module/tb_from_rr_i.data_rs1
add wave -noupdate /tb_module/tb_from_rr_i.data_rs2
add wave -noupdate /tb_module/module_inst/mul_unit_inst/done_tick_o
add wave -noupdate /tb_module/tb_stall_o
add wave -noupdate -expand -group output /tb_module/tb_to_wb_o.result_rd
add wave -noupdate -expand -group output /tb_module/tb_to_wb_o.result_pc
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4271 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 258
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
WaveRestoreZoom {4267 ns} {4286 ns}
