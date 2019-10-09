`include "LAGARTO_CONFIG.v"

module EXE_BRANCH_UNIT(

input 	`ADDR			PC,
input 	`ADDR			branch_offset,
input 	[2:0]			Funct3_FIELD,

input 					INT_BRANCH,
input 	`WORD_DATA		Source1,
input 	`WORD_DATA		Source2,

//TODO: commented due to todo #1
//output  				Take_Branch,
output  `ADDR			Branch_target,
output  `ADDR			Branch_Result

//TODO: #2 now Invalid_branch  is ignored in instance . Remove it and
//associated logic or do something with result
//,
//output 					Invalid_branch
);


wire Equal;
assign Equal= (Source1==Source2);
wire Less;
assign Less= ( $signed(Source1) < $signed(Source2)) ;
wire Less_U;
assign Less_U= ( Source1 < Source2) ;

// ---------------------------------------------------------------------
//						            INT BRANCH
// ---------------------------------------------------------------------
//TODO: #1 now Take_Branch is ignored. Remove it and associated logic
//or do something with result
reg Taken_INT;
//TODO: commented due to todo #2
//reg invalid_instruction;

always@(*)
begin

case ({INT_BRANCH,Funct3_FIELD})

	4'b1000:	begin	//BRANCH ON EQUAL
				Taken_INT = Equal;
//TODO: commented due to todo #2
//				invalid_instruction= 1'b0;
				end
	4'b1001:	begin	//BRANCH ON NOT EQUAL
				Taken_INT = ~Equal;
//TODO: commented due to todo #2
//				invalid_instruction= 1'b0;
				end	
	4'b1100:	begin	//BRANCH ON LESS THAN
				Taken_INT = Less;
//TODO: commented due to todo #2
//				invalid_instruction= 1'b0;
				end	
	4'b1101:	begin	//BRANCH ON GREATER THAN OR EQUAL
				Taken_INT = ~Less;
//TODO: commented due to todo #2
//				invalid_instruction= 1'b0;
				end
	4'b1110:	begin	//BRANCH IF LESS THAN UNSIGNED
				Taken_INT = Less_U;
//TODO: commented due to todo #2
//				invalid_instruction= 1'b0;
				end
	4'b1111:	begin	//BRANCH IF GREATER THAN OR EQUAL UNSIGNED
				Taken_INT = ~Less_U;
//TODO: commented due to todo #2
//				invalid_instruction= 1'b0;
				end			
	default:	begin	
				Taken_INT = 1'b0;
//TODO: commented due to todo #2
//				invalid_instruction= INT_BRANCH;
				end
endcase
end

wire 	`ADDR		Next_PC;
assign Next_PC = PC + 4;

//TODO: commented due to todo #2
//assign 	Invalid_branch = invalid_instruction;
//TODO: commented due to todo #1
//assign 	Take_Branch = Taken_INT;
assign 	Branch_target = PC + branch_offset; 
assign 	Branch_Result = (Taken_INT) ? Branch_target:Next_PC;

endmodule

