onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /tb_decoder/tb_clk_i
add wave -noupdate -radix hexadecimal -childformat {{/tb_decoder/tb_decode_i.pc_inst -radix hexadecimal} {/tb_decoder/tb_decode_i.inst -radix hexadecimal} {/tb_decoder/tb_decode_i.valid -radix hexadecimal} {/tb_decoder/tb_decode_i.bpred -radix hexadecimal} {/tb_decoder/tb_decode_i.ex -radix hexadecimal}} -expand -subitemconfig {/tb_decoder/tb_decode_i.pc_inst {-height 17 -radix hexadecimal} /tb_decoder/tb_decode_i.inst {-height 17 -radix hexadecimal} /tb_decoder/tb_decode_i.valid {-height 17 -radix hexadecimal} /tb_decoder/tb_decode_i.bpred {-height 17 -radix hexadecimal} /tb_decoder/tb_decode_i.ex {-height 17 -radix hexadecimal}} /tb_decoder/tb_decode_i
add wave -noupdate -expand /tb_decoder/tb_decode_instr_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {6 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 194
configure wave -valuecolwidth 153
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
WaveRestoreZoom {0 ns} {27 ns}
