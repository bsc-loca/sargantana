`include "definitions.v"

module top(
	input 					    CLK,
	input 					    RST,
	input                       SOFT_RST,
	input	`ADDR			    RESET_ADDRESS,
	//--------------------------------------------------------------------------------------------------------------------------
	// CSR INTERFACE
	//--------------------------------------------------------------------------------------------------------------------------
	input    `DATA         CSR_RW_RDATA,
	input                       CSR_CSR_REPLAY,
	input                       CSR_CSR_STALL,
	input                       CSR_XCPT,
	input                       CSR_ERET,
	input    `ADDR              CSR_EVEC,
	input                       CSR_INTERRUPT,
	input    `DATA         CSR_INTERRUPT_CAUSE,

	output   [11:0]             CSR_RW_ADDR,
	output   [2:0]              CSR_RW_CMD,
	output   `DATA         CSR_RW_WDATA,
	output                      CSR_EXCEPTION,
	output                      CSR_RETIRE,
	output   `DATA         CSR_CAUSE,
	output   `ADDR              CSR_PC,
	//--------------------------------------------------------------------------------------------------------------------------
	// I-CACHE INTERFACE
	//--------------------------------------------------------------------------------------------------------------------------
	output 				        ICACHE_INVALIDATE,
	output	[11:0]				ICACHE_REQ_BITS_IDX,
	output					    ICACHE_REQ_BITS_KILL,
	output                      ICACHE_REQ_VALID,
	output	 				    ICACHE_RESP_READY,
	output	[27:0]				TLB_REQ_BITS_VPN,
	output					    TLB_REQ_VALID,

	input 	`CBLOCK           	ICACHE_RESP_BITS_DATABLOCK,
	input						ICACHE_RESP_VALID,
	input						PTWINVALIDATE,
	input						TLB_RESP_MISS,
	input						TLB_RESP_XCPT_IF,
	//--------------------------------------------------------------------------------------------------------------------------
	// D-CACHE  INTERFACE
	//--------------------------------------------------------------------------------------------------------------------------
	output                      DMEM_REQ_VALID,  
	output	 `DATA  		    DMEM_OP_TYPE,
	output   [4:0]              DMEM_REQ_CMD,
	output   `DATA         DMEM_REQ_BITS_DATA,
	output   `ADDR              DMEM_REQ_BITS_ADDR,
	output   [7:0]              DMEM_REQ_BITS_TAG,
	output                      DMEM_REQ_INVALIDATE_LR,
	output                      DMEM_REQ_BITS_KILL,

	input                       DMEM_ORDERED,
	input                       DMEM_REPLAY_NEXT_VALID,
	input                       DMEM_REQ_READY,
	input    `DATA         DMEM_RESP_BITS_DATA,
	input    `DATA         DMEM_RESP_BITS_DATA_SUBW,
	input                       DMEM_RESP_BITS_HAS_DATA,
	input                       DMEM_RESP_BITS_NACK,
	input                       DMEM_RESP_BITS_REPLAY,
	input    [7:0]              DMEM_RESP_BITS_TAG,
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
	output                      io_core_pmu_new_instruction,
	//--------------------------------------------------------------------------------------------------------------------------
	// SEÑALES EXTRAS NECESARIAS PARA CONECTAR AL SOC - NO HACEN NADA, PERO SIN ELLAS EXISTE UN ERROR
	//--------------------------------------------------------------------------------------------------------------------------
	output io_dmem_req_bits_phys,
	input [39:0] io_dmem_resp_bits_addr,
	input [4:0] io_dmem_resp_bits_cmd,
	input [3:0] io_dmem_resp_bits_typ,
	input [63:0] io_dmem_resp_bits_store_data,
	input [7:0] io_dmem_replay_next_bits,
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
	input [4:0] io_fpu_sboard_clra,
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
	output[63:0] io_counter_wb
);

control control(
);

fetch if_stage(
);

register reg_if(
);

decode decode(
);

register reg_id(
);

read_reg read_reg(
);

register reg_rr(
);

execution execution(
);

register reg_ex(
);

write_back write_back(
);

endmodule

