onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_regfile/tb_clk_i
add wave -noupdate -expand -group Regfile /tb_regfile/tb_clk_i
add wave -noupdate -expand -group Regfile /tb_regfile/tb_write_enable_i
add wave -noupdate -expand -group Regfile /tb_regfile/tb_write_addr_i
add wave -noupdate -expand -group Regfile /tb_regfile/tb_write_data_i
add wave -noupdate -expand -group Regfile /tb_regfile/tb_read_addr1_i
add wave -noupdate -expand -group Regfile /tb_regfile/tb_read_addr2_i
add wave -noupdate -expand -group Regfile /tb_regfile/tb_read_data1_o
add wave -noupdate -expand -group Regfile /tb_regfile/tb_read_data2_o
add wave -noupdate -expand /tb_regfile/regfile_inst/registers
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 268
configure wave -valuecolwidth 256
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
WaveRestoreZoom {0 ns} {28 ns}
