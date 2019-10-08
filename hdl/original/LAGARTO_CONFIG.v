/************************************************************************/
/* LAGARTO CONFIGURATION FILE	   									    */
/************************************************************************/
`ifndef INCISIVE_SIMULATION
`define SYNTHESIS     
`endif

`define LOW  	1'b0
`define HIGH 	1'b1

`define WORD_WIDTH_DATA   64								
`define WORD_ZERO_64 	  64'b0
`define WORD_ONE_64 	  64'b1
`define WORD_DATA          [`WORD_WIDTH_DATA-1:0]

`define WORD_WIDTH_INS    32								
`define WORD_ZERO_32 	  32'b0
`define WORD_INST         [`WORD_WIDTH_INS-1:0]

`define WORD_ZERO_40 	  40'b0	
`define ADDR_WIDTH   	  40									
`define ADDR         	  [`ADDR_WIDTH-1:0]

`define WORD_ZERO_128 	  128'b0	
`define CACHE_LINE_WIDTH  128									
`define CACHE_LINE_SIZE   [`CACHE_LINE_WIDTH-1:0]

`define SIZE   			  4									
`define DATA_SIZE         [`SIZE-1:0]
								
`define NOP_INSTRUCTION   32'h00000000

/************************************************************************/
/* LAGARTO CSR CAUSE FIELD 									            */
/************************************************************************/

`define misaligned_fetch 	    64'h0000000000000000
`define fault_fetch 	        64'h0000000000000001	
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
