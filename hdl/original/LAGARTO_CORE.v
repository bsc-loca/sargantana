//--------------------------------------------------------------------------------------------------------------------------
//															LAGARTO_I CORE
//-------------------------------------------------------------------------------------------------------------------------- 
// LAGARTO I IS A 64-BITS IN-ORDER CORE WHICH FETCH 1 INSTRUCTION PER CLOCK CYCLE. 
// CURRENTLY IS BOOTING THE LINUX KERNEL V3.14
// SUPPORTS THE FOLLOWING SUBSETS 
// -RV64I
// -M STANDARD EXTENSION
// OUTPUT CONNECTIONS TO CSR (PRIVILIGED ISA V1.7)
// OUTPUT CONNECTIONS TO DCACHE
// OUTPUT CONNECTIONS TO ICACHE 
//
// WORK-IN-PROGRESS: 
// FLOATING POINT
//
// CIC-IPN/BSC-UPC
// AUTOR: CRISTOBAL RAMIREZ LAZO
//-------------------------------------------------------------------------------------------------------------------------- 
//
//
//
//-------------------------------------------------------------------------------------------------------------------------- 

`include "LAGARTO_CONFIG.v" 

module LAGARTO_CORE(
input 					    CLK,
input 					    RST,
input                       SOFT_RST,
input	`ADDR			    RESET_ADDRESS,
//--------------------------------------------------------------------------------------------------------------------------
// CSR INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
input    `WORD_DATA         CSR_RW_RDATA,
input                       CSR_CSR_STALL,
input                       CSR_XCPT,
input                       CSR_ERET,
input    `ADDR              CSR_EVEC,
input                       CSR_INTERRUPT,
input    `WORD_DATA         CSR_INTERRUPT_CAUSE,

output   [11:0]             CSR_RW_ADDR,
output   [2:0]              CSR_RW_CMD,
output   `WORD_DATA         CSR_RW_WDATA,
output                      CSR_EXCEPTION,
output                      CSR_RETIRE,
output   `WORD_DATA         CSR_CAUSE,
output   `ADDR              CSR_PC,
//--------------------------------------------------------------------------------------------------------------------------
// I-CANCHE INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
output 				        ICACHE_INVALIDATE,
output	[11:0]				ICACHE_REQ_BITS_IDX,
output					    ICACHE_REQ_BITS_KILL,
output                      ICACHE_REQ_VALID,
output	 				    ICACHE_RESP_READY,
output	[27:0]				TLB_REQ_BITS_VPN,
output					    TLB_REQ_VALID,

input 	`CACHE_LINE_SIZE 	ICACHE_RESP_BITS_DATABLOCK,
input						ICACHE_RESP_VALID,
input						PTWINVALIDATE,
input						TLB_RESP_MISS,
input						TLB_RESP_XCPT_IF,
//--------------------------------------------------------------------------------------------------------------------------
// D-CACHE  INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
output                      DMEM_REQ_VALID,  
output	 `DATA_SIZE		    DMEM_OP_TYPE,
output   [4:0]              DMEM_REQ_CMD,
output   `WORD_DATA         DMEM_REQ_BITS_DATA,
output   `ADDR              DMEM_REQ_BITS_ADDR,
output   [7:0]              DMEM_REQ_BITS_TAG,
output                      DMEM_REQ_INVALIDATE_LR,
output                      DMEM_REQ_BITS_KILL,
input                       DMEM_ORDERED,
//TODO: commented due: declared but not read
//input                       DMEM_REPLAY_NEXT_VALID,
input                       DMEM_REQ_READY,
//TODO: commented due: declared but not read
//input    `WORD_DATA         DMEM_RESP_BITS_DATA,
input    `WORD_DATA         DMEM_RESP_BITS_DATA_SUBW,
//TODO: commented due: declared but not read
//input                       DMEM_RESP_BITS_HAS_DATA,
input                       DMEM_RESP_BITS_NACK,
input                       DMEM_RESP_BITS_REPLAY,
input                       DMEM_RESP_VALID,
input                       DMEM_XCPT_MA_ST,
input                       DMEM_XCPT_MA_LD,
input                       DMEM_XCPT_PF_ST,
input                       DMEM_XCPT_PF_LD,
//--------------------------------------------------------------------------------------------------------------------------
// DEBUGGING MODULE SIGNALS
//--------------------------------------------------------------------------------------------------------------------------
input                       istall_test,
// PC
output `ADDR                IO_FETCH_PC,
output `ADDR                IO_DEC_PC,
output `ADDR                IO_RR_PC,
output `ADDR                IO_EXE_PC,
output `ADDR                IO_WB_PC,

output                      IO_WB_PC_VALID,
output [4:0]                IO_WB_ADDR,
output                      IO_WB_WE,
output [63:0]               IO_WB_BITS_ADDR,

input `ADDR		            IO_FETCH_PC_VALUE,
input			            IO_FETCH_PC_UPDATE,

input                       IO_REG_READ,
input [4:0]                 IO_REG_ADDR,     // Address used for both read and write operations
output [63:0]               IO_REG_READ_DATA,
input                       IO_REG_WRITE,
input [63:0]                IO_REG_WRITE_DATA,
// PMU INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
output                      io_core_pmu_branch_miss,
output                      io_core_pmu_EXE_STORE,
output                      io_core_pmu_EXE_LOAD,
//output   [39:0]             io_core_pmu_EXE_PC,
output                      io_core_pmu_new_instruction
//--------------------------------------------------------------------------------------------------------------------------
// SEÑALES EXTRAS NECESARIAS PARA CONECTAR AL SOC - NO HACEN NADA, PERO SIN ELLAS EXISTE UN ERROR
//--------------------------------------------------------------------------------------------------------------------------
    `ifdef CHISEL
    ,
    output io_dmem_req_bits_phys,
    output[31:0] io_fpu_inst,
    output[63:0] io_fpu_fromint_data,
    output[2:0] io_fpu_fcsr_rm,
    input  io_fpu_fcsr_flags_valid,
    input [4:0] io_fpu_fcsr_flags_bits,
    input [63:0] io_fpu_store_data,
    input [63:0] io_fpu_toint_data,
    output io_fpu_dmem_resp_val,
    output[2:0] io_fpu_dmem_resp_type,
    output[4:0] io_fpu_dmem_resp_tag,
    output[63:0] io_fpu_dmem_resp_data,
    input  io_rocc_cmd_ready,
    output io_rocc_cmd_valid,
    output[6:0] io_rocc_cmd_bits_inst_funct,
    output[4:0] io_rocc_cmd_bits_inst_rs2,
    output[4:0] io_rocc_cmd_bits_inst_rs1,
    output io_rocc_cmd_bits_inst_xd,
    output io_rocc_cmd_bits_inst_xs1,
    output io_rocc_cmd_bits_inst_xs2,
    output[4:0] io_rocc_cmd_bits_inst_rd,
    output[6:0] io_rocc_cmd_bits_inst_opcode,
    output[63:0] io_rocc_cmd_bits_rs1,
    output[63:0] io_rocc_cmd_bits_rs2,
    output io_rocc_s,
    output io_rocc_exception,
    input [31:0] io_icache_resp_bits_data,
    input  io_icache_mem_acquire_valid,
    input [25:0] io_icache_mem_acquire_bits_addr_block,
    input  io_icache_mem_acquire_bits_client_xact_id,
    input [1:0] io_icache_mem_acquire_bits_addr_beat,
    input [127:0] io_icache_mem_acquire_bits_data,
    input  io_icache_mem_acquire_bits_is_builtin_type,
    input [2:0] io_icache_mem_acquire_bits_a_type,
    input [16:0] io_icache_mem_acquire_bits_union,
    input  io_icache_mem_grant_ready,
    input  io_tlb_req_ready,
    input [19:0] io_tlb_resp_ppn,
    input  io_tlb_resp_xcpt_ld,
    input  io_tlb_resp_xcpt_st,
    input [7:0] io_tlb_resp_hit_idx,
    input  io_tlb_ptw_req_valid,
    input [26:0] io_tlb_ptw_req_bits_addr,
    input [1:0] io_tlb_ptw_req_bits_prv,
    input  io_tlb_ptw_req_bits_store,
    input  io_tlb_ptw_req_bits_fetch,
    input  io_csr_status_sd,
    input [30:0] io_csr_status_zero2,
    input  io_csr_status_sd_rv32,
    input [8:0] io_csr_status_zero1,
    input [4:0] io_csr_status_vm,
    input  io_csr_status_mprv,
    input [1:0] io_csr_status_xs,
    input [1:0] io_csr_status_fs,
    input [1:0] io_csr_status_prv3,
    input  io_csr_status_ie3,
    input [1:0] io_csr_status_prv2,
    input  io_csr_status_ie2,
    input [1:0] io_csr_status_prv1,
    input  io_csr_status_ie1,
    input [1:0] io_csr_status_prv,
    input  io_csr_status_ie,
    input [31:0] io_csr_ptbr,
    input  io_csr_fatc,
    input [63:0] io_csr_time,
    input [2:0] io_csr_fcsr_rm,
    output io_csr_fcsr_flags_valid,
    output[4:0] io_csr_fcsr_flags_bits,
    input  io_csr_pcr_req_valid,
    input  io_csr_pcr_req_bits_coreId,
    input [11:0] io_csr_pcr_req_bits_addr,
    input [2:0] io_csr_pcr_req_bits_cmd,
    input [63:0] io_csr_pcr_req_bits_data,
    output[63:0] io_counter_wb,
    //Refactor unused
    input    [7:0]              DMEM_RESP_BITS_TAG,
    input                       CSR_CSR_REPLAY,
    input [39:0] io_dmem_resp_bits_addr,
    input [4:0] io_dmem_resp_bits_cmd,
    input [3:0] io_dmem_resp_bits_typ,
    input [63:0] io_dmem_resp_bits_store_data,
    input [7:0] io_dmem_replay_next_bits,
    output io_fpu_valid,
    input  io_fpu_fcsr_rdy,
    input  io_fpu_nack_mem,
    input  io_fpu_illegal_rm,
    output io_fpu_killx,
    output io_fpu_killm,
    input  io_fpu_dec_wen,
    input  io_fpu_dec_ren1,
    input  io_fpu_dec_ren2,
    input  io_fpu_dec_ren3,
    input  io_fpu_sboard_set,
    input  io_fpu_sboard_clr,
    input [4:0] io_fpu_sboard_clra
    `endif   
);
`ifdef CHISEL
assign io_dmem_req_bits_phys = 1'b0; 
`endif   
//--------------------------------------------------------------------------------------------------------------------------
// LOCKS
//--------------------------------------------------------------------------------------------------------------------------
wire						lock_FETCH;
wire						lock_DEC;
wire						lock_RR;
wire                        lock_FETCH_DELAY;
wire						lock_DEPENDENCY;
wire						lock_EXE;
wire                        lock_WB;
wire						lock_EXT_M;
//--------------------------------------------------------------------------------------------------------------------------
// EXCEPTIONS
//--------------------------------------------------------------------------------------------------------------------------
wire                        FETCH_XCPT;
wire        `WORD_DATA      FETCH_XCPT_CAUSE;

wire                        DEC_XCPT;
wire        `WORD_DATA      DEC_XCPT_CAUSE;
wire                        DEC_XCPT_0;
wire        `WORD_DATA      DEC_XCPT_CAUSE_0;
wire                        DEC_XCPT_ILLEGAL_INST;

wire                        RR_XCPT;
wire        `WORD_DATA      RR_XCPT_CAUSE;
wire                        RR_XCPT_0;
wire        `WORD_DATA      RR_XCPT_CAUSE_0;

wire                        EXE_XCPT;
wire        `WORD_DATA      EXE_XCPT_CAUSE;
wire                        EXE_XCPT_0;
wire        `WORD_DATA      EXE_XCPT_CAUSE_0;
wire                        EXE_NEXT_PC_MISSALIGNED;

wire                        WB_XCPT;
wire                        WB_XCPT_0;
wire        `WORD_DATA      WB_XCPT_CAUSE;

wire                        FETCH_XCPT_MISALIGNED;

//--------------------------------------------------------------------------------------------------------------------------
// FETCH SIGNALS
//--------------------------------------------------------------------------------------------------------------------------
wire 	    `ADDR			FETCH_PC;
wire                        FETCH_PC_VALID;
wire 		`WORD_INST	    FETCH_INST;

wire                        FETCH_REQ_Kill;
wire                        FETCH_same_block;
//-----------------------------------------------------------------------------------------------------------------
// PREDICTOR-FETCH SIGNALS
//-----------------------------------------------------------------------------------------------------------------
wire 					PREDICTOR_predict;
wire 		[1:0]		PREDICTOR_TNT;
wire		`ADDR		PREDICTOR_branch_addr;
wire 					PREDICTOR_TAKE_BRANCH;
//-----------------------------------------------------------------------------------------------------------------
// PREDICTOR-EXE SIGNALS
//-----------------------------------------------------------------------------------------------------------------
wire 					PREDICTOR_hit;
//--------------------------------------------------------------------------------------------------------------------------
// DECODE SIGNALS
//--------------------------------------------------------------------------------------------------------------------------
wire 						FETCH_DEC_flush_P1;
wire 						FETCH_DEC_flush_P2;

wire		`ADDR			DEC_PC;
wire                        DEC_PC_VALID;
wire 		`WORD_INST	    DEC_INST;
wire 		[15:0]		    DEC_Control_Signal;

wire 		[4:0]			DEC_Src1_FIELD; 
wire 		[4:0]			DEC_Src2_FIELD;

wire 						DEC_JAL;
wire		`ADDR			DEC_JAL_target_addr;

wire                        DEC_BRANCH;
   
//--------------------------------------------------------------------------------------------------------------------------
// READ REGISTER SIGNALS
//--------------------------------------------------------------------------------------------------------------------------
wire 						DEC_RR_flush_P1;
wire 						DEC_RR_flush_P2;
wire 						RR_EXE_LOCK_PIPELINE_BY_DEPENDENCY;

wire		`ADDR			RR_PC;
wire                        RR_PC_VALID;
wire 		`WORD_INST	    RR_INST;
wire 		[15:0]		    RR_Control_Signal;

wire 		[4:0]			RR_Src1_FIELD; 
wire 		[4:0]			RR_Src2_FIELD;

wire 		`WORD_DATA		RR_Src1_Data; 
wire 		`WORD_DATA		RR_Src2_Data; 

wire		`ADDR			RR_JAL_NEXT_PC;
wire		[4:0]			RR_JAL_write_addr;
wire 						RR_JAL_write_addr_ENA;

//--------------------------------------------------------------------------------------------------------------------------
// EXECUTION SIGNALS
//--------------------------------------------------------------------------------------------------------------------------
wire 						RR_EXE_flush_P1;
wire 						RR_EXE_flush_P2;

wire                        EXE_EXCEPTION;
wire		`ADDR			EXE_PC;
wire                        EXE_PC_VALID;
wire                        EXE_PC_LOAD_VALID;
wire 		`WORD_INST	    EXE_INST;
wire 		[15:0]		    EXE_Control_Signal;

wire 		[4:0]			EXE_DST_FIELD; 

wire 		[6:0]			EXE_OPCODE;
wire 		[2:0]			EXE_FUNCT3;
wire 		[6:0]			EXE_FUNCT7;
wire 		[4:0]			RD_FIELD;

wire 						EXE_INT_UNIT_VALID;
wire						EXE_INT_32;
wire 						EXE_OPCODE_VALID;
wire 						EXE_IMMEDIATE;
wire 		[11:0]		    IMM12_INT;
wire 		[19:0]		    IMM20_INT;

wire 						EXE_jalr;
wire 						EXE_JALR_VALID;
wire						EXE_JAL_VALID;
wire 		`ADDR			EXE_jalr_target_addr;

wire 		`WORD_DATA	    EXE_Src1_Data; 
wire 		`WORD_DATA	    EXE_Src2_Data;

wire 		[4:0]			EXE_SRC1_FIELD;
wire 		[4:0]			EXE_SRC2_FIELD;
wire 		`WORD_DATA	    EXE_Src1_Data_BYPASS;
wire 		`WORD_DATA	    EXE_Src2_Data_BYPASS;

wire 						EXE_INT1_READY;
wire 		`WORD_DATA	    EXE_INT1_RESULT;
wire 		[4:0]			EXE_INT1_WRITE_ADDR;

//TODO:Remove if possible.
//TODO: Commented due to: Variables set but not read
//wire                      EXE_EXCEPCION_INVALID_INST;
//wire 						EXCEPCION_DIV_BY_0;				
//wire						EXCEPCION_DIV_OVER;

wire                        EXE_CSR_ENABLE;
// BRANCH UNIT
wire 		[11:0] 		    IMM12_BRANCH;
wire 		`ADDR			EXE_BRANCH_offset;
			
wire 						EXE_BRANCH;
//TODO:Remove if possible.
//Commented due to: Variable 'EXE_BRANCH_TNT' set but not read
//wire 						EXE_BRANCH_TNT;
wire		`ADDR			EXE_BRANCH_target;
wire		`ADDR			EXE_BRANCH_result;
//TODO:Remove if possible.
//Commented due to: Variable 'EXE_BRANCH_invalid' set but not read
//wire 						EXE_BRANCH_invalid;
wire						EXE_MISS_PREDICTION;

// MEMORY OPERATIONS LOAD/STORE/AMO	
wire                        EXE_MEM;

wire                        DMEM_LOCK;

wire                        EXE_AMO;
wire        [4:0]           EXE_AMO_FUNCT;
wire 						EXE_LOAD;
wire 						EXE_STORE;
wire 		[11:0]		    EXE_IMM12_LOAD;
wire 		[11:0]		    EXE_IMM12_STORE;

//TODO:Remove if possible.
//Commented due to: Variable 'EXE_PC_LOAD' set but not read
//wire		`ADDR			EXE_PC_LOAD;
wire 						EXE_LOAD_READY;
wire		`WORD_DATA	    EXE_LOAD_DATA;
wire		[4:0]			EXE_LOAD_WRITE_ADDR;

//--------------------------------------------------------------------------------------------------------------------------
// WRITE-BACK SIGNALS
//--------------------------------------------------------------------------------------------------------------------------
wire 						EXE_WB_lock;
//wire 						EXE_WB_flush;

wire		`ADDR			WB_PC;
wire                        WB_PC_VALID;
wire        `WORD_INST      WB_INST;

wire                        WB_CSR_ENABLE;
wire                        WB_FETCH_CAUSE;
wire                        WB_DMEM_CAUSE;

//wire                        WB_BRANCH;

wire						WB_WE;	
wire		`WORD_DATA	    WB_DATA_TO_CSR;	
wire		[4:0]			WB_ADDR;
wire        `WORD_DATA      WB_DATA;

wire                        WB_WE_TO_RF;  
wire        `WORD_DATA      WB_DATA_TO_RF;
wire        [4:0]           WB_ADDR_TO_RF;

wire                        WB_WE_TO_BYPASS;
wire        `WORD_DATA      WB_DATA_TO_BYPASS;
wire        [4:0]           WB_ADDR_TO_BYPASS;


wire        `ADDR           WB_REQ_BITS_ADDR;




//--------------------------------------------------------------------------------------------------------------------------
// PIPELINE LOCKS AND FLUSH
//--------------------------------------------------------------------------------------------------------------------------
wire    CORE_lock;

wire    FENCE;
wire    FENCE_I;
wire    FENCE_I_LOCK;

//wire    ID_CSR;
wire    RR_CSR;
wire    EXE_CSR;
wire    WB_CSR;
wire    CSR_LOCK;

wire    DEC_fence_next;
wire    DEC_amo_aq;
wire    DEC_amo_rl;
wire    DEC_amo;
wire    DEC_mem_busy;

reg     reg_fence;
wire    DEC_do_fence;
wire    DEC_mem;

assign  DEC_mem = DEC_Control_Signal[2] || DEC_Control_Signal[13];
assign  FENCE = DEC_Control_Signal[11] & (DEC_INST[14:12] == 3'b000);
assign  FENCE_I = DEC_Control_Signal[11] & (DEC_INST[14:12] == 3'b001);
assign  DEC_amo = DEC_Control_Signal[13];
assign  DEC_mem_busy = !DMEM_ORDERED || DMEM_REQ_VALID;

assign  DEC_amo_aq = DEC_INST[26];
assign  DEC_amo_rl = DEC_INST[25];
assign  DEC_fence_next = FENCE || (DEC_amo && DEC_amo_rl);


always@(posedge CLK)
begin
if(~RST)
    reg_fence <=  1'b0;
else 
    reg_fence <= DEC_fence_next || (reg_fence && DEC_mem_busy);
end

assign  DEC_do_fence = DEC_mem_busy && ( (DEC_amo && DEC_amo_aq) || FENCE_I || (reg_fence && DEC_mem) /*|| ID_CSR*/);
//--------------------------------------------------------------------------------------------------------------------------

assign  RR_CSR = RR_Control_Signal[12];
assign  EXE_CSR = EXE_CSR_ENABLE;
assign  WB_CSR = WB_CSR_ENABLE;
assign  CSR_LOCK = (RR_CSR | EXE_CSR | WB_CSR );

//--------------------------------------------------------------------------------------------------------------------------
assign lock_DEC =  lock_RR  | DEC_do_fence | CSR_LOCK/* julian pavon */| istall_test;
assign lock_RR = lock_EXE | RR_EXE_LOCK_PIPELINE_BY_DEPENDENCY ;
assign lock_EXE = lock_WB | lock_EXT_M | DMEM_LOCK | CSR_CSR_STALL;
assign lock_WB=  1'b0;
assign CORE_lock = lock_EXE | lock_RR | lock_DEC;
//--------------------------------------------------------------------------------------------------------------------------
assign FETCH_same_block = (FETCH_PC[39:4] == DEC_PC[39:4]) & FETCH_PC_VALID & DEC_PC_VALID & ~FENCE_I; 
assign PREDICTOR_TAKE_BRANCH = PREDICTOR_predict & PREDICTOR_TNT[1];
//--------------------------------------------------------------------------------------------------------------------------
assign FETCH_DEC_flush_P1 = WB_XCPT | CSR_ERET | EXE_MISS_PREDICTION | EXE_jalr;
assign FETCH_DEC_flush_P2 = PREDICTOR_TAKE_BRANCH | DEC_JAL | (lock_FETCH & ~lock_DEC);
assign DEC_RR_flush_P1 = WB_XCPT | CSR_ERET | EXE_MISS_PREDICTION | EXE_jalr;
assign DEC_RR_flush_P2 = CSR_LOCK |  DEC_do_fence/* julian pavon */| istall_test;
assign RR_EXE_flush_P1 = WB_XCPT | CSR_ERET | EXE_MISS_PREDICTION | EXE_jalr ;
assign RR_EXE_flush_P2 = RR_EXE_LOCK_PIPELINE_BY_DEPENDENCY ;
//assign EXE_WB_flush = 1'b0;
//--------------------------------------------------------------------------------------------------------------------------
// DEBBUG MODULE
//--------------------------------------------------------------------------------------------------------------------------

reg      `ADDR           IO_BASE_ADDR;
//initial IO_BASE_ADDR =  40'h0040000000;

always@(posedge CLK)
begin
if(~SOFT_RST)
    IO_BASE_ADDR <=  40'h0080000000;
else if(~RST)
        IO_BASE_ADDR <=  40'h0040000000;
     else
        IO_BASE_ADDR <= IO_BASE_ADDR;
end

//--------------------------------------------------------------------------------------------------------------------------
// FETCH_1 STAGE
//--------------------------------------------------------------------------------------------------------------------------


FETCH FETCH(
	.CLK						(CLK),
	.RST						(RST),
	.RESET_ADDRESS				(RESET_ADDRESS),
	.CORE_lock					(CORE_lock),
	.lock_FETCH				    (lock_FETCH),
    .FETCH_same_block           (FETCH_same_block),
    .FENCE_I                    (FENCE_I),
    //--------------------------------------------------
    // PC GENERATION SIGNALS
    //--------------------------------------------------
    .WB_EXCEPTION               (WB_XCPT), 
    .CSR_ERET                   (CSR_ERET),
    .CSR_EVEC                   (CSR_EVEC),
    
    .PREDICTOR_TAKE_BRANCH      (PREDICTOR_TAKE_BRANCH),
	.PREDICTOR_branch_addr	    (PREDICTOR_branch_addr),

	.EXE_MISS_PREDICTION        (EXE_MISS_PREDICTION),	
	.EXE_branch_addr			(EXE_BRANCH_result),					
	
	.DEC_JAL					(DEC_JAL),						
	.jal_addr					(DEC_JAL_target_addr),		

	.EXE_jalr					(EXE_jalr),						
	.jalr_addr					(EXE_jalr_target_addr),	

	.FETCH_PC				    (FETCH_PC),
	.PC_Valid                   (FETCH_PC_VALID),
	.FETCH_INST                 (FETCH_INST),
	
	.FETCH_XCPT_MISALIGNED	    (FETCH_XCPT_MISALIGNED),
	//--------------------------------------------------
	// INPUTS FROM CCM SET PC
	//--------------------------------------------------
	.FETCH_PC_VALUE		(IO_FETCH_PC_VALUE),
	.FETCH_PC_UPDATE	(IO_FETCH_PC_UPDATE),
	//--------------------------------------------------
    // INPUTS FROM ICACHE 
    //--------------------------------------------------
   .ICACHE_RESP_BITS_DATABLOCK  (ICACHE_RESP_BITS_DATABLOCK),
   .ICACHE_RESP_VALID           (ICACHE_RESP_VALID),
   .PTWINVALIDATE               (PTWINVALIDATE),
   .TLB_RESP_MISS               (TLB_RESP_MISS),
   .TLB_RESP_XCPT_IF            (TLB_RESP_XCPT_IF),
    //--------------------------------------------------
    // OUTPUTS TO ICACHE 
    //--------------------------------------------------
    .ICACHE_INVALIDATE           (ICACHE_INVALIDATE),
    .ICACHE_REQ_BITS_IDX         (ICACHE_REQ_BITS_IDX),
    .ICACHE_REQ_BITS_KILL        (ICACHE_REQ_BITS_KILL),
    .ICACHE_REQ_VALID            (ICACHE_REQ_VALID),
    .ICACHE_RESP_READY           (ICACHE_RESP_READY),
    .TLB_REQ_BITS_VPN            (TLB_REQ_BITS_VPN),
    .TLB_REQ_VALID               (TLB_REQ_VALID)
);

assign FETCH_XCPT = TLB_RESP_XCPT_IF | FETCH_XCPT_MISALIGNED;
assign FETCH_XCPT_CAUSE = (TLB_RESP_XCPT_IF) ? `fault_fetch :(FETCH_XCPT_MISALIGNED) ? `misaligned_fetch:64'b0;

assign DEC_BRANCH = DEC_Control_Signal[4];

BIMODAL_PREDICTOR BIMODAL_PREDICTOR( 
.Stall_FETCH					(CORE_lock  | lock_FETCH ),
.Stall_EXE					    (lock_EXE), 
.CLK							(CLK),
.RST							(RST),

.if_branch_DEC					(DEC_BRANCH),
.if_branch_EX					(EXE_BRANCH),						

.EXE_BRANCH_TARGET				(EXE_BRANCH_target),						
.EXE_Branch_Result			    (EXE_BRANCH_result),					

.DEC_PC						    (DEC_PC),
.FETCH_PC						(FETCH_PC),
.RR_PC						    (RR_PC),					
.EXE_PC							(EXE_PC),					

.PREDICTOR_TNT					(PREDICTOR_TNT),
.PREDICTOR_BRANCH_TARGET		(PREDICTOR_branch_addr),
.PREDICT						(PREDICTOR_predict),

.PREDICTOR_HIT					(PREDICTOR_hit)
);

//--------------------------------------------------------------------------------------------------------------------------
// FETCH/DECODE LATCH
//-------------------------------------------------------------------------------------------------------------------------- 

LATCH_FETCH_DECODE LATCH_FETCH_DECODE(
	.CLK						 (CLK),
	.RST						 (RST),
	.lock_PIPELINE			     (lock_DEC),
	.FLUSH_P1					 (FETCH_DEC_flush_P1),
	.FLUSH_P2					 (FETCH_DEC_flush_P2),
	
	.PC_FROM_FETCH			     (FETCH_PC),
	.PC_TO_DECODE				 (DEC_PC),
	.PC_VALID_FROM_FETCH         (FETCH_PC_VALID),
	.PC_VALID_TO_DEC             (DEC_PC_VALID),
	.INST_FROM_FETCH			 (FETCH_INST),
	.INST_TO_DECODE			     (DEC_INST),
	
	.FETCH_XCPT                  (FETCH_XCPT),
	.FETCH_XCPT_CAUSE            (FETCH_XCPT_CAUSE),
	.DEC_XCPT                    (DEC_XCPT_0),
    .DEC_XCPT_CAUSE              (DEC_XCPT_CAUSE_0)
);

//--------------------------------------------------------------------------------------------------------------------------

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// DECODE STAGE																																				                             	//
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
//	Vector Control_Signal 																																		                            //
// 15,14,,, 	            13          12         11		    10			9			8			7			6			5			4			3			2			1			0	//
// Valid		            AMO		   SYSTEM    MISC-MEM	   OPC_ID	    32-BITS	    HALF	    BYTE		INT-FP	    JUMP		BRANCH	    W-REG		LD/ST		OP-IMM	    OP	//
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// OP			0009        0			0		    0			0			0			0			0			0			0			0			1			0			0			1	//
// OP32			0209		0			0		    0			0			1			0			0			0			0			0			1			0			0			1	//
// OP-IMM		000A		0			0		    0			0			0			0			0			0			0			0			1			0			1			0	//
// OP-IMM32		020A		0			0		    0			0			1			0			0			0			0			0			1			0			1			0	//
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
DECODE DECODE (
.valid_inst                 (DEC_PC_VALID),
.opcode						(DEC_INST[6:0]),
.Control_Signal				(DEC_Control_Signal),
.DEC_XCPT_ILLEGAL_INST      (DEC_XCPT_ILLEGAL_INST)
);

assign DEC_XCPT = DEC_XCPT_0 | DEC_XCPT_ILLEGAL_INST ;
assign DEC_XCPT_CAUSE = (DEC_XCPT_0) ? DEC_XCPT_CAUSE_0 :(DEC_XCPT_ILLEGAL_INST) ? `illegal_instruction:64'b0;


// JUMP AND LINK (JAL) INSTRUCTION JUMP IN DECODE BUT PERFORM THE PC+4 AND WRITE REGISTER IN EXE AND WB STAGES.
DEC_JUMP_AND_LINK DEC_JUMP_AND_LINK (
.PC							(DEC_PC),
.Instruction				(DEC_INST),
.Control_Signal				(DEC_Control_Signal),

.JUMP_LINK_ENA				(DEC_JAL),
.JUMP_LINK_target_addr		(DEC_JAL_target_addr)
);

//--------------------------------------------------------------------------------------------------------------------------
// DECODE/RR LATCH
//--------------------------------------------------------------------------------------------------------------------------

LATCH_DECODE_RR LATCH_DECODE_RR(
	.CLK							(CLK),
	.RST							(RST),
	.lock							(lock_RR),
	.FLUSH_P1						(DEC_RR_flush_P1),
	.FLUSH_P2						(DEC_RR_flush_P2 | RR_XCPT),
	
	.PC_FROM_DECODE					(DEC_PC),
	.PC_TO_RR						(RR_PC),
	
	.PC_VALID_FROM_DEC              (DEC_PC_VALID),
	.PC_VALID_TO_RR                 (RR_PC_VALID),
	
	.INST_FROM_DECODE				(DEC_INST),
	.INST_TO_RR						(RR_INST),
	
	.CONTROLSIGNAL_FROM_DECODE		(DEC_Control_Signal),
	.CONTROLSIGNAL_TO_RR			(RR_Control_Signal),
	
    .DEC_XCPT                    (DEC_XCPT),
    .DEC_XCPT_CAUSE              (DEC_XCPT_CAUSE),
    .RR_XCPT                     (RR_XCPT_0),
    .RR_XCPT_CAUSE               (RR_XCPT_CAUSE_0)
);

assign RR_XCPT = (RR_PC_VALID & CSR_INTERRUPT) | RR_XCPT_0;
assign RR_XCPT_CAUSE = (RR_PC_VALID & CSR_INTERRUPT) ? CSR_INTERRUPT_CAUSE: (RR_XCPT_0)? RR_XCPT_CAUSE_0 : 64'b0 ;

//--------------------------------------------------------------------------------------------------------------------------
// READ REGISTER STAGE
//--------------------------------------------------------------------------------------------------------------------------

assign RR_Src1_FIELD=RR_INST[19:15]; 
assign RR_Src2_FIELD=RR_INST[24:20];

// julian pavon rivera
// Wires to handle the debug communication
wire            reg_write;
wire [4:0]      reg_write_addr;
wire [63:0]     reg_write_data;
wire [4:0]      reg_read_addr;
assign reg_write = WB_WE_TO_RF | IO_REG_WRITE;
assign reg_write_addr = (WB_ADDR_TO_RF & {5{!IO_REG_WRITE}}) | (IO_REG_ADDR & {5{IO_REG_WRITE}});
assign reg_write_data = (WB_DATA_TO_RF & {64{!IO_REG_WRITE}}) | (IO_REG_WRITE_DATA & {64{IO_REG_WRITE}});
assign reg_read_addr = (RR_Src1_FIELD & {5{!IO_REG_READ}}) | (IO_REG_ADDR & {5{IO_REG_READ}});

INT_REGISTER_FILE	INT_REGISTER_FILE(
	.CLK						    (CLK),
	
	.write_enable1					(reg_write), /*(WB_WE_TO_RF)*/
	.write_addr1					(reg_write_addr), /*(WB_ADDR_TO_RF)*/
	.write_data1					(reg_write_data), /*(WB_DATA_TO_RF)*/

	.read_addr1						(reg_read_addr),/*(RR_Src1_FIELD)*/
	.read_addr2						(RR_Src2_FIELD),

	.read_data1						(RR_Src1_Data),
	.read_data2						(RR_Src2_Data)

);

//TODO:As it is does nothing, remove it
CONTROL_DEPENDENCY CONTROL_DEPENDENCY(
.LOCK_PIPELINE			(RR_EXE_LOCK_PIPELINE_BY_DEPENDENCY)
);

//--------------------------------------------------------------------------------------------------------------------------
// RR/EXECUTION LATCH
//--------------------------------------------------------------------------------------------------------------------------

LATCH_RR_EXE LATCH_RR_EXE(
	.CLK								(CLK),
	.RST								(RST),
	.lock								(lock_EXE),
	.FLUSH_P1							(RR_EXE_flush_P1),
	.FLUSH_P2							(RR_EXE_flush_P2),
	
	.PC_FROM_RR							(RR_PC),
	.PC_TO_EXE							(EXE_PC),
	
	.PC_VALID_FROM_RR                   (RR_PC_VALID),
	.PC_VALID_TO_EXE                    (EXE_PC_VALID),
	
	.INST_FROM_RR						(RR_INST),
	.INST_TO_EXE						(EXE_INST),
	
	.CONTROLSIGNAL_FROM_RR				(RR_Control_Signal),
	.CONTROLSIGNAL_TO_EXE				(EXE_Control_Signal),
	
	.Src1_Data_FROM_RR					(RR_Src1_Data),
	.Src1_Data_TO_EXE					(EXE_Src1_Data),
	.Src2_Data_FROM_RR					(RR_Src2_Data),
	.Src2_Data_TO_EXE					(EXE_Src2_Data),

    .RR_XCPT                            (RR_XCPT),
    .RR_XCPT_CAUSE                      (RR_XCPT_CAUSE),
    .EXE_XCPT                           (EXE_XCPT_0),
    .EXE_XCPT_CAUSE                     (EXE_XCPT_CAUSE_0)
);

//--------------------------------------------------------------------------------------------------------------------------
// EXECUTION STAGE
//--------------------------------------------------------------------------------------------------------------------------

assign  EXE_MEM = EXE_AMO | EXE_STORE  | EXE_LOAD;

XCPT_PRIORITY XCPT_PRIORITY(
.priority_0     (EXE_XCPT_0),                    .cause_0        (EXE_XCPT_CAUSE_0),
.priority_1     (EXE_NEXT_PC_MISSALIGNED),       .cause_1        (`misaligned_fetch),
.priority_2     (DMEM_XCPT_MA_ST & EXE_MEM),     .cause_2        (`misaligned_store),
.priority_3     (DMEM_XCPT_MA_LD & EXE_MEM),     .cause_3        (`misaligned_load),
.priority_4     (DMEM_XCPT_PF_ST & EXE_MEM),     .cause_4        (`fault_store),
.priority_5     (DMEM_XCPT_PF_LD & EXE_MEM),     .cause_5        (`fault_load),
.priority_6     (1'b0),                          .cause_6        (64'b0),
.priority_7     (1'b0),                          .cause_7        (64'b0),

.xcpt           (EXE_XCPT),                      .xcpt_cause     (EXE_XCPT_CAUSE)
);

assign 			EXE_SRC1_FIELD = EXE_INST[19:15];
assign 			EXE_SRC2_FIELD = EXE_INST[24:20];

EXE_BYPASS EXE_BYPASS_SRC1 (
.EXE_SRC_FIELD			(EXE_SRC1_FIELD),
.RR_EXE_DATA1			(EXE_Src1_Data),   
.WB_WRITE_DATA1		    (WB_DATA_TO_BYPASS),
.WB_WRITE_ADDR1		    (WB_ADDR_TO_BYPASS),
.WB_WE1					(WB_WE_TO_BYPASS),

.BYPASS_SOURCE			(EXE_Src1_Data_BYPASS)
);

EXE_BYPASS EXE_BYPASS_SRC2 (
.EXE_SRC_FIELD			(EXE_SRC2_FIELD),
.RR_EXE_DATA1			(EXE_Src2_Data),   
.WB_WRITE_DATA1		    (WB_DATA_TO_BYPASS),
.WB_WRITE_ADDR1		    (WB_ADDR_TO_BYPASS),
.WB_WE1					(WB_WE_TO_BYPASS),

.BYPASS_SOURCE			(EXE_Src2_Data_BYPASS)
);

assign 			EXE_OPCODE = EXE_INST[6:0];
assign 			EXE_FUNCT3 = EXE_INST[14:12];
assign 			EXE_FUNCT7 = EXE_INST[31:25];
assign 			EXE_DST_FIELD = EXE_INST[11:7];

assign 			EXE_INT_UNIT_VALID = (EXE_Control_Signal[0] | EXE_Control_Signal[1]) & EXE_Control_Signal[3] & ~EXE_Control_Signal[5];
assign			EXE_INT_32 = EXE_Control_Signal[9];
assign 			EXE_OPCODE_VALID = EXE_Control_Signal[10] & ~EXE_Control_Signal[11];

assign 			EXE_JALR_VALID = (EXE_Control_Signal[0] & EXE_Control_Signal[3] & EXE_Control_Signal[5]) & (EXE_FUNCT3 ==3'b000);
assign			EXE_JAL_VALID		=	~EXE_Control_Signal[0] & EXE_Control_Signal[3] & EXE_Control_Signal[5] ;   

assign 			EXE_IMMEDIATE = EXE_Control_Signal[1] ;
assign 			IMM12_INT = EXE_INST[31:20];
assign 			IMM20_INT = EXE_INST[31:12];

EXE_INTEGER_UNIT EXE_INTEGER_UNIT(
	.CLK								(CLK),
	.RST								(RST),
	
	.WB_EXCEPTION                       (WB_XCPT),
	
	.PC									(EXE_PC),
	.valid_inst							(EXE_INT_UNIT_VALID),
	.INT_32								(EXE_INT_32),
	.valid_opcode						(EXE_OPCODE_VALID),
	.OPCODE_FIELD						(EXE_OPCODE),
	.Funct3_FIELD						(EXE_FUNCT3),
	.Funct7_FIELD						(EXE_FUNCT7),
	
	.Data_Source_1						(EXE_Src1_Data_BYPASS),
	.Data_Source_2						(EXE_Src2_Data_BYPASS),
	
	.Immediate							(EXE_IMMEDIATE),
	.Source_Immediate_12				(IMM12_INT),
	.Source_Immediate_20				(IMM20_INT),
	
	.RD_FIELD							(EXE_DST_FIELD),
	
	.Ready								(EXE_INT1_READY),
	.ALUresult							(EXE_INT1_RESULT),
	.Addr_write							(EXE_INT1_WRITE_ADDR),
	.jal_valid							(EXE_JAL_VALID),
	.jalr_valid							(EXE_JALR_VALID),
	.jalr_ADDR							(EXE_jalr_target_addr),
	.jalr_ready							(EXE_jalr),
	
	.lock_EXT_M							(lock_EXT_M)
);

assign  EXE_NEXT_PC_MISSALIGNED = EXE_jalr & (EXE_jalr_target_addr[1:0] != 2'b00); 

assign 			IMM12_BRANCH = {EXE_INST[31],EXE_INST[7],EXE_INST[30:25],EXE_INST[11:8]};
assign 			EXE_BRANCH_offset = {{27{IMM12_BRANCH[11]}},IMM12_BRANCH,1'b0}; 
assign 			EXE_BRANCH = EXE_Control_Signal[4] ;

EXE_BRANCH_UNIT EXE_BRANCH_UNIT(
.PC										(EXE_PC),
.branch_offset							(EXE_BRANCH_offset),
.Funct3_FIELD							(EXE_FUNCT3),

.INT_BRANCH								(EXE_BRANCH),
.Source1								(EXE_Src1_Data_BYPASS),
.Source2								(EXE_Src2_Data_BYPASS),

//.Take_Branch							(EXE_BRANCH_TNT),
.Branch_target							(EXE_BRANCH_target),
.Branch_Result							(EXE_BRANCH_result)
//.Invalid_branch							(EXE_BRANCH_invalid)
);

assign EXE_MISS_PREDICTION = (EXE_BRANCH && ~PREDICTOR_hit) ;

assign 			EXE_IMM12_LOAD = EXE_INST[31:20];
assign 			EXE_IMM12_STORE = {EXE_INST[31:25],EXE_INST[11:7]};
assign 			EXE_LOAD = EXE_Control_Signal[2] & EXE_Control_Signal[3];
assign 			EXE_STORE = EXE_Control_Signal[2] & ~EXE_Control_Signal[3];
assign 			EXE_AMO = EXE_Control_Signal[13];
assign          EXE_AMO_FUNCT = EXE_INST[31:27];

EXE_LOAD_STORE_UNIT EXE_LOAD_STORE_UNIT(
.CLK									(CLK),
.RST									(RST),
.Funct3_FIELD							(EXE_FUNCT3),
.WB_EXCEPTION                           (WB_XCPT),
.CSR_ERET                               (CSR_ERET),

.Immediate_load							(EXE_IMM12_LOAD),
.Immediate_store						(EXE_IMM12_STORE),
.Source1								(EXE_Src1_Data_BYPASS),
.Source2								(EXE_Src2_Data_BYPASS),
.DST_FIELD								(EXE_DST_FIELD),

.IO_BASE_ADDR                           (IO_BASE_ADDR),
//-------------------------------------------------------------
// AMO INTERFACE
//-------------------------------------------------------------
.AMO                                    (EXE_AMO),
.AMO_FUNCT                              (EXE_AMO_FUNCT),
//-------------------------------------------------------------
// LOAD INTERFACE
//-------------------------------------------------------------
// Control Signals LOAD
.LOAD									(EXE_LOAD),
// Control Signals STORE
.STORE									(EXE_STORE),
// DCACHE Answer
.DMEM_RESP_BITS_REPLAY                  (DMEM_RESP_BITS_REPLAY),
.DMEM_RESP_BITS_DATA					(DMEM_RESP_BITS_DATA_SUBW),
.DMEM_REQ_READY						    (DMEM_REQ_READY),
.DMEM_RESP_VALID                        (DMEM_RESP_VALID),
.DMEM_RESP_BITS_NACK                    (DMEM_RESP_BITS_NACK),
.DMEM_XCPT_MA_ST                        (DMEM_XCPT_MA_ST),
.DMEM_XCPT_MA_LD                        (DMEM_XCPT_MA_LD),
.DMEM_XCPT_PF_ST                        (DMEM_XCPT_PF_ST),
.DMEM_XCPT_PF_LD                        (DMEM_XCPT_PF_LD),

// OUTPUT TO WB
//.MEM_PC								    (EXE_PC_LOAD),
.MEM_READY								(EXE_LOAD_READY),
.MEM_DATA								(EXE_LOAD_DATA),
.WRITE_ADDR						        (EXE_LOAD_WRITE_ADDR),

// Request to DCACHE
.MEM_REQ_VALID                          (DMEM_REQ_VALID),
.MEM_OP_TYPE                            (DMEM_OP_TYPE),
.MEM_REQ_CMD                            (DMEM_REQ_CMD),
.MEM_REQ_BITS_DATA                      (DMEM_REQ_BITS_DATA),
.MEM_REQ_BITS_ADDR                      (DMEM_REQ_BITS_ADDR),
.MEM_REQ_BITS_TAG                       (DMEM_REQ_BITS_TAG),
.MEM_REQ_INVALIDATE_LR                  (DMEM_REQ_INVALIDATE_LR),
.MEM_REQ_BITS_KILL                      (DMEM_REQ_BITS_KILL),
.DMEM_LOCK                              (DMEM_LOCK)
);

//-------------------------------------------------------------------------------------------------------
// DATA  TO WRITE_BACK
//-------------------------------------------------------------------------------------------------------
reg					WE_EXE;
reg	`WORD_DATA	    DATA_EXE;
reg	[4:0]			WRITE_ADDR_EXE;

assign  EXE_CSR_ENABLE = EXE_Control_Signal[12];

always@(*)
begin
case({EXE_CSR_ENABLE,(EXE_LOAD | EXE_AMO),EXE_INT1_READY})
    3'b010: begin
            WE_EXE   =  EXE_LOAD_READY & (EXE_LOAD_WRITE_ADDR != 5'b00000);
            DATA_EXE =  EXE_LOAD_DATA;
            WRITE_ADDR_EXE =  EXE_LOAD_WRITE_ADDR;
            end
    3'b001: begin
            WE_EXE   =  EXE_INT1_READY & (EXE_DST_FIELD != 5'b00000);
            DATA_EXE =  EXE_INT1_RESULT;
            WRITE_ADDR_EXE =  EXE_INT1_WRITE_ADDR;
            end
    3'b100: begin
            WE_EXE   =  (EXE_DST_FIELD != 5'b00000);
            DATA_EXE =  (EXE_FUNCT3[2]) ? {28'b0,EXE_SRC1_FIELD}:EXE_Src1_Data_BYPASS;
            WRITE_ADDR_EXE =  EXE_DST_FIELD;
            end
    default:begin
            WE_EXE   =  1'b0;
            DATA_EXE =  64'b0;
            WRITE_ADDR_EXE =  5'b0;
            end
endcase
end

//-------------------------------------------------------------
// WRITE-BACK LATCH (COMMIT)
//-------------------------------------------------------------

LATCH_EXE_WB LATCH_EXE_WB(
	.CLK							    (CLK),
	.RST								(RST),
	.lock								(lock_EXE), 
	.FLUSH								(WB_XCPT | CSR_ERET),
	
	.PC_FROM_EXE						(EXE_PC),
	.PC_VALID_FROM_EXE                  (EXE_PC_VALID),
	
	.INST_FROM_EXE                      (EXE_INST),
	.INST_TO_WB                         (WB_INST),
	
	.WE_FROM_EXE				        (WE_EXE), 
	.DATA_FROM_EXE				        (DATA_EXE),
	.WRITE_ADDR_FROM_EXE			    (WRITE_ADDR_EXE),
	
	.PC_TO_WB							(WB_PC),
	.PC_VALID_TO_WB                     (WB_PC_VALID),
	
	.WE_TO_WB							(WB_WE),
	.DATA_TO_WB							(WB_DATA),
	.ADDR_TO_WB							(WB_ADDR),
	
	.EXE_CSR_ENABLE                     (EXE_CSR_ENABLE),
    .WB_CSR_ENABLE                      (WB_CSR_ENABLE),
    .DATA_TO_CSR                        (WB_DATA_TO_CSR),
        
	.EXE_XCPT                           (EXE_XCPT),
    .EXE_XCPT_CAUSE                     (EXE_XCPT_CAUSE),
    .WB_XCPT                            (WB_XCPT_0),
    .WB_XCPT_CAUSE                      (WB_XCPT_CAUSE),
    
    .DMEM_REQ_BITS_ADDR                 (DMEM_REQ_BITS_ADDR),
    .WB_REQ_BITS_ADDR                   (WB_REQ_BITS_ADDR)
);
wire WB_CANCEL_WE;
assign WB_CANCEL_WE = WB_XCPT;

assign  WB_WE_TO_BYPASS = WB_WE &  !WB_CSR_ENABLE  & !WB_CANCEL_WE;
assign  WB_DATA_TO_BYPASS= WB_DATA;
assign  WB_ADDR_TO_BYPASS = WB_ADDR;

assign  WB_WE_TO_RF =   WB_WE & !WB_CANCEL_WE;
assign  WB_DATA_TO_RF= (WB_CSR_ENABLE) ? CSR_RW_RDATA:WB_DATA;
assign  WB_ADDR_TO_RF = WB_ADDR;


reg     [2:0]CSR_CMD;
wire    [4:0]WB_rs1;
assign  WB_rs1 = WB_INST[19:15];

always@(*) 
begin
	case ({WB_CSR_ENABLE,WB_INST[14:12]})
       4'b1000 :  CSR_CMD = 3'b100;
       4'b1001 :  CSR_CMD = 3'b001;
       4'b1010 :  CSR_CMD = (WB_rs1 == 5'b00000) ? 3'b101:3'b010;
       4'b1011 :  CSR_CMD = (WB_rs1 == 5'b00000) ? 3'b101:3'b011;
       4'b1101 :  CSR_CMD = 3'b001;
       4'b1110 :  CSR_CMD = (WB_rs1 == 5'b00000) ? 3'b101:3'b010;
       4'b1111 :  CSR_CMD = (WB_rs1 == 5'b00000) ? 3'b101:3'b011;
       default:   CSR_CMD = 3'b000;
    endcase
end

assign  WB_FETCH_CAUSE = (WB_XCPT_CAUSE == 64'h0) | (WB_XCPT_CAUSE == 64'h1);
assign  WB_DMEM_CAUSE =  (WB_XCPT_CAUSE == 64'h4) | (WB_XCPT_CAUSE == 64'h5) | (WB_XCPT_CAUSE == 64'h6) | (WB_XCPT_CAUSE == 64'h7);

assign  WB_XCPT         =  WB_XCPT_0 | CSR_XCPT;
//OUTPUTS TO CSR
assign  CSR_RW_ADDR     = (WB_CSR_ENABLE) ? WB_INST[31:20]:12'h000;
assign  CSR_RW_CMD      = CSR_CMD;
assign  CSR_RW_WDATA    = (WB_CSR_ENABLE) ?  WB_DATA_TO_CSR: (WB_XCPT_0 & WB_FETCH_CAUSE) ? WB_PC: (WB_XCPT_0 & WB_DMEM_CAUSE) ? WB_REQ_BITS_ADDR: 64'b0;
assign  CSR_EXCEPTION   = WB_XCPT_0 ;
assign  CSR_CAUSE       = WB_XCPT_CAUSE;
assign  CSR_RETIRE      = WB_PC_VALID & ~CSR_XCPT & ~WB_XCPT_0 & ~lock_EXE ;
assign  CSR_PC          = WB_PC;

//-------------------------------------------------------------
// SIGNAL PROCESSING FOR PMU
//-------------------------------------------------------------
reg		[39:0]			previous_EXE_PC;
reg                   	new_instruction;
always @(posedge CLK) begin
    if(~RST)begin
        previous_EXE_PC <=0;
        new_instruction <=0;
        end
    else if(previous_EXE_PC!=EXE_PC && EXE_PC_VALID) begin
        previous_EXE_PC <= EXE_PC;
        new_instruction <= 1;
        end
        else new_instruction <= 0;
end
//-------------------------------------------------------------
// PROPAGATED SIGNAL FOR PMU
//-------------------------------------------------------------


assign io_core_pmu_branch_miss = EXE_MISS_PREDICTION;
assign io_core_pmu_EXE_STORE = EXE_STORE;
assign io_core_pmu_EXE_LOAD  = EXE_LOAD;
assign io_core_pmu_new_instruction  = new_instruction;
//assign io_core_pmu_EXE_PC  = EXE_PC;

/*
 * julian pavon rivera
 * All the debugging signals are assigned on this section
 */

assign IO_REG_READ_DATA = RR_Src1_Data;
assign IO_FETCH_PC      = FETCH_PC;
assign IO_DEC_PC        = DEC_PC;
assign IO_RR_PC         = RR_PC;
assign IO_EXE_PC        = EXE_PC;
assign IO_WB_PC         = WB_PC;

assign IO_WB_PC_VALID = WB_PC_VALID;
assign IO_WB_ADDR = WB_ADDR;
assign IO_WB_WE = WB_WE;
assign IO_WB_BITS_ADDR = WB_REQ_BITS_ADDR;

/*
 * julian pavon rivera
 * Module to dump info for step by step execution of torture test
 * This modulee only is used at simulation time using the Verilator Flag
 */
`ifdef VERILATOR
torture_dump_behav torture_dump
(
	.clk		( CLK		),
	.rst		( RST 		),
	.commit_valid	( WB_PC_VALID	),
	.reg_wr_valid	( WB_WE_TO_RF	),
	.PC		( WB_PC		),
	.INST		( WB_INST	),
	.REG_DST	( WB_ADDR_TO_RF	),
	.DATA		( WB_DATA_TO_RF	)
);
`endif

endmodule
