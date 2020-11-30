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

    input logic                         csr_interrupt_i, // interrupt detected on the csr
    input bus64_t                       csr_interrupt_cause_i,  // which interrupt has been detected

    // INPUTS
    input rr_exe_instr_t                from_rr_i,
    input resp_dcache_cpu_t             resp_dcache_cpu_i, // Response from dcache interface

    // I/O base space pointer to dcache interface
    input addr_t                        io_base_addr_i,

    input wire                          commit_store_or_amo_i, // Signal to execute stores and atomics in commit

    // OUTPUTS
    output exe_wb_instr_t               alu_mul_div_to_wb_o,
    output exe_wb_instr_t               mem_to_wb_o,
    output logic                        stall_o,
    output logic                        mem_commit_stall_o, // Stall commit stage
    output exception_t                  exception_mem_commit_o, // Exception to commit

    output req_cpu_dcache_t             req_cpu_dcache_o, // Request to dcache interface 
    output logic                        correct_branch_pred_o, // Decides if the branch prediction was correct  
    output exe_if_branch_pred_t         exe_if_branch_pred_o, // Branch prediction (taken, target) and result (take, target)

    //--PMU
    output logic  pmu_is_branch_o       ,
    output logic  pmu_branch_taken_o    ,                    
    output logic  pmu_miss_prediction_o ,
    output logic  pmu_stall_mul_o       ,
    output logic  pmu_stall_div_o       ,
    output logic  pmu_stall_mem_o       
);

// Declarations
bus64_t rs1_data_def;
bus64_t rs2_data_def;

exe_wb_instr_t alu_to_wb;

exe_wb_instr_t mul_to_wb;

exe_wb_instr_t div_to_wb;

exe_wb_instr_t branch_to_wb;

exe_wb_instr_t mem_to_wb;

bus64_t result_mem;
logic stall_mem;

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

rr_exe_instr_t instruction_to_functional_unit;
logic ready;
logic set_mul_64_inst;
logic set_div_32_inst;
logic set_div_64_inst;
logic ready_1cycle_inst;
logic ready_mul_64_inst;
logic ready_div_32_inst;
logic ready_div_64_inst; 

// Bypasses
`ifdef ASSERTIONS
    always @(posedge clk_i) begin
        if(from_rr_i.prs1 == 0)
            assert rs1_data_bypass==0;
        if(from_rr_i.prs2 == 0)
            assert rs2_data_bypass==0;
    end
`endif

// Select rs2 from imm to avoid bypasses
assign rs1_data_def = from_rr_i.instr.use_pc ? from_rr_i.instr.pc : from_rr_i.data_rs1;
assign rs2_data_def = from_rr_i.instr.use_imm ? from_rr_i.instr.result : from_rr_i.data_rs2;

score_board score_board_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .kill_i(kill_i),
    .set_mul_64_i(set_mul_64_inst),               
    .set_div_32_i(set_div_32_inst),               
    .set_div_64_i(set_div_64_inst),       
    .ready_1cycle_o(ready_1cycle_inst),             
    .ready_mul_64_o(ready_mul_64_inst),             
    .ready_div_32_o(ready_div_32_inst),             
    .ready_div_64_o(ready_div_64_inst)
);

assign ready = from_rr_i.instr.valid & ( (from_rr_i.rdy1 | from_rr_i.instr.use_pc) & (from_rr_i.rdy2 | from_rr_i.instr.use_imm) );

always_comb begin
    if (~stall_o & ~flush_i)
        instruction_to_functional_unit = from_rr_i;
    else
        instruction_to_functional_unit = 'h0;
end

alu alu_inst (
    .data_rs1_i     (rs1_data_def),
    .data_rs2_i     (rs2_data_def),
    .instruction_i  (instruction_to_functional_unit),
    .instruction_o  (alu_to_wb)
);

mul_unit mul_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_mul_i     (kill_i),
    .instruction_i  (instruction_to_functional_unit),
    .data_src1_i    (rs1_data_def),
    .data_src2_i    (rs2_data_def),
    .instruction_o  (mul_to_wb)
);

div_unit div_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_div_i     (kill_i),
    .instruction_i  (instruction_to_functional_unit),
    .data_src1_i    (rs1_data_def),
    .data_src2_i    (rs2_data_def),
    .instruction_o  (div_to_wb)
);

branch_unit branch_unit_inst (
    .instruction_i      (instruction_to_functional_unit),
    .data_rs1_i         (rs1_data_def),
    .data_rs2_i         (rs2_data_def),
    .instruction_o      (branch_to_wb)
);

mem_unit mem_unit_inst(
    .clk_i                  (clk_i),
    .rstn_i                 (rstn_i),
    .io_base_addr_i         (io_base_addr_i),
    .instruction_i          (instruction_to_functional_unit),
    .data_rs1_i             (rs1_data_def),
    .data_rs2_i             (rs2_data_def),
    .kill_i                 (kill_i),
    .flush_i                (1'b0),
    .resp_dcache_cpu_i      (resp_dcache_cpu_i),
    .commit_store_or_amo_i  (commit_store_or_amo_i),
    .req_cpu_dcache_o       (req_cpu_dcache_o),
    .instruction_o          (mem_to_wb),
    .exception_mem_commit_o (exception_mem_commit_o),
    .mem_commit_stall_o     (mem_commit_stall_o),
    .lock_o                 (stall_mem)
);

// Request to DCACHE INTERFACE
assign req_cpu_dcache_o.kill          = kill_i;
assign req_cpu_dcache_o.io_base_addr  = io_base_addr_i;

always_comb begin
    if (mem_to_wb.valid)
        mem_to_wb_o  = mem_to_wb;
    else
        mem_to_wb_o  = 'h0;

    if (alu_to_wb.valid)
        alu_mul_div_to_wb_o = alu_to_wb;
    else if (mul_to_wb.valid)
        alu_mul_div_to_wb_o = mul_to_wb;
    else if (div_to_wb.valid)
        alu_mul_div_to_wb_o = div_to_wb;
    else if (branch_to_wb.valid)
        alu_mul_div_to_wb_o = branch_to_wb;
    else
        alu_mul_div_to_wb_o = 'h0;
end

always_comb begin
    stall_o = 1'b0;
    set_div_32_inst = 1'b0;
    set_div_64_inst = 1'b0;
    set_mul_64_inst = 1'b0;
    if (from_rr_i.instr.valid) begin
        if (from_rr_i.instr.unit == UNIT_DIV & from_rr_i.instr.op_32) begin
            stall_o = ~ready | ~ready_div_32_inst;
            set_div_32_inst = ready & ready_div_32_inst;
        end
        else if (from_rr_i.instr.unit == UNIT_DIV & ~from_rr_i.instr.op_32) begin
            stall_o = ~ready | ~ready_div_64_inst;
            set_div_64_inst = ready & ready_div_64_inst;
        end
        else if (from_rr_i.instr.unit == UNIT_MUL & from_rr_i.instr.op_32) 
            stall_o = ~ready | ~ready_1cycle_inst;
        else if (from_rr_i.instr.unit == UNIT_MUL & ~from_rr_i.instr.op_32) begin
            stall_o = ~ready | ~ready_mul_64_inst;
            set_mul_64_inst = ready & ready_mul_64_inst;
        end
        else if ((from_rr_i.instr.unit == UNIT_ALU | from_rr_i.instr.unit == UNIT_BRANCH | from_rr_i.instr.unit == UNIT_SYSTEM))
            stall_o = ~ready | ~ready_1cycle_inst;
        else if (from_rr_i.instr.unit == UNIT_MEM)
            stall_o = stall_mem | (~ready);
    end
end

// Branch predictor required signals
// Program counter at Execution Stage
assign exe_if_branch_pred_o.pc_execution = from_rr_i.instr.pc; 

    // Correct prediction
    always_comb begin
        if (from_rr_i.instr.instr_type == JAL)begin
            correct_branch_pred_o = 1'b1;
            to_wb_o.result_pc = 1'b0;
        end else   
        if (from_rr_i.instr.instr_type != BLT && from_rr_i.instr.instr_type != BLTU &&
            from_rr_i.instr.instr_type != BGE && from_rr_i.instr.instr_type != BGEU &&
            from_rr_i.instr.instr_type != BEQ && from_rr_i.instr.instr_type != BNE  &&
            from_rr_i.instr.instr_type != JALR) begin            
            correct_branch_pred_o = ((~from_rr_i.instr.bpred.is_branch) | (from_rr_i.instr.bpred.decision == PRED_NOT_TAKEN));
            to_wb_o.result_pc = from_rr_i.instr.pc + 64'h4;
        end else begin
            if (from_rr_i.instr.bpred.is_branch) begin
                correct_branch_pred_o = (from_rr_i.instr.bpred.decision == branch_to_wb.branch_taken) &&
                                        (from_rr_i.instr.bpred.decision == PRED_NOT_TAKEN ||
                                         from_rr_i.instr.bpred.pred_addr == branch_to_wb.result_pc);
                to_wb_o.result_pc     = branch_to_wb.result_pc;
            end else begin
                correct_branch_pred_o = ~branch_to_wb.branch_taken;
                to_wb_o.result_pc     = branch_to_wb.result_pc;
            end
        end
    end

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
                                             from_rr_i.instr.instr_type == BNE  );


//-PMU 
assign pmu_is_branch_o       = from_rr_i.instr.bpred.is_branch && from_rr_i.instr.valid;
assign pmu_branch_taken_o    = from_rr_i.instr.bpred.is_branch && from_rr_i.instr.bpred.decision && 
                               from_rr_i.instr.valid            ;
assign pmu_miss_prediction_o = !correct_branch_pred_o;

assign pmu_stall_mul_o = from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_MUL & stall_mul;
assign pmu_stall_div_o = from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_DIV & stall_div;
assign pmu_stall_mem_o = from_rr_i.instr.valid & from_rr_i.instr.unit == UNIT_MEM & stall_mem; 

endmodule

