`include "LAGARTO_CONFIG.v"

module EXE_LOAD_STORE_UNIT(
input						CLK,
input						RST,
input						lock_EXE,
input                       WB_EXCEPTION,
input                       CSR_ERET,
input		`ADDR			PC,		
input                       PC_Valid,									
input		[2:0]			Funct3_FIELD,							
	
input		[11:0]			Immediate_load,						
input		[11:0]			Immediate_store,							
input		`WORD_DATA		Source1,									
input		`WORD_DATA		Source2,	
input		[4:0]			DST_FIELD,									

input      `ADDR            IO_BASE_ADDR,
//-------------------------------------------------------------
// AMO INTERFACE
//-------------------------------------------------------------
input						AMO,
input       [4:0]           AMO_FUNCT,
//-------------------------------------------------------------
// LOAD INTERFACE
//-------------------------------------------------------------
// Control Signals LOAD
input						LOAD,

// DCACHE Answer
input                       DMEM_RESP_BITS_REPLAY,
input                       DMEM_REPLAY_NEXT_VALID,
input                       DMEM_RESP_BITS_HAS_DATA,
input		`WORD_DATA		DMEM_RESP_BITS_DATA,
input						DMEM_REQ_READY,
input                       DMEM_RESP_VALID,
input                       DMEM_RESP_BITS_NACK,
input                       DMEM_XCPT_MA_ST,
input                       DMEM_XCPT_MA_LD,
input                       DMEM_XCPT_PF_ST,
input                       DMEM_XCPT_PF_LD,

// DCACHE Answer to WB
output	     `ADDR			MEM_PC,
//output                    Load_PC_Valid,
output						MEM_READY,
output	     `WORD_DATA		MEM_DATA,
output	     [4:0]			WRITE_ADDR,
//-------------------------------------------------------------
// STORE INTERFACE
//-------------------------------------------------------------
// Control Signals STORE
input						STORE,
//-------------------------------------------------------------
// LOAD/STORE/AMO INTERFACE OUTPUTS TO DCACHE
//-------------------------------------------------------------
output  reg                 MEM_REQ_VALID,
output	    `DATA_SIZE		MEM_OP_TYPE,
output  reg [4:0]           MEM_REQ_CMD,
output      `WORD_DATA      MEM_REQ_BITS_DATA,
output      `ADDR           MEM_REQ_BITS_ADDR,
output      [7:0]           MEM_REQ_BITS_TAG,
output                      MEM_REQ_INVALIDATE_LR,
output                      MEM_REQ_BITS_KILL,

output  reg                 DMEM_LOCK
//-------------------------------------------------------------						
);
//-------------------------------------------------------------
// CONTROL SIGNALS
//-------------------------------------------------------------
wire    DMEM_XCPT;
assign  DMEM_XCPT = DMEM_XCPT_MA_ST | DMEM_XCPT_MA_LD | DMEM_XCPT_PF_ST | DMEM_XCPT_PF_LD;

//-------------------------------------------------------------

wire 		`ADDR	Imm_load;
wire 		`ADDR	Imm_store;
assign 				Imm_load = {{28{Immediate_load[11]}},Immediate_load[11:0]} ;
assign 				Imm_store = {{28{Immediate_store[11]}},Immediate_store[11:0]} ;

//-------------------------------------------------------------
// STORE
//-------------------------------------------------------------
wire   `ADDR          STORE_ADDR;
wire   `WORD_DATA     STORE_DATA;
//wire                  STORE_ENABLE;

assign		STORE_ADDR = Source1[39:0] + Imm_store;
assign 		STORE_DATA = Source2;
//assign		STORE_ENABLE = STORE;

//-------------------------------------------------------------
// LOAD - 1st stage
//-------------------------------------------------------------
wire   `ADDR          LOAD_ADDR;
//wire                  LOAD_ENABLE;

assign	LOAD_ADDR =  Source1[39:0] + Imm_load;
//assign	LOAD_ENABLE = LOAD;

//-------------------------------------------------------------
wire    MEM_REQ_VALID_AUX;

assign 		MEM_OP_TYPE = {1'b0,Funct3_FIELD};
assign      MEM_REQ_BITS_DATA = (AMO) ? Source2:(STORE) ? STORE_DATA: (LOAD) ? 64'b0: 64'b0;
assign      MEM_REQ_BITS_ADDR = (AMO) ? Source1[39:0]:(STORE) ? STORE_ADDR: (LOAD) ? LOAD_ADDR: `WORD_ZERO_40;

assign      MEM_REQ_BITS_TAG = {2'b00,DST_FIELD,1'b0}; //  BIT 0 CORRESPONDE A INT O FP
assign      MEM_REQ_INVALIDATE_LR = WB_EXCEPTION;

assign      MEM_REQ_BITS_KILL = DMEM_XCPT | WB_EXCEPTION | CSR_ERET  |(DMEM_RESP_BITS_REPLAY & MEM_REQ_VALID_AUX);

always@(*)
begin
case({STORE,LOAD,AMO})
    3'b001:   begin
              case(AMO_FUNCT)
                   5'b00010:MEM_REQ_CMD = 5'b00110; // LR
                   5'b00011:MEM_REQ_CMD = 5'b00111; // SC
                   5'b00001:MEM_REQ_CMD = 5'b00100; // AMOSWAP
                   5'b00000:MEM_REQ_CMD = 5'b01000; // AMOADD
                   5'b00100:MEM_REQ_CMD = 5'b01001; // AMOXOR                  
                   5'b01100:MEM_REQ_CMD = 5'b01011; // AMOAND                
                   5'b01000:MEM_REQ_CMD = 5'b01010; // AMOOR
                   5'b10000:MEM_REQ_CMD = 5'b01100; // AMOMIN
                   5'b10100:MEM_REQ_CMD = 5'b01101; // AMOMAX
                   5'b11000:MEM_REQ_CMD = 5'b01110; // AMOMINU
                   5'b11100:MEM_REQ_CMD = 5'b01111; // AMOMAXU                 
                   default: MEM_REQ_CMD = 5'b00000;
              endcase
              end
    3'b010:   MEM_REQ_CMD = 5'b00000;
    3'b100:   MEM_REQ_CMD = 5'b00001;
    default:  MEM_REQ_CMD = 5'b00000;  
endcase
end

//--------------------------------------------------------------------------------------------------------------------------
// MAQUINA DE ESTADOS PARA EL CONTROL DE LOCK
//--------------------------------------------------------------------------------------------------------------------------
assign  MEM_REQ_VALID_AUX = (STORE |  LOAD | AMO );
//--------------------------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------------
wire IO_ADDRESS_SPACE;
//assign  IO_ADDRESS_SPACE = ((MEM_REQ_BITS_ADDR >= IO_BASE_ADDR) & (MEM_REQ_BITS_ADDR <= 40'h008001FFFF) ) ? 1'b1:1'b0; 
assign  IO_ADDRESS_SPACE = ((MEM_REQ_BITS_ADDR >= IO_BASE_ADDR) & (MEM_REQ_BITS_ADDR <= 40'h80020053) ) ? 1'b1:1'b0; 

wire KILL_IO_RESP;   
assign  KILL_IO_RESP =  IO_ADDRESS_SPACE &  STORE ;

wire KILL_MEM_OPE;
assign   KILL_MEM_OPE = DMEM_XCPT | WB_EXCEPTION | CSR_ERET;

reg [2:0]EstadoSiguiente,Edo_Sgte;
reg ICACHE_MISS;
parameter   REQ_VALID    = 2'b00,
			RESP_READY   = 2'b01,
			RESP_VALID   = 2'b10;

always@(posedge CLK)
begin
if(~RST)
	EstadoSiguiente <= 2'b00;
else
    EstadoSiguiente <= Edo_Sgte;
end

//wire DMEM_REPLAY;
//assign  DMEM_REPLAY = DMEM_RESP_BITS_HAS_DATA & DMEM_RESP_BITS_REPLAY; 

wire KILL_MEM_OPE_aux;
assign   KILL_MEM_OPE_aux =  /*DMEM_XCPT |*/ WB_EXCEPTION | CSR_ERET;



always@(*)
begin
	case (EstadoSiguiente)
        REQ_VALID:     begin
                    MEM_REQ_VALID = (KILL_MEM_OPE_aux /*MEM_REQ_BITS_KILL*/ ) ? 1'b0: MEM_REQ_VALID_AUX & DMEM_REQ_READY; 
                    Edo_Sgte = (KILL_MEM_OPE_aux /*MEM_REQ_BITS_KILL*/) ? REQ_VALID : (MEM_REQ_VALID ) ?  RESP_READY : REQ_VALID;
                    DMEM_LOCK = (KILL_MEM_OPE_aux /*MEM_REQ_BITS_KILL*/ ) ? 1'b0: (MEM_REQ_VALID_AUX) ? 1'b1 : 1'b0;
                    end
        RESP_READY: begin
                    if(DMEM_RESP_VALID & DMEM_REQ_READY) // CASE: IO RESPONSE UART
                      begin
                      MEM_REQ_VALID = 1'b0; 
                      Edo_Sgte = REQ_VALID;
                      DMEM_LOCK = 1'b0;
                      end  
                    else
                      begin
                      MEM_REQ_VALID = 1'b0;
                      Edo_Sgte =  (KILL_MEM_OPE /*MEM_REQ_BITS_KILL*/) ? REQ_VALID:(DMEM_REQ_READY)? RESP_VALID : REQ_VALID;
                      DMEM_LOCK = (KILL_MEM_OPE /*MEM_REQ_BITS_KILL*/) ? 1'b0 :  1'b1;
                      end
                    end
		RESP_VALID: begin
		            if(DMEM_RESP_VALID)
		                begin
                        MEM_REQ_VALID = 1'b0; 
                        Edo_Sgte = REQ_VALID;
                        DMEM_LOCK = 1'b0;
                        end                                        
		            else if(DMEM_RESP_BITS_NACK)
		                    begin
                            MEM_REQ_VALID = 1'b0;
                            Edo_Sgte = REQ_VALID;
                            DMEM_LOCK = 1'b1;
                            end 
                        /*
                         else if(DMEM_REPLAY_NEXT_VALID)
                            begin
                            MEM_REQ_VALID = 1'b0; 
                            Edo_Sgte = REQ_VALID;
                            DMEM_LOCK = 1'b1;
                            end  
                         */
                         /*
                         else if(DMEM_REPLAY)
                               begin
                               MEM_REQ_VALID = 1'b0; 
                               Edo_Sgte = REQ_VALID;
                               DMEM_LOCK = 1'b1;
                               end  
                         */
                            else
                                begin
                                MEM_REQ_VALID = 1'b0;
                                Edo_Sgte = (KILL_MEM_OPE /*MEM_REQ_BITS_KILL*/ | KILL_IO_RESP) ? REQ_VALID : RESP_VALID;
                                DMEM_LOCK = (KILL_MEM_OPE /*MEM_REQ_BITS_KILL*/ | KILL_IO_RESP) ? 1'b0: 1'b1;
                                end
                    end
        default: begin
          MEM_REQ_VALID = 1'b0;
          Edo_Sgte = REQ_VALID;
          DMEM_LOCK = 1'b0;
        end
	endcase
end

assign 	MEM_PC			= PC;
assign 	MEM_DATA 		= DMEM_RESP_BITS_DATA;
assign 	WRITE_ADDR      = DST_FIELD;
assign 	MEM_READY 		= DMEM_RESP_VALID & (LOAD | AMO);

endmodule
