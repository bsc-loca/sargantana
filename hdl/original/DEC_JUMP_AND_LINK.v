//------------------------------------------------------------------------------------------------------------------------------------
//										  JUMP AND LINK - ISA: RISCV ISA RV32I
//------------------------------------------------------------------------------------------------------------------------------------
// The jump and link (JAL) instruction uses the J-type format, where the J-immediate encodes a signed offset in multiples of 2 bytes.
// The offset is sign-extended and added to the pc to form the jump target address. Jumps can therefore target a +-1 MiB range.
//	JAL stores the address of the instruction following the jump (pc+4) into register rd. The standard software calling convention
// uses x1 as the return address register and x5 as an alternate link register.
//	
//	Plain unconditional jumps (assembler pseudo-op J) are encoded as a JAL with rd=x0.
//
//	AUTOR: CRISTOBAL RAMIREZ LAZO	
//	 
//------------------------------------------------------------------------------------------------------------------------------------
`include "LAGARTO_CONFIG.v"

module DEC_JUMP_AND_LINK (
input		`ADDR			PC,
input		`WORD_INST	    Instruction,				
input		[15:0]		    Control_Signal,			

output						JUMP_LINK_ENA,
output		`ADDR           JUMP_LINK_target_addr
);

wire  		[19:0]		    DEC_IMM20_JAL;
wire  		`ADDR			DEC_IMM_JAL_SIGN_EXT;

assign 		DEC_IMM20_JAL = {Instruction[31],Instruction[19:12],Instruction[20],Instruction[30:21]};
assign 		DEC_IMM_JAL_SIGN_EXT = {{19{DEC_IMM20_JAL[19]}},DEC_IMM20_JAL[19:0],1'b0} ;

assign	JUMP_LINK_ENA		=	Control_Signal[5] & Control_Signal[3] & ~Control_Signal[0];
assign	JUMP_LINK_target_addr=	PC + DEC_IMM_JAL_SIGN_EXT;

endmodule
