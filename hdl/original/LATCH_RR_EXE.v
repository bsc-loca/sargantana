`include "LAGARTO_CONFIG.v"

module LATCH_RR_EXE(
input 			            CLK,
input 			            RST,
input 			            lock,
input 			            FLUSH_P1,
input 			            FLUSH_P2,
//input                       CSR_INTERRUPT,

input 			`ADDR	    PC_FROM_RR,
output 	reg	    `ADDR		PC_TO_EXE,

input 				        PC_VALID_FROM_RR,
output 	reg	        		PC_VALID_TO_EXE,
	
input 			`WORD_INST	INST_FROM_RR,
output 	reg	    `WORD_INST	INST_TO_EXE,

input 			[15:0]		CONTROLSIGNAL_FROM_RR,
output 	reg	    [15:0]		CONTROLSIGNAL_TO_EXE,

input 			`WORD_DATA	Src1_Data_FROM_RR,
output 		    `WORD_DATA	Src1_Data_TO_EXE,

input 			`WORD_DATA	Src2_Data_FROM_RR,
output 		    `WORD_DATA	Src2_Data_TO_EXE,

input                       RR_XCPT,
input           `WORD_DATA  RR_XCPT_CAUSE,
output  reg                 EXE_XCPT,
output  reg     `WORD_DATA  EXE_XCPT_CAUSE
);  

reg 	    `WORD_DATA	aux_Src1_Data_TO_EXE;
reg 	    `WORD_DATA	aux_Src2_Data_TO_EXE;

reg src_select;

always @(posedge CLK) begin
  if(~RST)
    src_select <= 1'b1;
  else
    src_select <= FLUSH_P1 || lock || FLUSH_P1 || (/*CSR_INTERRUPT |*/ RR_XCPT);
end

// Bypass the src_Data_FROM_RR signals to compensate for the delay introduced by the SRAM memory
assign Src1_Data_TO_EXE = src_select ? aux_Src1_Data_TO_EXE : Src1_Data_FROM_RR;
assign Src2_Data_TO_EXE = src_select ? aux_Src2_Data_TO_EXE : Src2_Data_FROM_RR;


always@(posedge CLK)
begin
if(~RST)
	begin
	PC_TO_EXE 				<=	`WORD_ZERO_40;
	INST_TO_EXE				<=	`WORD_ZERO_32;
	CONTROLSIGNAL_TO_EXE	<=	16'h0000;
	aux_Src1_Data_TO_EXE 		<=	`WORD_ZERO_64;
	aux_Src2_Data_TO_EXE 		<=	`WORD_ZERO_64;
	PC_VALID_TO_EXE         <=	1'b0;
	EXE_XCPT                 <=	1'b0;
    EXE_XCPT_CAUSE           <=  64'b0;
	end
else if(FLUSH_P1) 
        begin
        PC_TO_EXE                     <=    `WORD_ZERO_40;
        INST_TO_EXE                    <=    `WORD_ZERO_32;
        CONTROLSIGNAL_TO_EXE        <=    16'h0000;
        aux_Src1_Data_TO_EXE             <=    `WORD_ZERO_64;
        aux_Src2_Data_TO_EXE             <=    `WORD_ZERO_64;
        PC_VALID_TO_EXE             <=    1'b0;
        EXE_XCPT                    <=    1'b0;     
        EXE_XCPT_CAUSE              <=  64'b0;
        end
	else if(lock)
            begin
            PC_TO_EXE				<=	PC_TO_EXE;
            INST_TO_EXE				<=	INST_TO_EXE;
            CONTROLSIGNAL_TO_EXE	<=	CONTROLSIGNAL_TO_EXE;
            aux_Src1_Data_TO_EXE 		<=	Src1_Data_TO_EXE;
            aux_Src2_Data_TO_EXE 		<=	Src2_Data_TO_EXE;
            PC_VALID_TO_EXE         <=	PC_VALID_TO_EXE;
            EXE_XCPT                <=	EXE_XCPT;     
            EXE_XCPT_CAUSE          <=  EXE_XCPT_CAUSE;
            end
		else if(FLUSH_P2) 
                begin
                PC_TO_EXE 					<=	`WORD_ZERO_40;
                INST_TO_EXE					<=	`WORD_ZERO_32;
                CONTROLSIGNAL_TO_EXE		<=	16'h0000;
                aux_Src1_Data_TO_EXE 			<=	`WORD_ZERO_64;
                aux_Src2_Data_TO_EXE 			<=	`WORD_ZERO_64;
                PC_VALID_TO_EXE             <=	1'b0;
                EXE_XCPT                    <=	1'b0;     
                EXE_XCPT_CAUSE              <=  64'b0;
                end
            /*
             else if(CSR_INTERRUPT | RR_XCPT) 
                    begin
                    PC_TO_EXE                   <=    PC_FROM_RR;
                    INST_TO_EXE                 <=    `WORD_ZERO_32;
                    CONTROLSIGNAL_TO_EXE        <=    16'h0000;
                    aux_Src1_Data_TO_EXE            <=    `WORD_ZERO_64;
                    aux_Src2_Data_TO_EXE            <=    `WORD_ZERO_64;
                    PC_VALID_TO_EXE             <=    PC_VALID_FROM_RR;
                    EXE_XCPT                    <=    RR_XCPT;     
                    EXE_XCPT_CAUSE              <=    RR_XCPT_CAUSE;
                    end*/
                  else
                    begin
                    PC_TO_EXE				<=	PC_FROM_RR;
                    INST_TO_EXE				<=	INST_FROM_RR;
                    CONTROLSIGNAL_TO_EXE	<=	RR_XCPT ? 16'h0000 : CONTROLSIGNAL_FROM_RR;
                    aux_Src1_Data_TO_EXE 	<=	Src1_Data_FROM_RR;
                    aux_Src2_Data_TO_EXE 	<=	Src2_Data_FROM_RR;
                    PC_VALID_TO_EXE         <=	PC_VALID_FROM_RR;
                    EXE_XCPT                <=	RR_XCPT;     
                    EXE_XCPT_CAUSE          <=  RR_XCPT_CAUSE;
                    end
end

endmodule
