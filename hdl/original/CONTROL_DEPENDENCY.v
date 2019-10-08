module	CONTROL_DEPENDENCY (
input			[15:0]	    RR_Control_Signal,
input			[4:0]		RR_Src1_FIELD,
input			[4:0]		RR_Src2_FIELD,
input			[15:0]	    EXE_Control_Signal,
input			[4:0]		EXE_DST_FIELD,
output					    LOCK_PIPELINE
);
/*
// QUE NI SRC NI DST SEA CERO ----- 		NO_ZERO LO CHECA
wire NO_ZERO;
assign NO_ZERO = |EXE_DST_FIELD;

// OP-IMM invalida RR_Src2_FIELD
wire 	VALID_SRC2;
assign 	VALID_SRC2 = ~RR_Control_Signal[1];

// LUI y AUIPC invalida RR_Src1_FIELD y RR_Src2_FIELD
wire 	VALID_SRC_1_2;
assign 	VALID_SRC_1_2 = ~RR_Control_Signal[10];

// LOAD Invalida RR_Src2_FIELD
wire 	RR_IS_LOAD;
assign 	RR_IS_LOAD = (RR_Control_Signal[2] & RR_Control_Signal[3]);

//wire 		IS_STORE;
//assign 	IS_STORE = EXE_Control_Signal[2] & ~EXE_Control_Signal[3];

// QUE EXE_DST NO SEA BRANCH
//wire 		VALID_DST;
//assign 	VALID_DST = ~EXE_Control_Signal[4] & ~IS_STORE;

wire SRC1_DEP,SRC2_DEP;
assign SRC1_DEP = (RR_Src1_FIELD == EXE_DST_FIELD) & NO_ZERO & VALID_SRC_1_2 ; // & VALID_DST ;
assign SRC2_DEP = (RR_Src2_FIELD == EXE_DST_FIELD) & NO_ZERO & VALID_SRC2 & VALID_SRC_1_2  & ~RR_IS_LOAD; // & VALID_DST 

//wire    BUBBLE;
//assign  BUBBLE = RR_IS_LOAD & EXE_IS_LOAD;
// HAZARD BY LOAD
wire 	EXE_IS_LOAD;
assign 	EXE_IS_LOAD = (EXE_Control_Signal[2] & EXE_Control_Signal[3]);

assign LOCK_PIPELINE = (EXE_IS_LOAD & ( SRC1_DEP | SRC2_DEP));    //  | BUBBLE
*/

// CURRENT VERSION PERFORM MEMORY OPERATIONS IN EXECUTION STAGE AND STALL UNTIL IT IS READY, 
// THEN THE INTRUCCTION GO TO WB STAGE, MEANS THAT IF THERE ARE DEPENDENCIES, IT CAN USE THE BYPASS TO SOLVE IT
// WE DONT NEED TO DO PIPELINE STALL

assign LOCK_PIPELINE = 1'b0;

endmodule

