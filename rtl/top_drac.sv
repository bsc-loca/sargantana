//TODO: add DRAC header
//TODO: replace definitions with package drac
`include "definitions.vh" 

module top_drac(
//original inputs of lagarto
input 					    CLK,
input 					    RST,
input                       SOFT_RST,
input	`ADDR			    RESET_ADDRESS,
//CSR inputs
input    `DATA         CSR_RW_RDATA,
input                       CSR_CSR_STALL,
input                       CSR_XCPT,
input                       CSR_ERET,
input    `ADDR              CSR_EVEC,
input                       CSR_INTERRUPT,
input    `DATA         CSR_INTERRUPT_CAUSE,
//ICache
input 	`CBLOCK 	ICACHE_RESP_BITS_DATABLOCK,
input						ICACHE_RESP_VALID,
input						PTWINVALIDATE,
input						TLB_RESP_MISS,
input						TLB_RESP_XCPT_IF,
//DMEM
input                       DMEM_ORDERED,
input                       DMEM_REQ_READY,
input    `DATA         DMEM_RESP_BITS_DATA_SUBW,
input                       DMEM_RESP_BITS_NACK,
input                       DMEM_RESP_BITS_REPLAY,
input                       DMEM_RESP_VALID,
input                       DMEM_XCPT_MA_ST,
input                       DMEM_XCPT_MA_LD,
input                       DMEM_XCPT_PF_ST,
input                       DMEM_XCPT_PF_LD,
//fetch
input `ADDR		            IO_FETCH_PC_VALUE,
input			            IO_FETCH_PC_UPDATE,
//debug register file?
input                       IO_REG_READ,
input [4:0]                 IO_REG_ADDR,     
input                       IO_REG_WRITE,
input [63:0]                IO_REG_WRITE_DATA
//TODO:add outputs later

);
endmodule
