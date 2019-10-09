//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// DECODE STAGE																																				                             	//
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
//	Vector Control_Signal 																																		                            //
// 15,14,,, 	            13          12         11		    10			9			8			7			6			5			4			3			2			1			0	//
// Libre		            AMO		   SYSTEM    MISC-MEM	   OPC_ID	    32-BITS	    HALF	    BYTE		INT-FP	    JUMP		BRANCH	    W-REG		LD/ST		OP-IMM	    OP	//
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// OP			0009        0			0		    0			0			0			0			0			0			0			0			1			0			0			1	//
// OP32			0109		0			0		    0			0			1			0			0			0			0			0			1			0			0			1	//
// OP-IMM		000A		0			0		    0			0			0			0			0			0			0			0			1			0			1			0	//
// OP-IMM32		010A		0			0		    0			0			1			0			0			0			0			0			1			0			1			0	//
// BRANCH		0010		0			0		    0			0			0			0			0			0			0			1			0			0			0			0	//
// LOAD			000C		0			0		    0			0			0			0			0			0			0			0			1			1			0			0	//
// STORE		0004		0			0		    0			0			0			0			0			0			0			0			0			1			0			0	//
// JAL			0028		0			0		    0			0			0			0			0			0			1			0			1			0			0			0	//
// JALR			0029		0			0		    0			0			0			0			0			0			1			0			1			0			0			1	//
// LUI			0409		0			0		    0			1			0			0			0			0			0			0			1			0			0			1	//
// AUIPC		0409		0			0		    0			1			0			0			0			0			0			0			1			0			0			1	//
// MISC _MEM	0800		0			0		    1			0			0			0			0			0			0			0			0			0			0			0	//
// SYSTEM		1000		0			1		    0			0			0			0			0			0			0			0			0			0			0	        0   //
// AMO		    2000		1			0		    0			0			0			0			0			0			0			0			0			0			0			0	//
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
module DECODE (
input               valid_inst,
input 		[6:0]	opcode,

output reg	[15:0]	Control_Signal,
output              DEC_XCPT_ILLEGAL_INST

);


wire [15:0]Control_Signal_0;
Decoder_0 Decoder_0(
.tag					(opcode[4:2]),
.Control_Signal	(Control_Signal_0)
);

wire [15:0]Control_Signal_1;
Decoder_1 Decoder_1(
.tag					(opcode[4:2]),
.Control_Signal	(Control_Signal_1)
);

wire [15:0]Control_Signal_2;
Decoder_2 Decoder_2(
.tag					(opcode[4:2]),
.Control_Signal	(Control_Signal_2)
);

wire [15:0]Control_Signal_3;
Decoder_3 Decoder_3(
.tag					(opcode[4:2]),
.Control_Signal	(Control_Signal_3)
);

wire 		Ins32;
assign 	Ins32 = (opcode[1:0] == 2'b11);
	
always @ (*) begin
case (opcode[6:5])
	2'b00:  Control_Signal= (Ins32) ? Control_Signal_0:16'b0;
	2'b01:  Control_Signal= (Ins32) ? Control_Signal_1:16'b0;
	2'b10:  Control_Signal= (Ins32) ? Control_Signal_2:16'b0;
	2'b11:  Control_Signal= (Ins32) ? Control_Signal_3:16'b0;
//	default: Control_Signal=16'b000000000000000;	
endcase

end

assign  DEC_XCPT_ILLEGAL_INST = ~Control_Signal[15] & valid_inst;

endmodule


//-----------------------------------------------------------------------
//								Decoder_0
//-----------------------------------------------------------------------
module Decoder_0(
input [2:0]tag,
output reg [15:0]Control_Signal
);

wire [15:0]Decoder[0:7];
//always @ (*) begin
assign Decoder[0]=16'h800C;	// RISCV LOAD
assign Decoder[1]=16'h0000;    //
assign Decoder[2]=16'h0000;    //
assign Decoder[3]=16'h8800;    // RISCV MISC-MEM
assign Decoder[4]=16'h800A;    // RISCV OP-IMM	
assign Decoder[5]=16'h8409;    // RISCV AUIPC 
assign Decoder[6]=16'h820A;    // RISCV OP-IMM32
assign Decoder[7]=16'h0000;    //
//end
always@(*) 		//posedge CLK
begin 
	Control_Signal= Decoder[tag]; 
end

endmodule
//-----------------------------------------------------------------------
//								Decoder_1
//-----------------------------------------------------------------------
module Decoder_1(
input [2:0]tag,
output reg [15:0]Control_Signal
);

//reg [15:0]Decoder[0:7];    
//initial $readmemh ("decoder_1.hex", Decoder);
parameter MEM_SIZE = 8;
wire [15:0]Decoder[0:MEM_SIZE-1];
//always @ (*) begin
assign Decoder[0]=16'h8004;	// RISCV STORE
assign Decoder[1]=16'h0000;    //      
assign Decoder[2]=16'h0000;    //
assign Decoder[3]=16'hA000;    // RISCV AMO
assign Decoder[4]=16'h8009;    // RISCV OP	
assign Decoder[5]=16'h8409;    // RISCV LUI 
assign Decoder[6]=16'h8209;    // RISCV OP-32
assign Decoder[7]=16'h0000;    //
//end

always@(*) 		//posedge CLK
begin 
	Control_Signal= Decoder[tag]; 
end
endmodule
//-----------------------------------------------------------------------
//								Decoder_2
//-----------------------------------------------------------------------
module Decoder_2(
input [2:0]tag,
output reg [15:0]Control_Signal
);

wire [15:0]Decoder[0:7];
//always @ (*) begin
assign Decoder[0]=16'h0000;	// 
assign Decoder[1]=16'h0000;    //      
assign Decoder[2]=16'h0000;    //
assign Decoder[3]=16'h0000;    //
assign Decoder[4]=16'h8000;    // OP_FP - NOP
assign Decoder[5]=16'h0000;    //
assign Decoder[6]=16'h0000;    //
assign Decoder[7]=16'h0000;    //
//end

always@(*) 		//posedge CLK
begin 
	Control_Signal= Decoder[tag]; 
end
endmodule
//-----------------------------------------------------------------------
//								Decoder_3
//-----------------------------------------------------------------------
module Decoder_3(
input [2:0]tag,
output reg [15:0]Control_Signal
);

wire [15:0]Decoder[0:7];
//always @ (*) begin
assign Decoder[0]=16'h8010;	// RISCV BRANCH
assign Decoder[1]=16'h8029;    // RISCV JALR     
assign Decoder[2]=16'h0000;    //
assign Decoder[3]=16'h8028;    // RISCV JAL
assign Decoder[4]=16'h9000;    // RISCV SYSTEM	
assign Decoder[5]=16'h0000;    //
assign Decoder[6]=16'h0000;    //
assign Decoder[7]=16'h0000;    //
//end


always@(*) 		//posedge CLK
begin 
	Control_Signal= Decoder[tag]; 
end
endmodule
