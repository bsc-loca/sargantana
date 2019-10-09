//----------------------------------------------------------------------------------------------------------------------
//										  INTEGER FUNCTIONAL UNIT - ISA: RISCV ISA RV64I
//---------------------------------------------------------------------------------------------------------------------- 
// Integer computational instructions are either encoded as register-immediate operations using
// the I-type format or as register-register operations using the R-type format.  
//	The destination is register rd for both register-immediate and register-register instructions. 
//---------------------------------------------------------------------------------------------------------------------- 
//	EXCEPTIONS
// No integer computational instructions cause arithmetic exceptions.
//	SLLIW, SRLIW, and SRAIW generate an illegal	instruction exception if imm[5] 6= 0.
//
//
//	AUTOR: CRISTOBAL RAMIREZ LAZO	
//	 
//---------------------------------------------------------------------------------------------------------------------- 
`include "LAGARTO_CONFIG.v"

module EXE_INTEGER_UNIT(
input					CLK,							
input					RST,																												

input                   WB_EXCEPTION,

input 	     `ADDR		PC,
input 					valid_inst,
input					INT_32,
input					valid_opcode,
input					Immediate,	
input		[6:0]		OPCODE_FIELD,
input		[2:0]		Funct3_FIELD,					
input		[6:0]		Funct7_FIELD,	
input		[4:0]		RD_FIELD,

input		`WORD_DATA	Data_Source_1,						
input		`WORD_DATA	Data_Source_2,									
input		[11:0]		Source_Immediate_12,
input		[19:0]		Source_Immediate_20,			
	
output					Ready,	
output	    `WORD_DATA	ALUresult,										
output	    [4:0]		Addr_write,	


// JAL and JALR
input					jal_valid,				
input					jalr_valid,		
output	     `ADDR		jalr_ADDR,
output					jalr_ready,

output					lock_EXT_M

//TODO: #1 Commented  beacuse signal is unused in instance EXE_INTEGER_UNIT
//      Remove it or do something useful with it
//,
//output					EXCEPCION_ILLEGAL_INST
);

wire		`WORD_DATA	Source_1;						
wire		`WORD_DATA	Source_2;	

assign      Source_1 = (INT_32) ? {32'h0,Data_Source_1[31:0]} : Data_Source_1;
assign      Source_2 = (INT_32) ? {32'h0,Data_Source_2[31:0]} : Data_Source_2;

reg 		`WORD_DATA	ALUresult_aux;
reg 					Ready_aux;
//TODO: commented due to TODO #1
//reg 					Illegal_Inst_Exception_aux;
wire 		`WORD_DATA	Source2_Immediate_64;
wire 		`WORD_DATA	Source2_Immediate_64_AUX;
wire 		[5:0]		shamt;
wire 		[5:0]		shamt_aux;
wire 		[5:0]		shiftWord;

wire 		`WORD_DATA Shift_Right_Arith;

// ------------------------------------------------------------------------------------------------------
// SHIFT WORD INSTRUCTIONS AND IMMEDIATE OPERANDS
// ------------------------------------------------------------------------------------------------------

assign 	Source2_Immediate_64_AUX =  {{52{Source_Immediate_12[11]}},Source_Immediate_12[11:0]} ;
assign 	Source2_Immediate_64 = (INT_32) ?  {32'h0,Source2_Immediate_64_AUX[31:0]}:Source2_Immediate_64_AUX;

assign 	shamt = Source_Immediate_12[5:0] ;
assign 	shiftWord = (INT_32) ? {1'b0,Source_2[4:0]}: Source_2[5:0] ;
assign 	shamt_aux = (Immediate) ? shamt:shiftWord;

 Shift_Word_Right_Arith Shift_Word_Right_Arith(
.shamt			(shamt_aux),
.INT_32         (INT_32),
.Input_Data		(Source_1),
.Output_Data	(Shift_Right_Arith)
);

// ------------------------------------------------------------------------------------------------------
// MULTIPLICATION  INSTRUCTIONS
// ------------------------------------------------------------------------------------------------------

wire                  KILL_M_EXT;
assign     KILL_M_EXT = WB_EXCEPTION;

wire 					lock_EXT_mul;
wire 					ready_mul;
wire 					signed_mul;
wire 					Valid_mul;
wire 		[63:0]  	mul_result;

assign Valid_mul = ((Funct3_FIELD == 3'b000) |(Funct3_FIELD == 3'b001) |(Funct3_FIELD == 3'b010) | (Funct3_FIELD == 3'b011)) & (Funct7_FIELD == 7'b0000001) & valid_inst & ~Immediate;

 INT_MUL_64B INT_MUL_64B (
    .clk_i(CLK),
    .rst_ni(RST),
    .kill_mul_i(KILL_M_EXT),
    .request_i(Valid_mul),
    .func3(Funct3_FIELD),
    .int_32_i(INT_32),
    .src1_i(Source_1),
    .src2_i(Source_2),
    .result_o(mul_result),
    .stall_o(lock_EXT_mul),
    .done_tick_o(ready_mul)
);

// ------------------------------------------------------------------------------------------------------
// DIVISION AND REMINDER INSTRUCTIONS
// ------------------------------------------------------------------------------------------------------
//The semantics for division by zero and division overflow are summarized below. 
//The quotient of division by zero has all bits set, i.e. 2XLEN-1 for unsigned division or -1 for signed division.
//The remainder of division by zero equals the dividend.
//Signed division overflow occurs only when the most-negative integer, 2XLEN-1, is divided by -1. The quotient of signed division 
//overflow is equal to the dividend, and the remainder is zero. Unsigned division overflow cannot occur.
//
//											DIVIDEND	DIVISOR	DIVU 			REMU	DIV 			REM
// DIVISION_BY_ZERO_EXCEPTION	      X       0       2^leng-1	 X    -1    		X		
// OVERFLOW_EXCEPTION				 -2^leng-1  -1      -           -   -2^leng-1   0
// ------------------------------------------------------------------------------------------------------
wire 		[63:0]  	div_result;
wire 		[63:0]  	rem_result;
wire				  	ready_DIV_REM;
wire				  	signed_DIV;
wire				  	Valid_DIV;
wire 				  	lock_EXT_div;

assign 	signed_DIV = ~Funct3_FIELD[0];
assign 	Valid_DIV = ((Funct3_FIELD == 3'b100) |(Funct3_FIELD == 3'b101) |(Funct3_FIELD == 3'b110) | (Funct3_FIELD == 3'b111)) & (Funct7_FIELD == 7'b0000001) & valid_inst & ~Immediate;

 INT_DIV_64B INT_DIV_64B (
    .clk_i(CLK),
    .rst_ni(RST),
    .kill_div_i(KILL_M_EXT),
    .request_i(Valid_DIV),
    .int_32_i(INT_32),
    .signed_op_i(signed_DIV),
    .dvnd_i(Data_Source_1),
    .dvsr_i(Data_Source_2),
    .quo_o(div_result),
    .rmd_o(rem_result),
    .stall_o(lock_EXT_div),
    .done_tick_o(ready_DIV_REM)
);

assign lock_EXT_M = lock_EXT_div | lock_EXT_mul;

// ------------------------------------------------------------------------------------------------------						
always@(*)
begin

case ({valid_inst,Immediate,Funct3_FIELD})
// ------------------------------------------------------------------------------------------------------
// REGISTER-REGISTER INSTRUCTIONS
// ------------------------------------------------------------------------------------------------------
	
	5'b10000:  begin		
						case(Funct7_FIELD)
						// Add Word  - ADD , 
						7'b0000000:	begin
										ALUresult_aux= Source_1 + Source_2;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						// Subtract Word - SUB
						7'b0100000:	begin
										ALUresult_aux= Source_1 - Source_2;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						// Multiply word, Low part, Signed - MUL , MULW
						7'b0000001:	begin
										ALUresult_aux= mul_result;
										Ready_aux= ready_mul;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end	
						default:		begin
										ALUresult_aux= `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b1;
										end
						endcase
					end	
					

	5'b10001:  begin	
						case(Funct7_FIELD)
						// Shift Word Left Logical - SLL
						7'b0000000:	begin
										ALUresult_aux= Source_1 << shiftWord ;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						// Multiply word, High part, Signed - MULH
						7'b0000001:	begin
										ALUresult_aux= mul_result;
										Ready_aux= ready_mul;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end	
						default:		begin
										ALUresult_aux= `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b1;
										end
						endcase
					end

					
	
	5'b10010:  begin		
						case(Funct7_FIELD)
						// Set On Less Than - SLT
						7'b0000000:	begin
										ALUresult_aux= ( $signed(Source_1) < $signed(Source_2))  ? `WORD_ONE_64 : `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						// Multiply word, High part, SignedxUnsigned - MULHSU
						7'b0000001:	begin
										ALUresult_aux= mul_result;
										Ready_aux= ready_mul;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end	
						default:		begin
										ALUresult_aux= `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b1;
										end
						endcase
					end

	
	5'b10011:  begin		
						case(Funct7_FIELD)
						//Set On Less Than Unsigned - SLTU
						7'b0000000:	begin
										ALUresult_aux= ( Source_1 < Source_2)  ? `WORD_ONE_64 : `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						//	Multiply word, High part, Unsigned Unsigned MULHU
						7'b0000001:	begin
										ALUresult_aux= mul_result;
										Ready_aux= ready_mul;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end	
						default:		begin
										ALUresult_aux= `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b1;
										end
						endcase
					end	
				
	5'b10100:  begin		
						case(Funct7_FIELD)
						//Exclusive Or - XOR  
						7'b0000000:	begin
										ALUresult_aux= Source_1 ^ Source_2;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						//	Divide words, Signed DIV
						7'b0000001:	begin
										ALUresult_aux= div_result;
										Ready_aux= ready_DIV_REM;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end	
						default:		begin
										ALUresult_aux= `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b1;
										end
						endcase
					end						
	
	5'b10101:  begin	
						case(Funct7_FIELD)
						//Shift Word Right Logical - SRL 
						7'b0000000:	begin
										ALUresult_aux= Source_1 >> shiftWord;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						//Shift Word Right Arithmetic - SRA
						7'b0100000:	begin
										ALUresult_aux= Shift_Right_Arith;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end				
						//	Divide words, Unsigned DIV 
						7'b0000001:	begin
										ALUresult_aux= div_result;
										Ready_aux= ready_DIV_REM;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end	
						default:		begin
										ALUresult_aux= `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b1;
										end
						endcase
					end								
	5'b10110:  begin	
						case(Funct7_FIELD)
						// OR  
						7'b0000000:	begin
										ALUresult_aux= Source_1 | Source_2;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						//	Remider, Signed - REM
						7'b0000001:	begin
										ALUresult_aux= rem_result;
										Ready_aux= ready_DIV_REM;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end	
						default:		begin
										ALUresult_aux= `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b1;
										end
						endcase
					end					
					
	5'b10111:  begin	
						case(Funct7_FIELD)
						// AND  
						7'b0000000:	begin
										ALUresult_aux= Source_1 & Source_2;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end
						//	Remider, Unsigned - REMU
						7'b0000001:	begin
										ALUresult_aux= rem_result;
										Ready_aux= ready_DIV_REM;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b0;
										end	
						default:		begin
										ALUresult_aux= `WORD_ZERO_64;
										Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//										Illegal_Inst_Exception_aux = 1'b1;
										end
						endcase
					end								
// ------------------------------------------------------------------------------------------------------
// REGISTER-IMMEDIATE INSTRUCTIONS
// ------------------------------------------------------------------------------------------------------
	
	// Add Immediate - ADDI
	5'b11000:  	begin	
					ALUresult_aux= Source_1 + Source2_Immediate_64;
					Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//					Illegal_Inst_Exception_aux = 1'b0;

					end	
	// Shift Word Left Logical Immediate - SLLI , SLLIW
	5'b11001:  begin		
						if(Funct7_FIELD[6:1] == 6'b000000)
							begin
							ALUresult_aux= Source_1 << shamt;
							Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//							Illegal_Inst_Exception_aux = INT_32 & shamt[5];
							end
						else
							begin
							ALUresult_aux=  `WORD_ZERO_64;
							Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//							Illegal_Inst_Exception_aux = 1'b1;
							end
					end
	// Set on Less Than immediate - SLTI			
	5'b11010:  	begin		
					ALUresult_aux= ( $signed(Source_1) < $signed(Source2_Immediate_64))  ? `WORD_ONE_64 : `WORD_ZERO_64;
					Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//					Illegal_Inst_Exception_aux = 1'b0;
					end	
    // Set on Less Than immediate Unsigned - SLTIU			
    5'b11011:      begin        
                    ALUresult_aux= ( Source_1 < Source2_Immediate_64)  ? `WORD_ONE_64 : `WORD_ZERO_64;
                    Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//                    Illegal_Inst_Exception_aux = 1'b0;
                    end    
	// XOR Immediate - XORI
	5'b11100:  	begin		
					ALUresult_aux= Source_1 ^ Source2_Immediate_64;
					Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//					Illegal_Inst_Exception_aux = 1'b0;
					end
	//Shift Word Right Logical Imediate, Shift Word Right Arithmetic Imediate - SRLI , SRAI , SRLIW , SRAIW
	5'b11101:  begin		
						if(Funct7_FIELD[6:1] == 6'b000000)
							begin
							ALUresult_aux= Source_1 >> shamt;
							Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//							Illegal_Inst_Exception_aux = INT_32 & shamt[5];
							end
						else	if(Funct7_FIELD[6:1] == 6'b010000)
									begin
									ALUresult_aux= Shift_Right_Arith;
									Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//									Illegal_Inst_Exception_aux = INT_32 & shamt[5];
									end
								else
									begin
									ALUresult_aux= `WORD_ZERO_64;
									Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//									Illegal_Inst_Exception_aux = 1'b1;
									end
					end	
	// OR Immediate - ORI
	5'b11110:  	begin		
					ALUresult_aux= Source_1 | Source2_Immediate_64;
					Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//					Illegal_Inst_Exception_aux = 1'b0;
					end	
	// And Immediate - ANDI
	5'b11111:  	begin		
					ALUresult_aux= Source_1 & Source2_Immediate_64;
					Ready_aux= 1'b1;
//TODO: commented due to TODO #1
//					Illegal_Inst_Exception_aux = 1'b0;
					end					
	default:  	begin
						ALUresult_aux= `WORD_ZERO_64;
						Ready_aux= 1'b0;
//TODO: commented due to TODO #1
//						Illegal_Inst_Exception_aux = 1'b0;
					end
					
endcase
end

// ------------------------------------------------------------------------------------------------------
// OPERATIONS CONTROLED BY ONLY OPCODE
// ------------------------------------------------------------------------------------------------------
reg 	`WORD_DATA	ALUresult_aux2;
reg 					Ready_aux2;

wire 	`WORD_DATA	Source_Immediate_64;
assign 				Source_Immediate_64 = {{32{Source_Immediate_20[19]}},Source_Immediate_20[19:0],12'b0} ;  
						
always@(*)
begin

case (OPCODE_FIELD[6:2])

	// Load Upper Immediate - LUI
	5'b01101:  	begin		
					ALUresult_aux2= Source_Immediate_64;
					Ready_aux2= 1'b1;
					end
	// Add Upper Immediate to PC - AUIPC  
	5'b00101:  	begin		
					ALUresult_aux2= Source_Immediate_64 + {{24{PC[39]}},PC};
					Ready_aux2= 1'b1;
					end		
					
	default:  	begin
					ALUresult_aux2= `WORD_ZERO_64;
					Ready_aux2= 1'b0;
					end
					
endcase
end

assign Ready = 			( (jal_valid | jalr_valid) & (RD_FIELD > 5'b00000)) ? 1'b1:(valid_opcode) ? Ready_aux2:Ready_aux;

assign Addr_write=		(valid_inst | jalr_valid | jal_valid | valid_opcode) ?  RD_FIELD:5'b0;
assign ALUresult = 		( jalr_valid | jal_valid) ?  {{24{PC[39]}},PC} + 64'h4 :(valid_opcode) ? ALUresult_aux2: (INT_32) ? {{32{ALUresult_aux[31]}},ALUresult_aux[31:0]}:ALUresult_aux;

//TODO: Commented due to TODO #1
//TODO: commented due to TODO #1
////assign 	EXCEPCION_ILLEGAL_INST = 	Illegal_Inst_Exception_aux;


wire 	`ADDR	 jalr_ADDR_aux;
//assign jalr_ADDR_aux = 	(jalr_valid) ?  Source_1 + Source2_Immediate_64:`WORD_ZERO_64;
assign jalr_ADDR_aux = 	(jalr_valid) ?  Source_1 [39:0] + Source2_Immediate_64[39:0]:`WORD_ZERO_40;
assign jalr_ADDR = 		{jalr_ADDR_aux[39:1],1'b0};
assign jalr_ready = 		jalr_valid;

endmodule


//-----------------------------------------------------------------------------------------------
// Functional Unit - Shift_Word_Right_Arithmetic
//-----------------------------------------------------------------------------------------------

module Shift_Word_Right_Arith (
input 		[5:0]			shamt,
input                       INT_32,
input 		`WORD_DATA 	Input_Data,
output reg 	`WORD_DATA 	Output_Data
);

always@(*)
begin
case (shamt)

		6'b000000:	Output_Data=  Input_Data ;
		
		6'b000001:	Output_Data= (INT_32) ? {{1{Input_Data[31]}},Input_Data[31:1]}:{{1{Input_Data[63]}},Input_Data[63:1]} ;
		6'b000010:	Output_Data= (INT_32) ? {{2{Input_Data[31]}},Input_Data[31:2]}: {{2{Input_Data[63]}},Input_Data[63:2]} ;
		6'b000011:	Output_Data= (INT_32) ? {{3{Input_Data[31]}},Input_Data[31:3]}: {{3{Input_Data[63]}},Input_Data[63:3]} ;
		6'b000100:	Output_Data= (INT_32) ? {{4{Input_Data[31]}},Input_Data[31:4]}: {{4{Input_Data[63]}},Input_Data[63:4]} ;
		6'b000101:	Output_Data= (INT_32) ? {{5{Input_Data[31]}},Input_Data[31:5]}: {{5{Input_Data[63]}},Input_Data[63:5]} ;
		6'b000110:	Output_Data= (INT_32) ? {{6{Input_Data[31]}},Input_Data[31:6]}: {{6{Input_Data[63]}},Input_Data[63:6]} ;
		6'b000111:	Output_Data= (INT_32) ? {{7{Input_Data[31]}},Input_Data[31:7]}: {{7{Input_Data[63]}},Input_Data[63:7]} ;
		6'b001000:	Output_Data= (INT_32) ? {{8{Input_Data[31]}},Input_Data[31:8]}: {{8{Input_Data[63]}},Input_Data[63:8]} ;
		
		6'b001001:	Output_Data= (INT_32) ? {{9{Input_Data[31]}},Input_Data[31:9]}: {{9{Input_Data[63]}},Input_Data[63:9]} ;
		6'b001010:	Output_Data= (INT_32) ? {{10{Input_Data[31]}},Input_Data[31:10]}: {{10{Input_Data[63]}},Input_Data[63:10]} ;
		6'b001011:	Output_Data= (INT_32) ? {{11{Input_Data[31]}},Input_Data[31:11]}: {{11{Input_Data[63]}},Input_Data[63:11]} ;
		6'b001100:	Output_Data= (INT_32) ? {{12{Input_Data[31]}},Input_Data[31:12]}: {{12{Input_Data[63]}},Input_Data[63:12]} ;
		6'b001101:	Output_Data= (INT_32) ? {{13{Input_Data[31]}},Input_Data[31:13]}: {{13{Input_Data[63]}},Input_Data[63:13]} ;
		6'b001110:	Output_Data= (INT_32) ? {{14{Input_Data[31]}},Input_Data[31:14]}: {{14{Input_Data[63]}},Input_Data[63:14]} ;
		6'b001111:	Output_Data= (INT_32) ? {{15{Input_Data[31]}},Input_Data[31:15]}: {{15{Input_Data[63]}},Input_Data[63:15]} ;
		6'b010000:	Output_Data= (INT_32) ? {{16{Input_Data[31]}},Input_Data[31:16]}: {{16{Input_Data[63]}},Input_Data[63:16]} ;
		
		6'b010001:	Output_Data= (INT_32) ? {{17{Input_Data[31]}},Input_Data[31:17]}: {{17{Input_Data[63]}},Input_Data[63:17]} ;
		6'b010010:	Output_Data= (INT_32) ? {{18{Input_Data[31]}},Input_Data[31:18]}: {{18{Input_Data[63]}},Input_Data[63:18]} ;
		6'b010011:	Output_Data= (INT_32) ? {{19{Input_Data[31]}},Input_Data[31:19]}: {{19{Input_Data[63]}},Input_Data[63:19]} ;
		6'b010100:	Output_Data= (INT_32) ? {{20{Input_Data[31]}},Input_Data[31:20]}: {{20{Input_Data[63]}},Input_Data[63:20]} ;
		6'b010101:	Output_Data= (INT_32) ? {{21{Input_Data[31]}},Input_Data[31:21]}: {{21{Input_Data[63]}},Input_Data[63:21]} ;
		6'b010110:	Output_Data= (INT_32) ? {{22{Input_Data[31]}},Input_Data[31:22]}: {{22{Input_Data[63]}},Input_Data[63:22]} ;
		6'b010111:	Output_Data= (INT_32) ? {{23{Input_Data[31]}},Input_Data[31:23]}: {{23{Input_Data[63]}},Input_Data[63:23]} ;
		6'b011000:	Output_Data= (INT_32) ? {{24{Input_Data[31]}},Input_Data[31:24]}: {{24{Input_Data[63]}},Input_Data[63:24]} ;

		6'b011001:	Output_Data= (INT_32) ? {{25{Input_Data[31]}},Input_Data[31:25]}: {{25{Input_Data[63]}},Input_Data[63:25]} ;
		6'b011010:	Output_Data= (INT_32) ? {{26{Input_Data[31]}},Input_Data[31:26]}: {{26{Input_Data[63]}},Input_Data[63:26]} ;
		6'b011011:	Output_Data= (INT_32) ? {{27{Input_Data[31]}},Input_Data[31:27]}: {{27{Input_Data[63]}},Input_Data[63:27]} ;
		6'b011100:	Output_Data= (INT_32) ? {{28{Input_Data[31]}},Input_Data[31:28]}: {{28{Input_Data[63]}},Input_Data[63:28]} ;
		6'b011101:	Output_Data= (INT_32) ? {{29{Input_Data[31]}},Input_Data[31:29]}: {{29{Input_Data[63]}},Input_Data[63:29]} ;
		6'b011110:	Output_Data= (INT_32) ? {{30{Input_Data[31]}},Input_Data[31:30]}: {{30{Input_Data[63]}},Input_Data[63:30]} ;
		6'b011111:	Output_Data= (INT_32) ? {{31{Input_Data[31]}},Input_Data[31]}: {{31{Input_Data[63]}},Input_Data[63:31]} ;
		
		6'b100000:	Output_Data=  {{32{Input_Data[63]}},Input_Data[63:32]} ;
		6'b100001:	Output_Data=  {{33{Input_Data[63]}},Input_Data[63:33]} ;
		6'b100010:	Output_Data=  {{34{Input_Data[63]}},Input_Data[63:34]} ;
		6'b100011:	Output_Data=  {{35{Input_Data[63]}},Input_Data[63:35]} ;
		6'b100100:	Output_Data=  {{36{Input_Data[63]}},Input_Data[63:36]} ;
		6'b100101:	Output_Data=  {{37{Input_Data[63]}},Input_Data[63:37]} ;
		6'b100110:	Output_Data=  {{38{Input_Data[63]}},Input_Data[63:38]} ;
		6'b100111:	Output_Data=  {{39{Input_Data[63]}},Input_Data[63:39]} ;
		6'b101000:	Output_Data=  {{40{Input_Data[63]}},Input_Data[63:40]} ;
		
		6'b101001:	Output_Data=  {{41{Input_Data[63]}},Input_Data[63:41]} ;
		6'b101010:	Output_Data=  {{42{Input_Data[63]}},Input_Data[63:42]} ;
		6'b101011:	Output_Data=  {{43{Input_Data[63]}},Input_Data[63:43]} ;
		6'b101100:	Output_Data=  {{44{Input_Data[63]}},Input_Data[63:44]} ;
		6'b101101:	Output_Data=  {{45{Input_Data[63]}},Input_Data[63:45]} ;
		6'b101110:	Output_Data=  {{46{Input_Data[63]}},Input_Data[63:46]} ;
		6'b101111:	Output_Data=  {{47{Input_Data[63]}},Input_Data[63:47]} ;
		6'b110000:	Output_Data=  {{48{Input_Data[63]}},Input_Data[63:48]} ;
		
		6'b110001:	Output_Data=  {{49{Input_Data[63]}},Input_Data[63:49]} ;
		6'b110010:	Output_Data=  {{50{Input_Data[63]}},Input_Data[63:50]} ;
		6'b110011:	Output_Data=  {{51{Input_Data[63]}},Input_Data[63:51]} ;
		6'b110100:	Output_Data=  {{52{Input_Data[63]}},Input_Data[63:52]} ;
		6'b110101:	Output_Data=  {{53{Input_Data[63]}},Input_Data[63:53]} ;
		6'b110110:	Output_Data=  {{54{Input_Data[63]}},Input_Data[63:54]} ;
		6'b110111:	Output_Data=  {{55{Input_Data[63]}},Input_Data[63:55]} ;
		6'b111000:	Output_Data=  {{56{Input_Data[63]}},Input_Data[63:56]} ;

		6'b111001:	Output_Data=  {{57{Input_Data[63]}},Input_Data[63:57]} ;
		6'b111010:	Output_Data=  {{58{Input_Data[63]}},Input_Data[63:58]} ;
		6'b111011:	Output_Data=  {{59{Input_Data[63]}},Input_Data[63:59]} ;
		6'b111100:	Output_Data=  {{60{Input_Data[63]}},Input_Data[63:60]} ;
		6'b111101:	Output_Data=  {{61{Input_Data[63]}},Input_Data[63:61]} ;
		6'b111110:	Output_Data=  {{62{Input_Data[63]}},Input_Data[63:62]} ;
		6'b111111:	Output_Data=  {{63{Input_Data[63]}},Input_Data[63]} ;
		
//		default: 	Output_Data= `WORD_ZERO_64;
endcase
end
endmodule

//-----------------------------------------------------------------------------------------------
// END Functional Unit - Shift_Word_Right_Arithmetic
//-----------------------------------------------------------------------------------------------

