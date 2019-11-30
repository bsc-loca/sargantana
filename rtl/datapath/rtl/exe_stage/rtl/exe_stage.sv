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
import riscv_pkg::*;

module exe_stage (
    input logic             clk_i,
    input logic             rstn_i,
    input logic             kill_i,
    input logic             flush_i,

    input logic             csr_interrupt_i, // interrupt detected on the csr
    input bus64_t           csr_interrupt_cause_i,  // which interrupt has been detected

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
    output logic                     correct_branch_pred_o, // Decides if the branch prediction was correct  
    output exe_if_branch_pred_t      exe_if_branch_pred_o , // Branch prediction (taken, target) and result (take, target)

    //--PMU
    output logic  pmu_is_branch_o       ,
    output logic  pmu_branch_taken_o    ,                    
    output logic  pmu_miss_prediction_o ,
    output logic  pmu_stall_mul_o       ,
    output logic  pmu_stall_div_o       ,
    output logic  pmu_stall_mem_o       
);

// Declarations
bus64_t rs1_data_bypass;
bus64_t rs2_data_bypass;
bus64_t rs1_data_def;
bus64_t rs2_data_def;

bus64_t result_alu;
bus64_t result_mul;
logic stall_mul;
bus64_t result_div;
bus64_t result_rmd;
logic stall_div;

branch_pred_decision_t taken_branch;
addrPC_t result_branch;
addrPC_t linked_pc;

bus64_t result_mem;
logic stall_mem;

logic ready_interface_mem;
bus64_t data_interface_mem;
logic lock_interface_mem;

lsq_interface_t load_store_instruction;
logic valid_mem_interface;
bus64_t data_rs1_mem_interface;
bus64_t data_rs2_mem_interface;
instr_type_t instr_type_mem_interface;
mem_op_t mem_op_mem_interface;
logic [2:0] funct3_mem_interface;
reg_t rd_mem_interface;
bus64_t imm_mem_interface;

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
assign rs2_data_def = from_rr_i.instr.use_imm ? from_rr_i.instr.result : rs2_data_bypass;

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
    .func3_i        (from_rr_i.instr.mem_size),
    .int_32_i       (from_rr_i.instr.op_32),
    .src1_i         (rs1_data_bypass),
    .src2_i         (rs2_data_bypass),

    .result_o       (result_mul),
    .stall_o        (stall_mul)
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
    .stall_o        (stall_div)
);

branch_unit branch_unit_inst (
    .instr_type_i       (from_rr_i.instr.instr_type),
    .pc_i               (from_rr_i.instr.pc),
    .data_rs1_i         (rs1_data_bypass),
    .data_rs2_i         (rs2_data_bypass),
    .imm_i              (from_rr_i.instr.result),

    .taken_o            (taken_branch),
    .result_o           (result_branch),
    .reg_data_o         (reg_data_branch)
);


// Request to DCACHE INTERFACE
assign req_cpu_dcache_o.valid         = (from_rr_i.instr.unit == UNIT_MEM) && from_rr_i.instr.valid;
assign req_cpu_dcache_o.kill          = kill_i;
assign req_cpu_dcache_o.data_rs1      = rs1_data_bypass;
assign req_cpu_dcache_o.data_rs2      = rs2_data_bypass;
assign req_cpu_dcache_o.instr_type    = from_rr_i.instr.instr_type;
assign req_cpu_dcache_o.mem_size      = from_rr_i.instr.mem_size;
assign req_cpu_dcache_o.rd            = from_rr_i.instr.rd;
assign req_cpu_dcache_o.imm           = from_rr_i.instr.result;
assign req_cpu_dcache_o.io_base_addr  = io_base_addr_i;

// RESPONSE FROM DCACHE INTERFACE
assign result_mem   = resp_dcache_cpu_i.data;
assign stall_mem    = resp_dcache_cpu_i.lock;

assign load_store_instruction.valid = (from_rr_i.instr.unit == UNIT_MEM);
assign load_store_instruction.addr = (1'b1) ? rs1_data_bypass : rs1_data_bypass + from_rr_i.instr.imm; // TODO: (from_rr_i.instr.mem_op == MEM_AMO)
assign load_store_instruction.data = rs2_data_bypass;
assign load_store_instruction.instr_type = from_rr_i.instr.instr_type;
assign load_store_instruction.mem_op = from_rr_i.instr.mem_op;
assign load_store_instruction.funct3 = from_rr_i.instr.funct3;
assign load_store_instruction.rd = from_rr_i.instr.rd;


mem_unit mem_unit_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .interface_i(load_store_instruction),
    .kill_i(kill_i),
    .flush_i(flush_i),
    .ready_i(ready_interface_mem),
    .data_i(data_interface_mem),
    .lock_i(lock_interface_mem),
    .valid_o(valid_mem_interface),
    .data_rs1_o(data_rs1_mem_interface),
    .data_rs2_o(data_rs2_mem_interface),
    .instr_type_o(instr_type_mem_interface),
    .mem_op_o(mem_op_mem_interface),
    .funct3_o(funct3_mem_interface),
    .rd_o(rd_mem_interface),
    .imm_o(imm_mem_interface),
    .data_o(result_mem),
    .ls_queue_entry_o(),
    .ready_o(ready_mem),
    .lock_o(stall_mem)
);

//------------------------------------------------------------------------------
// DATA  TO WRITE_BACK
//------------------------------------------------------------------------------

assign to_wb_o.valid = from_rr_i.instr.valid;
assign to_wb_o.pc = from_rr_i.instr.pc;
assign to_wb_o.bpred = from_rr_i.instr.bpred;
assign to_wb_o.rs1 = from_rr_i.instr.rs1;
assign to_wb_o.rd = from_rr_i.instr.rd;
assign to_wb_o.change_pc_ena = from_rr_i.instr.change_pc_ena;
assign to_wb_o.regfile_we = from_rr_i.instr.regfile_we;
assign to_wb_o.instr_type = from_rr_i.instr.instr_type;
assign to_wb_o.stall_csr_fence = from_rr_i.instr.stall_csr_fence;
assign to_wb_o.csr_addr = from_rr_i.instr.result[CSR_ADDR_SIZE-1:0];

`ifdef VERILATOR
assign to_wb_o.inst = from_rr_i.instr.inst;
`endif

always_comb begin
    to_wb_o.ex.cause  = INSTR_ADDR_MISALIGNED;
    to_wb_o.ex.origin = 0;
    to_wb_o.ex.valid  = 0;
    if(from_rr_i.instr.ex.valid) begin // Bypass exception from previous stages
        to_wb_o.ex = from_rr_i.instr.ex;
    end else if(from_rr_i.instr.valid) begin // Check exceptions in exe stage
        //Interrupt comming from csr, if there are a memory operation is better to finish it
        if(from_rr_i.instr.unit != UNIT_MEM && csr_interrupt_i) begin 
            to_wb_o.ex.cause = exception_cause_t'(csr_interrupt_cause_i);
            to_wb_o.ex.origin = 64'b0;
            to_wb_o.ex.valid = 1;
        end else if(resp_dcache_cpu_i.xcpt_ma_st && from_rr_i.instr.unit == UNIT_MEM) begin // Misaligned store
            to_wb_o.ex.cause = ST_AMO_ADDR_MISALIGNED;
            to_wb_o.ex.origin = resp_dcache_cpu_i.addr;
            to_wb_o.ex.valid = 1;
        end else if (resp_dcache_cpu_i.xcpt_ma_ld && from_rr_i.instr.unit == UNIT_MEM) begin // Misaligned load
            to_wb_o.ex.cause = LD_ADDR_MISALIGNED;
            to_wb_o.ex.origin = resp_dcache_cpu_i.addr;
            to_wb_o.ex.valid = 1;
        end else if (resp_dcache_cpu_i.xcpt_pf_st && from_rr_i.instr.unit == UNIT_MEM) begin // Page fault store
            to_wb_o.ex.cause = ST_AMO_PAGE_FAULT;
            to_wb_o.ex.origin = resp_dcache_cpu_i.addr;
            to_wb_o.ex.valid = 1;
        end else if (resp_dcache_cpu_i.xcpt_pf_ld && from_rr_i.instr.unit == UNIT_MEM) begin // Page fault load
            to_wb_o.ex.cause = LD_PAGE_FAULT;
            to_wb_o.ex.origin = resp_dcache_cpu_i.addr;
            to_wb_o.ex.valid = 1;
        end else if (((|resp_dcache_cpu_i.addr[63:40] && !resp_dcache_cpu_i.addr[39]) ||
                      ( !(&resp_dcache_cpu_i.addr[63:40]) && resp_dcache_cpu_i.addr[39] )) &&
                     from_rr_i.instr.unit == UNIT_MEM) begin // invalid address
            case(from_rr_i.instr.instr_type)
                SD, SW, SH, SB, AMO_LRW, AMO_LRD, AMO_SCW, AMO_SCD,
                AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW, AMO_XORW, AMO_MAXW,
                AMO_MAXWU, AMO_MINW, AMO_MINWU, AMO_SWAPD, AMO_ADDD,
                AMO_ANDD, AMO_ORD, AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND, AMO_MINDU: begin
                    to_wb_o.ex.cause = ST_AMO_ACCESS_FAULT;
                    to_wb_o.ex.origin = resp_dcache_cpu_i.addr;
                    to_wb_o.ex.valid = 1;
                end
                LD,LW,LWU,LH,LHU,LB,LBU: begin
                    to_wb_o.ex.cause = LD_ACCESS_FAULT;
                    to_wb_o.ex.origin = resp_dcache_cpu_i.addr;
                    to_wb_o.ex.valid = 1;
                end
                default: begin
                    `ifdef ASSERTIONS
                        assert (1 == 0);
                    `endif
                    to_wb_o.ex.valid = 0;
                end
            endcase
        end else if (result_branch[1:0] != 0 && 
                    from_rr_i.instr.unit == UNIT_BRANCH && 
                    (from_rr_i.instr.instr_type == JALR || 
                    ((from_rr_i.instr.instr_type == BLT || 
                    from_rr_i.instr.instr_type == BLTU || 
                    from_rr_i.instr.instr_type == BGE ||
                    from_rr_i.instr.instr_type == BGEU || 
                    from_rr_i.instr.instr_type == BEQ || 
                    from_rr_i.instr.instr_type == BNE ) &&
                    taken_branch )) &&
                    from_rr_i.instr.valid) begin // invalid address
            to_wb_o.ex.cause = INSTR_ADDR_MISALIGNED;
            to_wb_o.ex.origin = result_branch;
            to_wb_o.ex.valid = 1;
        end
    end 
end


always_comb begin
    to_wb_o.branch_taken = 1'b0;
    case(from_rr_i.instr.unit)
        UNIT_ALU: begin
            to_wb_o.result      = result_alu;
        end
        UNIT_MUL: begin
            to_wb_o.result      = result_mul;
        end
        UNIT_DIV: begin
            case(from_rr_i.instr.instr_type)
                DIV,DIVU,DIVW,DIVUW: begin
                    to_wb_o.result = result_div;
                end
                REM,REMU,REMW,REMUW: begin
                    to_wb_o.result = result_rmd;
                end
                default: begin
                    to_wb_o.result = 0;
                end
            endcase
        end
        UNIT_BRANCH: begin
            to_wb_o.branch_taken    = taken_branch;
            to_wb_o.result          = linked_pc;
        end
        UNIT_MEM: begin
            to_wb_o.result      = result_mem;
        end
        UNIT_SYSTEM: begin
            to_wb_o.result      = rs1_data_bypass;
        end
        default: begin
            to_wb_o.result      = 0;
        end
    endcase
end

// Branch predictor required signals
// Program counter at Execution Stage
assign exe_if_branch_pred_o.pc_execution = from_rr_i.instr.pc; 

    // Correct prediction
    always_comb begin
        if (from_rr_i.instr.instr_type == JAL)begin
            correct_branch_pred_o = 1'b1;
            to_wb_o.result_pc = 0;
        end else   
        if (from_rr_i.instr.instr_type != BLT && from_rr_i.instr.instr_type != BLTU &&
            from_rr_i.instr.instr_type != BGE && from_rr_i.instr.instr_type != BGEU &&
            from_rr_i.instr.instr_type != BEQ && from_rr_i.instr.instr_type != BNE  &&
            from_rr_i.instr.instr_type != JALR) begin            
            correct_branch_pred_o = ((~from_rr_i.instr.bpred.is_branch) | (from_rr_i.instr.bpred.decision == PRED_NOT_TAKEN));
            to_wb_o.result_pc = from_rr_i.instr.pc + 64'h4;
        end else begin
            if (from_rr_i.instr.bpred.is_branch) begin
                correct_branch_pred_o = (from_rr_i.instr.bpred.decision == taken_branch) && (from_rr_i.instr.bpred.decision == PRED_NOT_TAKEN || from_rr_i.instr.bpred.pred_addr == result_branch);
                to_wb_o.result_pc     = result_branch;
            end else begin
                correct_branch_pred_o = ~taken_branch;
                to_wb_o.result_pc     = result_branch;
            end
        end
    end

    // Address generated by branch in Execution Stage
assign exe_if_branch_pred_o.branch_addr_result_exe = result_branch; 
    // Taken or not taken branch result in Execution Stage
assign exe_if_branch_pred_o.branch_taken_result_exe = taken_branch == PRED_TAKEN;   
    // The instruction in the Execution Stage is a branch
assign exe_if_branch_pred_o.is_branch_exe = (from_rr_i.instr.instr_type == BLT  |
                                             from_rr_i.instr.instr_type == BLTU |
                                             from_rr_i.instr.instr_type == BGE  |
                                             from_rr_i.instr.instr_type == BGEU |
                                             from_rr_i.instr.instr_type == BEQ  |
                                             from_rr_i.instr.instr_type == BNE  );

assign stall_o = (from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_MUL) ? stall_mul :
                 (from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_DIV) ? stall_div :
                 (from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_MEM) ? stall_mem :
                 0;


//-PMU 
assign pmu_is_branch_o       = from_rr_i.instr.bpred.is_branch && from_rr_i.instr.valid;
assign pmu_branch_taken_o    = from_rr_i.instr.bpred.is_branch && from_rr_i.instr.bpred.decision && 
                               from_rr_i.instr.valid            ;
assign pmu_miss_prediction_o = !correct_branch_pred_o;

assign pmu_stall_mul_o = from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_MUL & stall_mul;
assign pmu_stall_div_o = from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_DIV & stall_div;
assign pmu_stall_mem_o = from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_MEM & stall_mem; 


endmodule

