`include "LAGARTO_CONFIG.v"

module FETCH(
input 					    CLK,
input 					    RST,
input		`ADDR	        RESET_ADDRESS,
input 					    CORE_lock,
input                       FETCH_same_block,

input                       FENCE_I,
output	reg				    lock_FETCH,
//--------------------------------------------------
// PC GENERATION SIGNALS
//--------------------------------------------------
input 					    WB_EXCEPTION,
input 					    CSR_ERET,
input 		`ADDR		    CSR_EVEC,
    
input 					    PREDICTOR_TAKE_BRANCH,
input 		`ADDR		    PREDICTOR_branch_addr,

input 					    EXE_MISS_PREDICTION,
input 		`ADDR		    EXE_branch_addr,

input 					    DEC_JAL,
input 		`ADDR		    jal_addr,

input 					    EXE_jalr,	
input 		`ADDR		    jalr_addr,	

output reg 	`ADDR		    FETCH_PC,
output reg                  PC_Valid,
output reg  `WORD_INST      FETCH_INST,

output reg				    FETCH_XCPT_MISALIGNED,
//--------------------------------------------------
// INPUTS FROM CCM SET PC 
//--------------------------------------------------
input `ADDR			FETCH_PC_VALUE,
input				FETCH_PC_UPDATE,
//--------------------------------------------------
// INPUTS FROM ICACHE 
//--------------------------------------------------
input 	`CACHE_LINE_SIZE 	ICACHE_RESP_BITS_DATABLOCK,
input						ICACHE_RESP_VALID,
input						PTWINVALIDATE,
input						TLB_RESP_MISS,
input						TLB_RESP_XCPT_IF,
//--------------------------------------------------
// OUTPUTS TO ICACHE 
//--------------------------------------------------
output 				        ICACHE_INVALIDATE,
output	[11:0]				ICACHE_REQ_BITS_IDX,
output					    ICACHE_REQ_BITS_KILL,
output   reg                ICACHE_REQ_VALID,
output	 reg				ICACHE_RESP_READY,
output	[27:0]				TLB_REQ_BITS_VPN,
output					    TLB_REQ_VALID
);  

wire                        FETCH_PC_req_valid;
wire    `ADDR               PC_PREDICTED;
wire    `ADDR               PC_NEXT;
//--------------------------------------------------------------------------------------------------------------------------
// PC GENERATION
//--------------------------------------------------------------------------------------------------------------------------

assign PC_NEXT = FETCH_PC + 40'h004;
/* julian pavon rivera */
assign PC_PREDICTED = (EXE_MISS_PREDICTION) ? EXE_branch_addr:(EXE_jalr) ? jalr_addr: (DEC_JAL) ? jal_addr: (PREDICTOR_TAKE_BRANCH) ? PREDICTOR_branch_addr: (FETCH_PC_UPDATE) ? FETCH_PC_VALUE : (lock_FETCH | CORE_lock) ? FETCH_PC:PC_NEXT;

always@(posedge CLK)
begin
if(~RST)
	begin
	FETCH_PC               <= RESET_ADDRESS;
	PC_Valid               <=1'b1;
	FETCH_XCPT_MISALIGNED  <=1'b0;
	end 
else if(WB_EXCEPTION | CSR_ERET)
        begin
		FETCH_PC              <=CSR_EVEC;
		PC_Valid              <=1'b1;
		FETCH_XCPT_MISALIGNED <= |CSR_EVEC[1:0];
		end
         else	
            begin
            FETCH_PC                <=PC_PREDICTED;
            PC_Valid                <=1'b1;
            FETCH_XCPT_MISALIGNED   <=|PC_PREDICTED[1:0];
            end
end

assign  FETCH_PC_req_valid = ~CORE_lock && ~FETCH_same_block;
//--------------------------------------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------------------------------------
// INTRUCTION SELECTION FROM ICACHE LINE
//--------------------------------------------------------------------------------------------------------------------------
reg [127:0] ICACHE_LINE;
//initial ICACHE_LINE = 128'b0;

always@(posedge CLK)
begin
if(~RST)
ICACHE_LINE <= 128'b0;
else   if(ICACHE_RESP_VALID)
           ICACHE_LINE <= ICACHE_RESP_BITS_DATABLOCK;
       else
           ICACHE_LINE <= ICACHE_LINE;
end
wire [127:0] ICACHE_LINE_INT;
assign ICACHE_LINE_INT = (ICACHE_RESP_VALID) ? ICACHE_RESP_BITS_DATABLOCK : ICACHE_LINE;


always@(*)
begin
    case(FETCH_PC[3:0])
        4'b0000:    FETCH_INST = ICACHE_LINE_INT[31:0];
        4'b0100:    FETCH_INST = ICACHE_LINE_INT[63:32]; 
        4'b1000:    FETCH_INST = ICACHE_LINE_INT[95:64]; 
        4'b1100:    FETCH_INST = ICACHE_LINE_INT[127:96]; 
        default:    FETCH_INST = 32'h0;
    endcase
end
//--------------------------------------------------------------------------------------------------------------------------
wire   FETCH_REQ_Kill;
assign FETCH_REQ_Kill = WB_EXCEPTION | CSR_ERET | EXE_MISS_PREDICTION | PREDICTOR_TAKE_BRANCH | DEC_JAL | EXE_jalr;
//--------------------------------------------------------------------------------------------------------------------------
// ICACHE OUTPUT CONNECTIONS
//--------------------------------------------------------------------------------------------------------------------------
assign  TLB_REQ_BITS_VPN    = FETCH_PC[39:12]; 
assign  ICACHE_REQ_BITS_IDX = FETCH_PC[11:0];

assign  ICACHE_INVALIDATE = FENCE_I & ~FETCH_REQ_Kill;
assign  ICACHE_REQ_BITS_KILL = FETCH_REQ_Kill | TLB_RESP_MISS | TLB_RESP_XCPT_IF | PTWINVALIDATE ; // | ICACHE_MISS

assign  TLB_REQ_VALID = ~CORE_lock;

wire FETCH_XCPT;
assign  FETCH_XCPT = TLB_RESP_XCPT_IF | FETCH_XCPT_MISALIGNED;
//--------------------------------------------------------------------------------------------------------------------------
// MAQUINA DE ESTADOS - CONTROL DE TIEMPOS PARA COMUNICARSE CON LA ICACHE Y TLB
//--------------------------------------------------------------------------------------------------------------------------
reg [1:0]EstadoSiguiente,Edo_Sgte;
reg ICACHE_MISS;
parameter   NO_REQ       = 2'b00,
		    REQ_VALID    = 2'b01,
			RESP_READY   = 2'b10,
			RESP_VALID   = 2'b11;

always@(posedge CLK)
begin
if(~RST)
	EstadoSiguiente <= 2'b00;
	else	if(~CORE_lock)
			EstadoSiguiente <= Edo_Sgte;
end

always@(*)
begin
	case (EstadoSiguiente)
        NO_REQ:     begin
                    ICACHE_REQ_VALID = (FETCH_XCPT) ? 1'b0:(FETCH_REQ_Kill) ? 1'b0:FETCH_PC_req_valid;
                    ICACHE_RESP_READY = 1'b0;
                    Edo_Sgte = (FETCH_XCPT) ? NO_REQ:(FETCH_REQ_Kill) ? NO_REQ:(ICACHE_REQ_VALID) ?  RESP_READY : NO_REQ;
                    lock_FETCH = (FETCH_XCPT) ? 1'b0:(FETCH_REQ_Kill) ? 1'b0 : (ICACHE_REQ_VALID) ? 1'b1 : 1'b0;
                    end
		RESP_READY:  begin
		            ICACHE_REQ_VALID = 1'b0;
                    ICACHE_RESP_READY =  (FETCH_XCPT) ? 1'b0:(FETCH_REQ_Kill) ? 1'b0:~CORE_lock  & ~FETCH_same_block;
			        Edo_Sgte = (FETCH_XCPT) ? NO_REQ:(FETCH_REQ_Kill) ? NO_REQ:(ICACHE_RESP_READY)? REQ_VALID : NO_REQ;
			        lock_FETCH = (FETCH_XCPT) ? 1'b0:(FETCH_REQ_Kill) ? 1'b0:(ICACHE_RESP_READY) ? 1'b1 : 1'b0;
			        end
			        
		REQ_VALID: begin
		            if(ICACHE_RESP_VALID)
		                begin
                        ICACHE_REQ_VALID = 1'b0;
                        ICACHE_RESP_READY = 1'b0;
                        Edo_Sgte =  NO_REQ;
                        lock_FETCH = 1'b0;
                        end
		            else
                        begin
                        ICACHE_REQ_VALID = (FETCH_XCPT) ? 1'b0:(FETCH_REQ_Kill) ? 1'b0:FETCH_PC_req_valid;
                        ICACHE_RESP_READY = 1'b0;
                        Edo_Sgte = (FETCH_XCPT) ? NO_REQ:(FETCH_REQ_Kill) ? NO_REQ:(ICACHE_REQ_VALID) ?  RESP_READY : NO_REQ;
                        lock_FETCH = (FETCH_XCPT) ? 1'b0:(FETCH_REQ_Kill) ? 1'b0:(ICACHE_REQ_VALID) ? 1'b1 : 1'b0;
                        end
                    end
        default: begin
            ICACHE_REQ_VALID = 1'b0;
            ICACHE_RESP_READY = 1'b0;
            Edo_Sgte = NO_REQ;
            lock_FETCH = 1'b0;
        end
	endcase
end
//--------------------------------------------------------------------------------------------------------------------------

endmodule
