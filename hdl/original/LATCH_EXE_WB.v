`include "LAGARTO_CONFIG.v"

module LATCH_EXE_WB(
input 						CLK,
input 						RST,
input 						lock,
input 						FLUSH,

//TODO: commented due to TODO #1
//input                       EXE_BRANCH,
//TODO: #1 WB_BRANCH is ignored in instance . Remove it and
//associated logic or do something with result
//output  reg                 WB_BRANCH,

input 			`ADDR		PC_FROM_EXE,
input                       PC_VALID_FROM_EXE,

input 			`WORD_INST	INST_FROM_EXE,
output 	reg	    `WORD_INST	INST_TO_WB,

input 						WE_FROM_EXE,
input 			`WORD_DATA	DATA_FROM_EXE,
input 			[4:0]		WRITE_ADDR_FROM_EXE,

output 	reg	    `ADDR		PC_TO_WB,
output  reg                 PC_VALID_TO_WB,

output 	reg					WE_TO_WB,	
output 	reg     `WORD_DATA	DATA_TO_WB,	
output 	reg	    [4:0]		ADDR_TO_WB,	

input						EXE_CSR_ENABLE,	
output	reg					WB_CSR_ENABLE,	
output  reg     `WORD_DATA  DATA_TO_CSR,

input                       EXE_XCPT,
input           `WORD_DATA  EXE_XCPT_CAUSE,
output  reg                 WB_XCPT,
output  reg     `WORD_DATA  WB_XCPT_CAUSE,

input           `ADDR       DMEM_REQ_BITS_ADDR,
output  reg     `ADDR       WB_REQ_BITS_ADDR

//output  reg                 lock_DELAY
);

wire	`ADDR			PC_TO_WB_AUX;	
wire					WE_TO_WB_AUX;
wire	`WORD_DATA	    DATA_TO_WB_AUX;
wire	[4:0]			ADDR_TO_WB_AUX;

assign	PC_TO_WB_AUX = (PC_VALID_FROM_EXE) ? PC_FROM_EXE: `WORD_ZERO_40;
assign	WE_TO_WB_AUX = (PC_VALID_FROM_EXE) ? (WE_FROM_EXE) ? 1'b1:1'b0:1'b0;	
assign	DATA_TO_WB_AUX =  (PC_VALID_FROM_EXE) ? (WE_FROM_EXE) ? DATA_FROM_EXE: 64'b0: 64'b0;
assign	ADDR_TO_WB_AUX = (PC_VALID_FROM_EXE) ? (WE_FROM_EXE) ? WRITE_ADDR_FROM_EXE : 5'b0: 5'b0;

reg						WE_TO_WB_AUX2;	     

always@(posedge CLK)

begin
if(~RST)
	begin
	PC_VALID_TO_WB          <=	1'b0;   
	PC_TO_WB 				<=	`WORD_ZERO_40;
	INST_TO_WB              <=	`WORD_ZERO_32;
	WE_TO_WB    		    <=	1'b0;
	DATA_TO_WB			    <=	`WORD_ZERO_64;
	ADDR_TO_WB              <=	5'b00000;
	
	WB_CSR_ENABLE           <=	1'b0;
	DATA_TO_CSR             <=	`WORD_ZERO_64;
	WB_XCPT                 <=	1'b0;
    WB_XCPT_CAUSE           <=  64'b0;
    
//TODO: commented due to TODO #1
//    WB_BRANCH               <=	1'b0;
    
    WB_REQ_BITS_ADDR        <=	`WORD_ZERO_40; 
	end 
else if (lock)
        begin
        PC_VALID_TO_WB              <=    PC_VALID_TO_WB; 
        PC_TO_WB                    <=    PC_TO_WB;
        INST_TO_WB                  <=    INST_TO_WB;
        WE_TO_WB                    <=    WE_TO_WB;
        DATA_TO_WB                  <=    DATA_TO_WB;
        ADDR_TO_WB                  <=    ADDR_TO_WB;
        
        WB_CSR_ENABLE               <=    WB_CSR_ENABLE;
        DATA_TO_CSR                 <=    DATA_TO_CSR;
        WB_XCPT                     <=    WB_XCPT;
        WB_XCPT_CAUSE               <=  WB_XCPT_CAUSE;
        
//TODO: commented due to TODO #1
// WB_BRANCH                   <=	WB_BRANCH;
        
        WB_REQ_BITS_ADDR            <=	WB_REQ_BITS_ADDR; 
        end
    else	if(FLUSH ) 
                begin
                PC_VALID_TO_WB              <=	1'b0; 
                PC_TO_WB 					<=	`WORD_ZERO_40;
                INST_TO_WB                  <=	`WORD_ZERO_32;
                WE_TO_WB  				    <=	1'b0;
                DATA_TO_WB				    <=	`WORD_ZERO_64;
                ADDR_TO_WB			        <=	5'b00000;
                
                WB_CSR_ENABLE               <=	1'b0;
                DATA_TO_CSR                 <=	`WORD_ZERO_64;
                WB_XCPT                     <=	1'b0;
                WB_XCPT_CAUSE               <=  64'b0;
                
//TODO: commented due to TODO #1
// WB_BRANCH                   <=	1'b0;
                WB_REQ_BITS_ADDR            <=	`WORD_ZERO_40; 
                end
           else 
                begin
                PC_VALID_TO_WB              <=    PC_VALID_FROM_EXE; 
                PC_TO_WB                    <=    PC_TO_WB_AUX;
                INST_TO_WB                  <=    INST_FROM_EXE;
                WE_TO_WB                    <=    WE_TO_WB_AUX;
                DATA_TO_WB                  <=    DATA_TO_WB_AUX;
                ADDR_TO_WB                  <=    ADDR_TO_WB_AUX;
                
                WB_CSR_ENABLE               <=    EXE_CSR_ENABLE;
                DATA_TO_CSR                 <=    DATA_FROM_EXE;
                WB_XCPT                     <=    EXE_XCPT;
                WB_XCPT_CAUSE               <=    EXE_XCPT_CAUSE;
                
//TODO: commented due to TODO #1
// WB_BRANCH                   <=	  EXE_BRANCH;
                WB_REQ_BITS_ADDR            <=	  DMEM_REQ_BITS_ADDR; 
                end
					
end

endmodule
