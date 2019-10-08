`include "LAGARTO_CONFIG.v"

module EXE_BYPASS (

input 		[4:0]			EXE_SRC_FIELD,

input 		`WORD_DATA	RR_EXE_DATA1,

input 		`WORD_DATA	WB_WRITE_DATA1,
input 		[4:0]			WB_WRITE_ADDR1,
input 						WB_WE1,

output  reg	`WORD_DATA	BYPASS_SOURCE
);


wire [1:0]BYPASS_MUX;   
assign BYPASS_MUX[1]= 1'b0;
assign BYPASS_MUX[0]= ((EXE_SRC_FIELD==WB_WRITE_ADDR1) & WB_WE1) ? 	1'b1:1'b0;


always@(*)
begin
	case(BYPASS_MUX)
		2'b00:	BYPASS_SOURCE	=	RR_EXE_DATA1;
		2'b01:	BYPASS_SOURCE	=	WB_WRITE_DATA1;
		default:BYPASS_SOURCE	=	`WORD_ZERO_64;
	endcase
end

endmodule

