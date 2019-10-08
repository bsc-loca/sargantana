`include "LAGARTO_CONFIG.v"

module LATCH_FETCH_DECODE(
input 					CLK,
input 					RST,
input 					lock_PIPELINE,
input 					lock_FETCH,
input 					FLUSH_P1,
input 					FLUSH_P2,

input 		`ADDR 		PC_FROM_FETCH,
output 	reg	`ADDR		PC_TO_DECODE,

input 		 		    PC_VALID_FROM_FETCH,
output 	reg			    PC_VALID_TO_DEC,
	
input 		`WORD_INST	INST_FROM_FETCH,
output 	reg	`WORD_INST	INST_TO_DECODE,

input                   FETCH_XCPT,
input       `WORD_DATA  FETCH_XCPT_CAUSE,
output  reg             DEC_XCPT,
output  reg `WORD_DATA  DEC_XCPT_CAUSE
);
    

always@(posedge CLK)
begin
if(~RST)
	begin
	PC_TO_DECODE    <=	`WORD_ZERO_40;
	INST_TO_DECODE	<=	`WORD_ZERO_32;
	PC_VALID_TO_DEC <=	1'b0;
	DEC_XCPT        <=	1'b0;
	DEC_XCPT_CAUSE  <=	64'b0;
	end
	else if(FLUSH_P1) 
            begin
            PC_TO_DECODE     <=    `WORD_ZERO_40;
            INST_TO_DECODE    <=    `WORD_ZERO_32;
            PC_VALID_TO_DEC <=    1'b0;
            DEC_XCPT        <=    1'b0;
            DEC_XCPT_CAUSE  <=  64'b0;
            end    
	   else if(lock_PIPELINE) 
				begin
				PC_TO_DECODE	<=	PC_TO_DECODE;
				INST_TO_DECODE	<=	INST_TO_DECODE;
				PC_VALID_TO_DEC <=	PC_VALID_TO_DEC;
				DEC_XCPT        <=	DEC_XCPT;
                DEC_XCPT_CAUSE  <=  DEC_XCPT_CAUSE;
				end		
			else if(FLUSH_P2) 
                    begin
                    PC_TO_DECODE 	<=	`WORD_ZERO_40;
                    INST_TO_DECODE	<=	`WORD_ZERO_32;
                    PC_VALID_TO_DEC <=	1'b0;
                    DEC_XCPT        <=	1'b0;
                    DEC_XCPT_CAUSE  <=  64'b0;
                    end	
                else if (FETCH_XCPT)
                        begin
                        PC_TO_DECODE    <=    PC_FROM_FETCH;
                        INST_TO_DECODE  <=    `WORD_ZERO_32;
                        PC_VALID_TO_DEC <=    PC_VALID_FROM_FETCH;
                        DEC_XCPT        <=    FETCH_XCPT;
                        DEC_XCPT_CAUSE  <=    FETCH_XCPT_CAUSE;
                        end            
                     else 
                        begin
                        PC_TO_DECODE	<=	PC_FROM_FETCH;
                        INST_TO_DECODE	<=	INST_FROM_FETCH;
                        PC_VALID_TO_DEC <=	PC_VALID_FROM_FETCH;
                        DEC_XCPT        <=	FETCH_XCPT;
                        DEC_XCPT_CAUSE  <=  FETCH_XCPT_CAUSE;
                        end
end


endmodule
