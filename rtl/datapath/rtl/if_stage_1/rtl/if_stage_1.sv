/* -----------------------------------------------
* Project Name   : DRAC
* File           : if_stage_1.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
*  0.2        | Max Doblas | Divide the fetch stage in two
* -----------------------------------------------
*/
//`default_nettype none

module if_stage_1
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic                 clk_i,
    input logic                 rstn_i,
    input addr_t                reset_addr_i,

    // Signals from debug
    //input addr_t                deb_change_pc_addr_i,
    
    // Signals from Control Unit
    input logic                 stall_i,
    input logic                 stall_debug_i,
    input cu_if_t               cu_if_i,
    // Signals to invalidate buffer/icache
    // from control unit
    input logic                 invalidate_icache_i,
    input logic                 invalidate_buffer_i,
    input logic                 en_translation_i,
    // PC comming from commit/decode/ecall/debug
    input addrPC_t              pc_jump_i,
    // Signals for branch predictor from exe stage 
    input exe_if_branch_pred_t  exe_if_branch_pred_i,
    // Retry requesto to icache
    input logic                 retry_fetch_i,
    // Request packet going from Icache
    output req_cpu_icache_t     req_cpu_icache_o,  
    // fetch data output
    output if_1_if_2_stage_t    fetch_o
    `ifdef SIM_KONATA_DUMP
    ,
    output logic[63:0]          id_o
    `endif
);
    // next pc logic
    addrPC_t next_pc;
//    regPC_t pc;
    reg[63:0] pc;
    `ifdef SIM_KONATA_DUMP
    logic[63:0] id, next_id;
    `endif

    // Exceptions
    // misalgined is checked here while the others 
    // on icache interface or icache itself
    logic ex_addr_misaligned_int;
    logic ex_if_addr_fault_int;

    // Branch Predictor wires
    logic       branch_predict_is_branch;
    logic       branch_predict_taken;
    addrPC_t    branch_predict_addr;


    logic is_in_dram, is_in_rom, is_in_deb, is_inside_exeregion ;

    always_comb begin
        priority case (cu_if_i.next_pc)
            NEXT_PC_SEL_KEEP_PC: begin
                next_pc = pc;
                `ifdef SIM_KONATA_DUMP
                next_id = id;
                `endif
            end
            NEXT_PC_SEL_BP_OR_PC_4: begin 
                if (branch_predict_is_branch && branch_predict_taken) 
                    next_pc = branch_predict_addr;
                else
                    next_pc = pc + 64'h04;
                
                `ifdef SIM_KONATA_DUMP
                next_id = id + 64'h01;
                `endif
            end
            NEXT_PC_SEL_JUMP,
            NEXT_PC_SEL_DEBUG: begin
                next_pc = pc_jump_i;
                `ifdef SIM_KONATA_DUMP
                next_id = id + 64'h01;
                `endif
            end
            default: begin
                `ifdef VERIFICATION
                    $error("next pc not defined error in if stage");
                `endif
                next_pc = pc + 64'h04;
                `ifdef SIM_KONATA_DUMP
                next_id = id + 64'h01;
                `endif
            end
        endcase
    end

    // PC output is the next_pc after a latch
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (!rstn_i) begin
            pc <= {24'b0,reset_addr_i};
            `ifdef SIM_KONATA_DUMP
            id <= 64'h0;
            `endif
        end else begin
            pc <= next_pc;
            `ifdef SIM_KONATA_DUMP
            id <= next_id;
            `endif
        end
    end

    assign is_in_dram = (pc >= _DRAM_BASE_) & (pc < _DRAM_END_);
    assign is_in_rom  = (pc >= _ROM_BASE_) & (pc < _ROM_END_);
    assign is_in_deb  = (pc >= _DEB_BASE_) & (pc < _DEB_END_); 
    assign is_inside_exeregion = is_in_dram | is_in_rom | is_in_deb ; 

    // check addr fault fetch
    always_comb begin
        if ((!((&pc[63:VIRT_ADDR_SIZE-1])==1'b1 | (|pc[63:VIRT_ADDR_SIZE-1])==1'b0) & en_translation_i) | 
            (!is_inside_exeregion & !en_translation_i)
           ) ex_if_addr_fault_int = 1'b1;
        else ex_if_addr_fault_int = 1'b0;
    end
    
    // check misaligned fetch
    always_comb begin
        if (|pc[1:0]) begin
            ex_addr_misaligned_int = 1'b1;
        end else begin
            ex_addr_misaligned_int = 1'b0;
        end
    end

    // logic for icache access: if not misaligned 
    assign req_cpu_icache_o.valid = !ex_addr_misaligned_int && !ex_if_addr_fault_int && !stall_debug_i && !stall_i;
    assign req_cpu_icache_o.vaddr = pc[PHY_VIRT_MAX_ADDR_SIZE-1:0];
    assign req_cpu_icache_o.invalidate_icache = invalidate_icache_i;
    assign req_cpu_icache_o.invalidate_buffer = invalidate_buffer_i | retry_fetch_i;
    assign req_cpu_icache_o.inval_fetch = /*inval_fetch_i |*/ retry_fetch_i;
    
    // Output fetch
    assign fetch_o.pc_inst = pc;
    assign fetch_o.valid   = !stall_debug_i && !stall_i;  // valid if the response of the cache is valid or xcpt
    `ifdef SIM_KONATA_DUMP
    assign fetch_o.id = id;
    `endif

    // Branch predictor and RAS
    branch_predictor brach_predictor_inst (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .pc_fetch_i(pc),
        .pc_execution_i(exe_if_branch_pred_i.pc_execution),
        .branch_addr_result_exec_i(exe_if_branch_pred_i.branch_addr_result_exe),
        .branch_taken_result_exec_i(exe_if_branch_pred_i.branch_taken_result_exe),
        .is_branch_EX_i(exe_if_branch_pred_i.is_branch_exe),
        .branch_predict_is_branch_o(branch_predict_is_branch),
        .branch_predict_taken_o(branch_predict_taken),
        .branch_predict_addr_o(branch_predict_addr)
    );

    // exceptions ordering
    always_comb begin
        if (ex_addr_misaligned_int) begin
            fetch_o.ex.cause = INSTR_ADDR_MISALIGNED;
            fetch_o.ex.valid = 1'b1;
        end else 
        if (ex_if_addr_fault_int) begin
            fetch_o.ex.cause = INSTR_ACCESS_FAULT;
            fetch_o.ex.valid = 1'b1;
        end else begin
            fetch_o.ex.cause = INSTR_ADDR_MISALIGNED;
            fetch_o.ex.valid = 1'b0;
        end
    end

    assign fetch_o.ex.origin = pc;
   
    // Pipeline branch prediction to exe stage
    assign fetch_o.bpred.is_branch = branch_predict_is_branch;
    assign fetch_o.bpred.decision  = (branch_predict_taken & branch_predict_is_branch)? PRED_TAKEN : PRED_NOT_TAKEN;
    assign fetch_o.bpred.pred_addr = branch_predict_addr;
    `ifdef SIM_KONATA_DUMP
    assign id_o = id;
    `endif

endmodule
`default_nettype wire
