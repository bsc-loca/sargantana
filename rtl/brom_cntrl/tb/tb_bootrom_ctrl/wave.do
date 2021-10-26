onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/clk_i
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/rstn_i
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/bytecount_d
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/bytecount_q
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/mi_i
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/mo_o
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/ready_o
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/req_address_i
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/req_valid_i
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/resp_data_d
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/resp_data_o
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/resp_data_q
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/resp_data_w
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/resp_valid_d
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/resp_valid_o
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/resp_valid_w
add wave -noupdate -expand -group bootrom_driv /tb_bootrom_ctrl/bd0/ser/req_opcode_q
add wave -noupdate -expand -group bootrom_driv /tb_bootrom_ctrl/bd0/ser/req_address_q
add wave -noupdate -expand -group bootrom_driv /tb_bootrom_ctrl/bd0/ser/req_bytes_q
add wave -noupdate -expand -group bootrom_driv /tb_bootrom_ctrl/bd0/ser/req_data_q
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/sclk_o
add wave -noupdate -expand -group bootrom_driv -radix hexadecimal /tb_bootrom_ctrl/bd0/cs_n_o
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/rstn_i
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/clk_i
add wave -noupdate -group spi_eeprom_req -radix hexadecimal {/tb_bootrom_ctrl/bd0/ser/clk_phs[0]}
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/next_state
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/req_address_i
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/req_opcode_i
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/req_bytes_i
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/req_valid_i
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/resp_data_d
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/resp_data_q
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/resp_data_o
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/resp_valid_d
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/resp_valid_q
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/resp_valid_o
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/mi_i
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/mo_o
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/ready_o
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/bitcount_d
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/bitcount_q
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/bytecount_d
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/bytecount_q
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/sclk_en_o
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/sclk_o
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/state
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/cnt_abyte
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/cnt_rbyte
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/cnt_tbyte
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/tx_addr_finish
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/rx_finish
add wave -noupdate -group spi_eeprom_req -radix hexadecimal /tb_bootrom_ctrl/bd0/ser/tx_finish
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/CS_N
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/RESET
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SCK
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SI
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SO
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/WP_N
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/HOLD_N
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/AddrRegister
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionREAD
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/BitCounter
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/BufferWrFlags
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/DataShifterI
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/DataShifterO
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/EEPROM_WrEvent
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/EEPROMWriteProtected
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/EffectiveMPR
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/FRZR_Event
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/HardwareWriteProtected
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstRegister
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionCHLK
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionFRZR
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionLOCK
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionPPAB
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionPRWD
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionPRWE
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionRDEX
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionRDSR
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionRMPR
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionSPID
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionSRST
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionWMPR
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionWRBP
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionWRDI
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionWREN
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionWREX
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionWRITE
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/InstructionWRSR
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/LoopIndex
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MAN_ID
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryBlock
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00000
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte0000A
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte0000B
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte0000C
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte0000D
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte0000E
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte0000F
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00001
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF0
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF1
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF2
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF3
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF4
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF5
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF6
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF7
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF8
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFF9
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFFA
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFFB
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFFC
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFFD
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFFE
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte1FFFF
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00002
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00003
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00004
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00005
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00006
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00007
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00008
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MemoryByte00009
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR00
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR01
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR02
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR03
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR04
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR05
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR06
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR07
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_0
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_1
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_2
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_3
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_4
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_5
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_6
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_7
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPR_WrEvent
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPRBuffer
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/MPRWriteProtected
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/OutputEnable1
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/OutputEnable2
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/OutputEnable3
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer00
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer0A
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer0B
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer0C
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer0D
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer0E
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer0F
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer01
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer1A
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer1B
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer1C
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer1D
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer1E
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer1F
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer02
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer03
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer04
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer05
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer06
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer07
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer08
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer09
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer10
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer11
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer12
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer13
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer14
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer15
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer16
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer17
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer18
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBuffer19
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE0
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE1
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE2
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE3
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE4
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE5
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE6
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE7
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE8
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferE9
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferEA
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferEB
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferEC
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferED
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferEE
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferEF
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF0
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF1
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF2
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF3
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF4
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF5
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF6
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF7
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF8
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferF9
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferFA
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferFB
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferFC
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferFD
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferFE
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PageBufferFF
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PPAB_ClearEvent
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/PPAB_SetEvent
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SECREG_LockEvent
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SECREG_WrEvent
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte000
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte0FC
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte0FD
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte0FE
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte0FF
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte001
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte1FC
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte1FD
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte1FE
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte1FF
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte002
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte003
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte100
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte101
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte102
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegByte103
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegLock
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecRegWriteProtected
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SecurityReg
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_0
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_1
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_2
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_3
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_4
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_5
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_6
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_7
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_8
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_9
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_A
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_B
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_C
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_D
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_E
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SERIAL_NUM_F
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SO_DO
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SO_Enable
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/SO_OE
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_BP
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_ECS
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_FMPC
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_PABP
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_PREL
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_REG_DEFAULTS
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_WEL
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_WPEN
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_WPM
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/STATUS_WrEvent
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/StatusRegBuffer
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/tDIS
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/tHV
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/tHZ
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/TimingCheckEnable
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/tV
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/tWC
add wave -noupdate -group mem /tb_bootrom_ctrl/mem0/WriteActive
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1363598 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 353
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
WaveRestoreZoom {62137473 ps} {138203291 ps}
