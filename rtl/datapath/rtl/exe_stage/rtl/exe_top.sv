/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : execution.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Victor SP | Remove dcache interface
 * -----------------------------------------------
 */
//`default_nettype none
import drac_pkg::*;

module exe_top (
    input logic             clk_i,
    input logic             rstn_i,
    input logic             kill_i,
    input logic             csr_eret_i,

    // INPUTS
    input rr_exe_instr_t    from_rr_i,
    input wb_exe_instr_t    from_wb_i,
    input resp_dcache_cpu_t resp_dcache_cpu_i, // Response from dcache interface

    // I/O base space pointer to dcache interface
    input addr_t            io_base_addr_i,

    // OUTPUTS
    output exe_wb_instr_t   to_wb_o,
    output logic            stall_o,

    output req_cpu_dcache_t req_cpu_dcache_o, // Request to dcache interface 

    output logic            dmem_lock_o // TODO connect
);

// Declarations
bus64_t rs1_data_bypass;
bus64_t rs2_data_bypass;
bus64_t rs1_data_def;
bus64_t rs2_data_def;

bus64_t result_alu;
bus64_t result_mul;
logic stall_mul;
logic ready_mul;
bus64_t result_div;
bus64_t result_rmd;
logic stall_div;
logic ready_div;

logic taken_branch;
addrPC_t target_branch;
addrPC_t result_branch;
bus64_t reg_data_branch;

logic ready_mem;
bus64_t result_mem;
logic stall_mem;



// Bypasses
`ifdef ASSERTIONS
    always @(posedge clk_i) begin
        if(from_rr_i.instr.rs1 == 0)
            assert rs1_data_bypass==0;
        if(from_rr_i.instr.rs2 == 0)
            assert rs2_data_bypass==0;
    end
`endif

assign rs1_data_bypass = ((from_rr_i.instr.rs1 != 0) & (from_rr_i.instr.rs1 == from_wb_i.rd) & from_wb_i.valid) ? from_wb_i.data : from_rr_i.data_rs1;
assign rs2_data_bypass = ((from_rr_i.instr.rs2 != 0) & (from_rr_i.instr.rs2 == from_wb_i.rd) & from_wb_i.valid) ? from_wb_i.data : from_rr_i.data_rs2;

// Select rs2 from imm to avoid bypasses
assign rs1_data_def = from_rr_i.instr.use_pc ? from_rr_i.instr.pc : rs1_data_bypass;
assign rs2_data_def = from_rr_i.instr.use_imm ? from_rr_i.instr.imm : rs2_data_bypass;

alu alu_inst (
    .data_rs1_i     (rs1_data_def),
    .data_rs2_i     (rs2_data_def),
    .instr_type_i   (from_rr_i.instr.instr_type),
    .result_o       (result_alu)
);

mul_unit mul_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_mul_i     (kill_i),
    .request_i      (from_rr_i.instr.unit == UNIT_MUL),
    .func3_i        (from_rr_i.instr.funct3),
    .int_32_i       (from_rr_i.instr.op_32),
    .src1_i         (rs1_data_bypass),
    .src2_i         (rs2_data_bypass),

    .result_o       (result_mul),
    .stall_o        (stall_mul),
    .done_tick_o    (ready_mul)
);

div_unit div_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_div_i     (kill_i),
    .request_i      (from_rr_i.instr.unit == UNIT_DIV),
    .int_32_i       (from_rr_i.instr.op_32),
    .signed_op_i    (from_rr_i.instr.signed_op),
    .dvnd_i         (rs1_data_bypass),
    .dvsr_i         (rs2_data_def),

    .quo_o          (result_div),
    .rmd_o          (result_rmd),
    .stall_o        (stall_div),
    .done_tick_o    (ready_div)
);

branch_unit branch_unit_inst (
    .instr_type_i       (from_rr_i.instr.instr_type),
    .pc_i               (from_rr_i.instr.pc),
    .data_rs1_i         (rs1_data_bypass),
    .data_rs2_i         (rs2_data_bypass),
    .imm_i              (from_rr_i.instr.imm),

    .taken_o            (taken_branch),
    .target_o           (target_branch),
    .result_o           (result_branch),
    .reg_data_o         (reg_data_branch)
);

// Request to DCACHE INTERFACE
assign req_cpu_dcache_o.valid         = from_rr_i.instr.unit == UNIT_MEM;
assign req_cpu_dcache_o.kill          = kill_i;
assign req_cpu_dcache_o.csr_eret      = csr_eret_i;
assign req_cpu_dcache_o.data_rs1      = rs1_data_bypass;
assign req_cpu_dcache_o.data_rs2      = rs2_data_bypass;
assign req_cpu_dcache_o.instr_type    = from_rr_i.instr.instr_type;
assign req_cpu_dcache_o.mem_op        = from_rr_i.instr.mem_op;
assign req_cpu_dcache_o.funct3        = from_rr_i.instr.funct3;
assign req_cpu_dcache_o.rd            = from_rr_i.instr.rd;
assign req_cpu_dcache_o.imm           = from_rr_i.instr.imm;
assign req_cpu_dcache_o.io_base_addr  = io_base_addr_i;

// RESPONSE FROM DCACHE INTERFACE
assign ready_mem    = resp_dcache_cpu_i.ready;  
assign result_mem   = resp_dcache_cpu_i.data;
assign stall_mem    = resp_dcache_cpu_i.lock;


//------------------------------------------------------------------------------
// DATA  TO WRITE_BACK
//------------------------------------------------------------------------------

assign to_wb_o.instr.valid = from_rr_i.instr.valid;
assign to_wb_o.instr.pc = from_rr_i.instr.pc;
assign to_wb_o.instr.bpred = from_rr_i.instr.bpred;
assign to_wb_o.instr.rs1 = from_rr_i.instr.rs1;
assign to_wb_o.instr.rs2 = from_rr_i.instr.rs2;
assign to_wb_o.instr.rd = from_rr_i.instr.rd;
assign to_wb_o.instr.use_imm = from_rr_i.instr.use_imm;
assign to_wb_o.instr.use_pc = from_rr_i.instr.use_pc;
assign to_wb_o.instr.op_32 = from_rr_i.instr.op_32;
assign to_wb_o.instr.alu_op = from_rr_i.instr.alu_op;
assign to_wb_o.instr.unit = from_rr_i.instr.unit;
assign to_wb_o.instr.change_pc_ena = from_rr_i.instr.change_pc_ena;
assign to_wb_o.instr.regfile_we = from_rr_i.instr.regfile_we;
assign to_wb_o.instr.regfile_w_sel = from_rr_i.instr.regfile_w_sel;
assign to_wb_o.instr.instr_type = from_rr_i.instr.instr_type;
assign to_wb_o.instr.result = from_rr_i.instr.result;
assign to_wb_o.instr.mem_op = from_rr_i.instr.mem_op;
assign to_wb_o.instr.signed_op = from_rr_i.instr.signed_op;
assign to_wb_o.instr.funct3 = from_rr_i.instr.funct3;
assign to_wb_o.instr.imm = from_rr_i.instr.imm;
assign to_wb_o.instr.aq = from_rr_i.instr.aq;
assign to_wb_o.instr.rl = from_rr_i.instr.rl;
assign to_wb_o.instr.stall_csr = from_rr_i.instr.stall_csr;

always_comb begin
    if(from_rr_i.instr.ex.valid) begin // Bypass exception from previous stages
        to_wb_o.instr.ex = from_rr_i.instr.ex;
    end else if(from_rr_i.instr.valid) begin // Check exceptions in exe stage
        if(resp_dcache_cpu_i.xcpt_ma_st) begin // Misaligned store
            to_wb_o.instr.ex.cause = ST_AMO_ADDR_MISALIGNED;
            to_wb_o.instr.ex.origin = resp_dcache_cpu_i.addr;
            to_wb_o.instr.ex.valid = 1;
        end else if (resp_dcache_cpu_i.xcpt_ma_ld) begin // Misaligned load
            to_wb_o.instr.ex.cause = LD_ADDR_MISALIGNED;
            to_wb_o.instr.ex.origin = resp_dcache_cpu_i.addr;
            to_wb_o.instr.ex.valid = 1;
        end else if (resp_dcache_cpu_i.xcpt_pf_st) begin // Page fault store
            to_wb_o.instr.ex.cause = ST_AMO_PAGE_FAULT;
            to_wb_o.instr.ex.origin = resp_dcache_cpu_i.addr;
            to_wb_o.instr.ex.valid = 1;
        end else if (resp_dcache_cpu_i.xcpt_pf_ld) begin // Page fault load
            to_wb_o.instr.ex.cause = LD_PAGE_FAULT;
            to_wb_o.instr.ex.origin = resp_dcache_cpu_i.addr;
            to_wb_o.instr.ex.valid = 1;
        end else if (resp_dcache_cpu_i.addr[63:40] != 0 && from_rr_i.instr.unit == UNIT_MEM) begin // invalid address
            case(from_rr_i.instr.instr_type)
                SD, SW, SH, SB, AMO_LRW, AMO_LRD, AMO_SCW, AMO_SCD,
                AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW, AMO_XORW, AMO_MAXW,
                AMO_MAXWU, AMO_MINW, AMO_MINWU, AMO_SWAPD, AMO_ADDD,
                AMO_ANDD, AMO_ORD, AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND, AMO_MINDU: begin
                    to_wb_o.instr.ex.cause = ST_AMO_ACCESS_FAULT;
                    to_wb_o.instr.ex.origin = resp_dcache_cpu_i.addr;
                    to_wb_o.instr.ex.valid = 1;
                end
                LD,LW,LWU,LH,LHU,LB,LBU: begin
                    to_wb_o.instr.ex.cause = LD_ACCESS_FAULT;
                    to_wb_o.instr.ex.origin = resp_dcache_cpu_i.addr;
                    to_wb_o.instr.ex.valid = 1;
                end
                default: begin
                    to_wb_o.instr.ex.cause = 0;
                    to_wb_o.instr.ex.origin = 0;
                    to_wb_o.instr.ex.valid = 0;
                end
            endcase
        end else if (result_branch[1:0] != 0 && from_rr_i.instr.unit == UNIT_BRANCH && from_rr_i.instr.instr_type == JALR && from_rr_i.instr.valid) begin // invalid address
                    to_wb_o.instr.ex.cause = INSTR_ADDR_MISALIGNED;
                    to_wb_o.instr.ex.origin = result_branch;
                    to_wb_o.instr.ex.valid = 1;
        end else begin
            to_wb_o.instr.ex.cause = 0;
            to_wb_o.instr.ex.origin = 0;
            to_wb_o.instr.ex.valid = 0;
        end
    end else begin
        to_wb_o.instr.ex.cause = 0;
        to_wb_o.instr.ex.origin = 0;
        to_wb_o.instr.ex.valid = 0;
    end
end


always_comb begin
    to_wb_o.branch_taken = 1'b0;
    case(from_rr_i.instr.unit)
        UNIT_ALU: begin
            to_wb_o.result_rd = result_alu;
            to_wb_o.result_pc = 0;

        end
        UNIT_MUL: begin
            to_wb_o.result_rd = result_mul;
            to_wb_o.result_pc = 0;
        end
        UNIT_DIV: begin
            case(from_rr_i.instr.instr_type)
                DIV,DIVU,DIVW,DIVUW: begin
                    to_wb_o.result_rd = result_div;
                end
                REM,REMU,REMW,REMUW: begin
                    to_wb_o.result_rd = result_rmd;
                end
                default: begin
                    to_wb_o.result_rd = 0;
                end
            endcase
            to_wb_o.result_pc = 0;
        end
        UNIT_BRANCH: begin
            to_wb_o.result_rd = reg_data_branch;
            to_wb_o.result_pc = result_branch;
            to_wb_o.branch_taken = taken_branch;
        end
        UNIT_MEM: begin
            to_wb_o.result_rd = result_mem;
            to_wb_o.result_pc = 0;
        end
        UNIT_SYSTEM: begin
            to_wb_o.result_rd = rs1_data_bypass;
            to_wb_o.result_pc = 0;
        end
        default: begin
            to_wb_o.result_rd = 0;
            to_wb_o.result_pc = 0;
        end
    endcase
end

assign to_wb_o.rd = from_rr_i.instr.rd;
assign stall_o = (from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_MUL) ? stall_mul :
                 (from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_DIV) ? stall_div :
                 (from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_MEM) ? stall_mem :
                 0;

endmodule

