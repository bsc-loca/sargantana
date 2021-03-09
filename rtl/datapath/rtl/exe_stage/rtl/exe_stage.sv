/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : execution.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Victor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */
//`default_nettype none
import drac_pkg::*;
import riscv_pkg::*;

module exe_stage (
    input logic                         clk_i,
    input logic                         rstn_i,
    input logic                         kill_i,
    input logic                         flush_i,

    input logic                         csr_interrupt_i,        // interrupt detected on the csr
    input bus64_t                       csr_interrupt_cause_i,  // which interrupt has been detected

    // INPUTS
    input rr_exe_instr_t                from_rr_i,
    input resp_dcache_cpu_t             resp_dcache_cpu_i,      // Response from dcache interface

    // I/O base space pointer to dcache interface
    input addr_t                        io_base_addr_i,

    input wire                          commit_store_or_amo_i, // Signal to execute stores and atomics in commit

    // OUTPUTS
    output exe_wb_scalar_instr_t        arith_to_wb_o,
    output exe_wb_scalar_instr_t        mem_to_wb_o,
    output exe_cu_t                     exe_cu_o,
    output logic                        mem_commit_stall_o,     // Stall commit stage
    output exception_t                  exception_mem_commit_o, // Exception to commit
    output gl_index_t                   mem_gl_index_o,

    output req_cpu_dcache_t             req_cpu_dcache_o,       // Request to dcache interface 
    output logic                        correct_branch_pred_o,  // Decides if the branch prediction was correct  
    output exe_if_branch_pred_t         exe_if_branch_pred_o,   // Branch prediction (taken, target) and result (take, target)

    //--PMU
    output logic                        pmu_is_branch_o,
    output logic                        pmu_branch_taken_o,                    
    output logic                        pmu_miss_prediction_o,
    output logic                        pmu_stall_mul_o,
    output logic                        pmu_stall_div_o,
    output logic                        pmu_stall_mem_o       
);

// Declarations
bus64_t rs1_data_def;
bus64_t rs2_data_def;

rr_exe_arith_instr_t arith_instr;
rr_exe_mem_instr_t mem_instr;

exe_wb_scalar_instr_t alu_to_wb;

exe_wb_scalar_instr_t mul_to_wb;

exe_wb_scalar_instr_t div_to_wb;

exe_wb_scalar_instr_t branch_to_wb;

exe_wb_scalar_instr_t mem_to_wb;

bus64_t result_mem;
logic stall_mem;
logic stall_int;
logic empty_mem;

logic ready_interface_mem;
bus64_t data_interface_mem;
logic lock_interface_mem;

logic valid_mem_interface;
bus64_t data_rs1_mem_interface;
bus64_t data_rs2_mem_interface;
instr_type_t instr_type_mem_interface;
logic [2:0] mem_size_mem_interface;
reg_t rd_mem_interface;
bus64_t imm_mem_interface;

logic ready;
logic set_mul_32_inst;
logic set_mul_64_inst;
logic set_div_32_inst;
logic set_div_64_inst;
logic ready_1cycle_inst;
logic ready_mul_32_inst; 
logic ready_mul_64_inst;
logic ready_div_32_inst;


// Bypasses
`ifdef ASSERTIONS
    always @(posedge clk_i) begin
        if(from_rr_i.prs1 == 0)
            assert rs1_data_def==0;
        if(from_rr_i.prs2 == 0)
            assert rs2_data_def==0;
    end
`endif

// Select rs2 from imm to avoid bypasses
assign rs1_data_def = from_rr_i.instr.use_pc ? from_rr_i.instr.pc : from_rr_i.data_rs1;
assign rs2_data_def = from_rr_i.instr.use_imm ? from_rr_i.instr.imm : from_rr_i.data_rs2;

score_board score_board_inst(
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_i         (kill_i),
    .set_mul_32_i   (set_mul_32_inst),               
    .set_mul_64_i   (set_mul_64_inst),               
    .set_div_32_i   (set_div_32_inst),               
    .set_div_64_i   (set_div_64_inst),
    .ready_1cycle_o (ready_1cycle_inst),
    .ready_mul_32_o (ready_mul_32_inst),
    .ready_mul_64_o (ready_mul_64_inst),
    .ready_div_32_o (ready_div_32_inst)
);

assign ready = from_rr_i.instr.valid & ( (from_rr_i.rdy1 | from_rr_i.instr.use_pc) & (from_rr_i.rdy2 | from_rr_i.instr.use_imm) );

always_comb begin
    if (~stall_int & ~flush_i) begin
        arith_instr.instr               = from_rr_i.instr;
        arith_instr.data_rs1            = rs1_data_def;
        arith_instr.data_rs2            = rs2_data_def;
        arith_instr.csr_interrupt       = from_rr_i.csr_interrupt;
        arith_instr.csr_interrupt_cause = from_rr_i.csr_interrupt_cause;
        arith_instr.prs1                = from_rr_i.prs1;
        arith_instr.rdy1                = from_rr_i.rdy1;
        arith_instr.prs2                = from_rr_i.prs2;
        arith_instr.rdy2                = from_rr_i.rdy2;
        arith_instr.prd                 = from_rr_i.prd;
        arith_instr.old_prd             = from_rr_i.old_prd;
        arith_instr.checkpoint_done     = from_rr_i.checkpoint_done;
        arith_instr.chkp                = from_rr_i.chkp;
        arith_instr.gl_index            = from_rr_i.gl_index;

        mem_instr.instr               = from_rr_i.instr;
        mem_instr.data_rs1            = rs1_data_def;
        mem_instr.data_rs2            = rs2_data_def;
        mem_instr.csr_interrupt       = from_rr_i.csr_interrupt;
        mem_instr.csr_interrupt_cause = from_rr_i.csr_interrupt_cause;
        mem_instr.prs1                = from_rr_i.prs1;
        mem_instr.rdy1                = from_rr_i.rdy1;
        mem_instr.prs2                = from_rr_i.prs2;
        mem_instr.rdy2                = from_rr_i.rdy2;
        mem_instr.prd                 = from_rr_i.prd;
        mem_instr.old_prd             = from_rr_i.old_prd;
        mem_instr.checkpoint_done     = from_rr_i.checkpoint_done;
        mem_instr.chkp                = from_rr_i.chkp;
        mem_instr.gl_index            = from_rr_i.gl_index;
    end else begin
        arith_instr = 'h0;
        mem_instr   = 'h0;
    end
end

alu alu_inst (
    .instruction_i  (arith_instr),
    .instruction_o  (alu_to_wb)
);

mul_unit mul_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_mul_i     (kill_i),
    .instruction_i  (arith_instr),
    .instruction_o  (mul_to_wb)
);

div_unit div_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_div_i     (kill_i),
    .instruction_i  (arith_instr),
    .instruction_o  (div_to_wb)
);

branch_unit branch_unit_inst (
    .instruction_i      (arith_instr),
    .instruction_o      (branch_to_wb)
);

mem_unit mem_unit_inst(
    .clk_i                  (clk_i),
    .rstn_i                 (rstn_i),
    .io_base_addr_i         (io_base_addr_i),
    .instruction_i          (mem_instr),
    .kill_i                 (kill_i),
    .flush_i                (1'b0),
    .resp_dcache_cpu_i      (resp_dcache_cpu_i),
    .commit_store_or_amo_i  (commit_store_or_amo_i),
    .req_cpu_dcache_o       (req_cpu_dcache_o),
    .instruction_o          (mem_to_wb),
    .exception_mem_commit_o (exception_mem_commit_o),
    .mem_commit_stall_o     (mem_commit_stall_o),
    .mem_gl_index_o         (mem_gl_index_o),
    .lock_o                 (stall_mem),
    .empty_o                (empty_mem)
);

always_comb begin
    if (mem_to_wb.valid) begin
        mem_to_wb_o  = mem_to_wb;
    end else begin
        mem_to_wb_o  = 'h0;
    end
    
    if (alu_to_wb.valid) begin
        arith_to_wb_o = alu_to_wb;
        if (~alu_to_wb.ex.valid & empty_mem & csr_interrupt_i) begin
            arith_to_wb_o.ex.valid = 1;
            arith_to_wb_o.ex.cause = exception_cause_t'(csr_interrupt_cause_i);
            arith_to_wb_o.ex.origin = 64'b0;
        end
    end else if (mul_to_wb.valid) begin
        arith_to_wb_o = mul_to_wb;
        if (~mul_to_wb.ex.valid & empty_mem & csr_interrupt_i) begin
            arith_to_wb_o.ex.valid = 1;
            arith_to_wb_o.ex.cause = exception_cause_t'(csr_interrupt_cause_i);
            arith_to_wb_o.ex.origin = 64'b0;
        end
    end else if (div_to_wb.valid) begin
        arith_to_wb_o = div_to_wb;
        if (~div_to_wb.ex.valid & empty_mem & csr_interrupt_i) begin
            arith_to_wb_o.ex.valid = 1;
            arith_to_wb_o.ex.cause = exception_cause_t'(csr_interrupt_cause_i);
            arith_to_wb_o.ex.origin = 64'b0;
        end
    end else if (branch_to_wb.valid) begin
        arith_to_wb_o = branch_to_wb;
        if (~branch_to_wb.ex.valid & empty_mem & csr_interrupt_i) begin
            arith_to_wb_o.ex.valid = 1;
            arith_to_wb_o.ex.cause = exception_cause_t'(csr_interrupt_cause_i);
            arith_to_wb_o.ex.origin = 64'b0;
        end
    end else begin
        arith_to_wb_o = 'h0;
    end
end

always_comb begin
    stall_int = 1'b0;
    set_div_32_inst = 1'b0;
    set_div_64_inst = 1'b0;
    set_mul_32_inst = 1'b0;
    set_mul_64_inst = 1'b0;
    pmu_stall_mul_o = 1'b0;
    pmu_stall_div_o = 1'b0;
    pmu_stall_mem_o = 1'b0; 
    if (from_rr_i.instr.valid) begin
        if (from_rr_i.instr.unit == UNIT_DIV & from_rr_i.instr.op_32) begin
            stall_int = ~ready | ~ready_div_32_inst;
            pmu_stall_div_o = ~ready | ~ready_div_32_inst;
            set_div_32_inst = ready & ready_div_32_inst;
        end
        else if (from_rr_i.instr.unit == UNIT_DIV & ~from_rr_i.instr.op_32) begin
            stall_int = ~ready;
            pmu_stall_div_o = ~ready;
            set_div_64_inst = ready;
        end
        else if (from_rr_i.instr.unit == UNIT_MUL & from_rr_i.instr.op_32) begin
            stall_int = ~ready | ~ready_mul_32_inst;
            pmu_stall_mul_o = ~ready | ~ready_mul_32_inst;
            set_mul_32_inst = ready & ready_mul_32_inst;
        end
        else if (from_rr_i.instr.unit == UNIT_MUL & ~from_rr_i.instr.op_32) begin
            stall_int = ~ready | ~ready_mul_64_inst;
            pmu_stall_mul_o = ~ready | ~ready_mul_64_inst;
            set_mul_64_inst = ready & ready_mul_64_inst;
        end
        else if ((from_rr_i.instr.unit == UNIT_ALU | from_rr_i.instr.unit == UNIT_BRANCH | from_rr_i.instr.unit == UNIT_SYSTEM))
            stall_int = ~ready | ~ready_1cycle_inst;
        else if (from_rr_i.instr.unit == UNIT_MEM) begin
            stall_int = stall_mem | (~ready);
            pmu_stall_mem_o = stall_mem | (~ready);
        end
    end
end



// Correct prediction
always_comb begin
    if (from_rr_i.instr.instr_type == JAL)begin
        correct_branch_pred_o = 1'b1;
    end else   
    if (from_rr_i.instr.instr_type != BLT && from_rr_i.instr.instr_type != BLTU &&
        from_rr_i.instr.instr_type != BGE && from_rr_i.instr.instr_type != BGEU &&
        from_rr_i.instr.instr_type != BEQ && from_rr_i.instr.instr_type != BNE  &&
        from_rr_i.instr.instr_type != JALR) begin            
        correct_branch_pred_o = 1'b1; // Correct because Decode and Control Unit Already fixed the missprediciton
    end else begin
        if (from_rr_i.instr.bpred.is_branch) begin
            correct_branch_pred_o = (from_rr_i.instr.bpred.decision == branch_to_wb.branch_taken) &&
                                    (from_rr_i.instr.bpred.decision == PRED_NOT_TAKEN ||
                                     from_rr_i.instr.bpred.pred_addr == branch_to_wb.result_pc);
        end else begin
            correct_branch_pred_o = ~branch_to_wb.branch_taken;
        end
    end
end

// Branch predictor required signals
// Program counter at Execution Stage
assign exe_if_branch_pred_o.pc_execution = from_rr_i.instr.pc; 

// Address generated by branch in Execution Stage
assign exe_if_branch_pred_o.branch_addr_result_exe = branch_to_wb.result_pc; 
// Taken or not taken branch result in Execution Stage
assign exe_if_branch_pred_o.branch_taken_result_exe = branch_to_wb.branch_taken == PRED_TAKEN;   
// The instruction in the Execution Stage is a branch
assign exe_if_branch_pred_o.is_branch_exe = (from_rr_i.instr.instr_type == BLT  |
                                             from_rr_i.instr.instr_type == BLTU |
                                             from_rr_i.instr.instr_type == BGE  |
                                             from_rr_i.instr.instr_type == BGEU |
                                             from_rr_i.instr.instr_type == BEQ  |
                                             from_rr_i.instr.instr_type == BNE  |
                                             from_rr_i.instr.instr_type == JAL  |
                                             from_rr_i.instr.instr_type == JALR) &
                                             arith_instr.instr.valid;
                                             

// Data for the Control Unit
assign exe_cu_o.valid_1 = arith_to_wb_o.valid;
assign exe_cu_o.valid_2 = mem_to_wb_o.valid;
assign exe_cu_o.change_pc_ena_1 = arith_to_wb_o.change_pc_ena;
assign exe_cu_o.is_branch = exe_if_branch_pred_o.is_branch_exe;
assign exe_cu_o.branch_taken = arith_to_wb_o.branch_taken;
assign exe_cu_o.checkpoint_done = arith_to_wb_o.checkpoint_done;
assign exe_cu_o.chkp = arith_to_wb_o.chkp;
assign exe_cu_o.gl_index = arith_to_wb_o.gl_index;

assign exe_cu_o.stall = stall_int;


//-PMU 
assign pmu_is_branch_o       = from_rr_i.instr.bpred.is_branch && from_rr_i.instr.valid;
assign pmu_branch_taken_o    = from_rr_i.instr.bpred.is_branch && from_rr_i.instr.bpred.decision && 
                               from_rr_i.instr.valid;
                               
assign pmu_miss_prediction_o = !correct_branch_pred_o;

endmodule
