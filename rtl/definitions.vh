`ifndef INCISIVE_SIMULATION
`define SYNTHESIS
`endif

`define LOW  1'b0
`define HIGH 1'b1

`define WIDTH_DATA        64
`define DATA              [`WIDTH_DATA-1:0]
`define ZERO_DATA         `WIDTH_DATA'b0
`define ONE_DATA          `WIDTH_DATA'b1

`define WIDTH_INS         32
`define INST              [`WIDTH_INS-1:0]
`define ZERO_INS          `WIDTH_INS'b0
`define NOP_INS           `ZERO_INS

`define WIDTH_ADDR        40
`define ADDR              [`WIDTH_ADDR-1:0]
`define ZERO_ADDR         `WIDTH_ADDR'b0

`define WIDTH_CBLOCK      128
`define CBLOCK            [`WIDTH_CBLOCK-1:0]
`define ZERO_128          WIDTH_CBLOCK'b0

`define WIDTH_SIZE        4
`define SIZE              [`WIDTH_SIZE-1:0]

`define WIDTH_MEM_OP      6
`define MEM_OP            [`WIDTH_MEM_OP-1:0]

/************************************************************************/
// LAGARTO CSR CAUSE FIELD
/************************************************************************/

`define misaligned_fetch        64'h0000000000000000
`define fault_fetch             64'h0000000000000001
`define illegal_instruction     64'h0000000000000002
`define breakpoint              64'h0000000000000003
`define misaligned_load         64'h0000000000000004
`define fault_load              64'h0000000000000005
`define misaligned_store        64'h0000000000000006
`define fault_store             64'h0000000000000007
`define user_ecall              64'h0000000000000008
`define supervisor_ecall        64'h0000000000000009
`define hypervisor_ecall        64'h000000000000000A
`define machine_ecall           64'h000000000000000B

