`include "LAGARTO_CONFIG.v"

module LATCH_DECODE_RR(
input 						CLK,
input 						RST,
input 						lock,
input 						FLUSH_P1,
input 						FLUSH_P2,

input 			`ADDR		PC_FROM_DECODE,
output 	reg	    `ADDR		PC_TO_RR,

input 				        PC_VALID_FROM_DEC,
output 	reg	    		    PC_VALID_TO_RR,
	
	
input 			`WORD_INST	INST_FROM_DECODE,
output 	reg	    `WORD_INST	INST_TO_RR,

input 			[15:0]		CONTROLSIGNAL_FROM_DECODE,
output 	reg	    [15:0]		CONTROLSIGNAL_TO_RR,

input                       DEC_XCPT,
input           `WORD_DATA  DEC_XCPT_CAUSE,
output  reg                 RR_XCPT,
output  reg     `WORD_DATA  RR_XCPT_CAUSE
);  

always@(posedge CLK)
begin
if(~RST)
	begin
	PC_TO_RR 					<=	`WORD_ZERO_40;
	INST_TO_RR					<=	`WORD_ZERO_32;
	CONTROLSIGNAL_TO_RR			<=	16'h0000;
	PC_VALID_TO_RR              <=	1'b0;
	RR_XCPT                     <=	1'b0;
    RR_XCPT_CAUSE               <=  64'b0;
	end
else if(FLUSH_P1) 
        begin
        PC_TO_RR                    <=    `WORD_ZERO_40;
        INST_TO_RR                  <=    `WORD_ZERO_32;
        CONTROLSIGNAL_TO_RR         <=    16'h0000;
        PC_VALID_TO_RR              <=    1'b0;
        RR_XCPT                     <=    1'b0;
        RR_XCPT_CAUSE               <=  64'b0;
        end
	else if(lock)
            begin
            PC_TO_RR					<=	PC_TO_RR;
            INST_TO_RR					<=	INST_TO_RR;
            CONTROLSIGNAL_TO_RR			<=	CONTROLSIGNAL_TO_RR;
            PC_VALID_TO_RR              <=	PC_VALID_TO_RR;
            RR_XCPT                     <=	RR_XCPT;
            RR_XCPT_CAUSE               <=  RR_XCPT_CAUSE;
            end
        else if(FLUSH_P2) 
                    begin
                    PC_TO_RR 					<=	`WORD_ZERO_40;
                    INST_TO_RR					<=	`WORD_ZERO_32;
                    CONTROLSIGNAL_TO_RR			<=	16'h0000;
                    PC_VALID_TO_RR              <=	1'b0;
                    RR_XCPT                     <=	1'b0;
                    RR_XCPT_CAUSE               <=  64'b0;
                    end
             else if(DEC_XCPT) 
                        begin
                        PC_TO_RR                    <=   PC_FROM_DECODE;
                        INST_TO_RR                  <=   `WORD_ZERO_32;
                        CONTROLSIGNAL_TO_RR         <=   16'h0000;
                        PC_VALID_TO_RR              <=   PC_VALID_FROM_DEC;
                        RR_XCPT                     <=   DEC_XCPT;
                        RR_XCPT_CAUSE               <=   DEC_XCPT_CAUSE;
                        end
					else
						begin
						PC_TO_RR					<=	PC_FROM_DECODE;
						INST_TO_RR					<=	INST_FROM_DECODE;
						CONTROLSIGNAL_TO_RR			<=	CONTROLSIGNAL_FROM_DECODE;
						PC_VALID_TO_RR              <=	PC_VALID_FROM_DEC;
						RR_XCPT                     <=	DEC_XCPT;
                        RR_XCPT_CAUSE               <=  DEC_XCPT_CAUSE;
						end
end

endmodule
