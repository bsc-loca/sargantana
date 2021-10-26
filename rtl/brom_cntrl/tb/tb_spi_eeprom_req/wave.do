onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group driver_eeprom -expand -group main /tb_spi_eeprom_req/ser0/clk_phs
add wave -noupdate -expand -group driver_eeprom -expand -group main {/tb_spi_eeprom_req/ser0/clk_phs[0]}
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/clk_i
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/rstn_i
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/req_opcode_i
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/req_address_i
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/req_data_i
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/req_bytes_i
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/req_valid_i
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/ready_o
add wave -noupdate -expand -group driver_eeprom -expand -group main /tb_spi_eeprom_req/ser0/resp_data_d
add wave -noupdate -expand -group driver_eeprom -expand -group main /tb_spi_eeprom_req/ser0/resp_data_q
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/resp_data_o
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/resp_valid_o
add wave -noupdate -expand -group driver_eeprom -expand -group main /tb_spi_eeprom_req/ser0/sclk_en_o
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal -radixshowbase 0 /tb_spi_eeprom_req/ser0/state
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/next_state
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/mo_o
add wave -noupdate -expand -group driver_eeprom -expand -group main -radix hexadecimal /tb_spi_eeprom_req/ser0/mi_i
add wave -noupdate -expand -group driver_eeprom -group counters -radix unsigned /tb_spi_eeprom_req/ser0/bitcount_q
add wave -noupdate -expand -group driver_eeprom -group counters -radix unsigned /tb_spi_eeprom_req/ser0/bitcount_d
add wave -noupdate -expand -group driver_eeprom -group counters -radix unsigned /tb_spi_eeprom_req/ser0/bytecount_q
add wave -noupdate -expand -group driver_eeprom -group counters -radix unsigned /tb_spi_eeprom_req/ser0/bytecount_d
add wave -noupdate -expand -group driver_eeprom -group counters -radix hexadecimal /tb_spi_eeprom_req/ser0/cnt_tbyte
add wave -noupdate -expand -group driver_eeprom -group counters -radix hexadecimal /tb_spi_eeprom_req/ser0/cnt_rbyte
add wave -noupdate -expand -group driver_eeprom -group counters -radix hexadecimal /tb_spi_eeprom_req/ser0/cnt_abyte
add wave -noupdate -expand -group driver_eeprom -group counters -radix hexadecimal /tb_spi_eeprom_req/ser0/rx_finish
add wave -noupdate -expand -group driver_eeprom -group counters -radix hexadecimal /tb_spi_eeprom_req/ser0/tx_finish
add wave -noupdate -expand -group driver_eeprom -group counters -radix hexadecimal /tb_spi_eeprom_req/ser0/tx_addr_finish
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_opcode_d
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_address_d
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_data_d
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_bytes_d
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/clk_i
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/rstn_i
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_opcode_i
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_address_i
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_data_i
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_bytes_i
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/req_valid_i
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/ready_o
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/resp_data_o
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/resp_valid_o
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/state
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/next_state
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/mo_o
add wave -noupdate -expand -group driver_eeprom -group registers -radix hexadecimal /tb_spi_eeprom_req/ser0/mi_i
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/CS_N
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/HOLD_N
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/RESET
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SCK
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SI
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SO
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/AddrRegister
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/BitCounter
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/BufferWrFlags
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/DataShifterI
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/DataShifterO
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/EEPROM_WrEvent
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/EEPROMWriteProtected
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/EffectiveMPR
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/FRZR_Event
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/HardwareWriteProtected
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstRegister
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionCHLK
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionFRZR
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionLOCK
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionPPAB
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionPRWD
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionPRWE
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionRDEX
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionRDSR
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionREAD
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionRMPR
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionSPID
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionSRST
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionWMPR
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionWRBP
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionWRDI
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionWREN
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionWREX
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionWRITE
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/InstructionWRSR
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/LoopIndex
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MAN_ID
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryBlock
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00000
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte0000A
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte0000B
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte0000C
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte0000D
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte0000E
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte0000F
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00001
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF0
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF1
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF2
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF3
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF4
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF5
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF6
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF7
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF8
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFF9
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFFA
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFFB
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFFC
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFFD
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFFE
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte1FFFF
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00002
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00003
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00004
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00005
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00006
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00007
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00008
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MemoryByte00009
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR00
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR01
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR02
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR03
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR04
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR05
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR06
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR07
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_0
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_1
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_2
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_3
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_4
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_5
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_6
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_7
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPR_WrEvent
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPRBuffer
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/MPRWriteProtected
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/OutputEnable1
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/OutputEnable2
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/OutputEnable3
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer00
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer0A
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer0B
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer0C
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer0D
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer0E
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer0F
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer01
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer1A
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer1B
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer1C
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer1D
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer1E
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer1F
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer02
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer03
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer04
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer05
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer06
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer07
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer08
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer09
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer10
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer11
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer12
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer13
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer14
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer15
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer16
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer17
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer18
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBuffer19
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE0
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE1
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE2
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE3
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE4
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE5
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE6
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE7
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE8
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferE9
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferEA
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferEB
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferEC
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferED
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferEE
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferEF
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF0
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF1
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF2
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF3
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF4
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF5
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF6
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF7
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF8
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferF9
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferFA
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferFB
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferFC
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferFD
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferFE
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PageBufferFF
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PPAB_ClearEvent
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/PPAB_SetEvent
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SECREG_LockEvent
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SECREG_WrEvent
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte000
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte0FC
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte0FD
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte0FE
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte0FF
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte001
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte1FC
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte1FD
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte1FE
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte1FF
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte002
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte003
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte100
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte101
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte102
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegByte103
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegLock
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecRegWriteProtected
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SecurityReg
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_0
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_1
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_2
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_3
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_4
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_5
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_6
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_7
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_8
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_9
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_A
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_B
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_C
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_D
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_E
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SERIAL_NUM_F
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SO_DO
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SO_Enable
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/SO_OE
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_BP
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_ECS
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_FMPC
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_PABP
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_PREL
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_REG_DEFAULTS
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_WEL
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_WPEN
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_WPM
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/STATUS_WrEvent
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/StatusRegBuffer
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/tDIS
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/tHV
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/tHZ
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/TimingCheckEnable
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/tV
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/tWC
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/WP_N
add wave -noupdate -group MEM -radix hexadecimal /tb_spi_eeprom_req/mem0/WriteActive
add wave -noupdate -group tb /tb_spi_eeprom_req/clk
add wave -noupdate -group tb /tb_spi_eeprom_req/cs_n
add wave -noupdate -group tb /tb_spi_eeprom_req/mi
add wave -noupdate -group tb /tb_spi_eeprom_req/mo
add wave -noupdate -group tb /tb_spi_eeprom_req/ready
add wave -noupdate -group tb /tb_spi_eeprom_req/req_address
add wave -noupdate -group tb /tb_spi_eeprom_req/req_bytes
add wave -noupdate -group tb /tb_spi_eeprom_req/req_data
add wave -noupdate -group tb /tb_spi_eeprom_req/req_opcode
add wave -noupdate -group tb /tb_spi_eeprom_req/req_valid
add wave -noupdate -group tb /tb_spi_eeprom_req/reset
add wave -noupdate -group tb /tb_spi_eeprom_req/resp_data
add wave -noupdate -group tb /tb_spi_eeprom_req/resp_valid
add wave -noupdate -group tb /tb_spi_eeprom_req/spi_clk
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {Ini_read(0) {20800000 ps} 1} {Ini_write(0)-5 {4400000 ps} 1} {Ini_sreset {800000 ps} 1} {{Cursor 4} {844332 ps} 0}
quietly wave cursor active 4
configure wave -namecolwidth 314
configure wave -valuecolwidth 371
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
configure wave -timelineunits ps
update
WaveRestoreZoom {5043252575 ps} {5057618286 ps}
