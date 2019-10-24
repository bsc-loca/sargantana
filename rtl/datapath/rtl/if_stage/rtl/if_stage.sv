/* -----------------------------------------------
* Project Name   : DRAC
* File           : if_stage.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

import drac_pkg::*;

module if_stage(
    input logic                 clk_i,
    input logic                 rstn_i,
    
    input logic                 stall_i,
    // which pc to select
    input next_pc_sel_t         next_pc_sel_i,
    // PC comming from commit
    input addrPC_t              pc_commit_i,
    // Request packet coming from Icache
    input req_icache_cpu_t      req_icache_cpu_i,
    // Request packet going from Icache
    output req_cpu_icache_t     req_cpu_icache_o,
    // fetch data output
    output if_id_stage_t        fetch_o
);

    addrPC_t next_pc;
    regPC_t pc;
    logic ex_misaligned_if_int;
    logic ex_if_addr_fault_int;

    always_comb begin
        priority case (next_pc_sel_i)
            NEXT_PC_SEL_PC:
                next_pc = pc;
            NEXT_PC_SEL_PC_4:
                next_pc = pc + 64'h04;
            NEXT_PC_SEL_COMMIT:
                next_pc = pc_commit_i;
        endcase
    end

    // PC output is the next_pc after a latch
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (!rstn_i) begin
            pc <= 'h00000100;
        end else begin
            pc <= next_pc;
        end
    end

    // check addr fault fetch
    always_comb begin
        // or of the high part of the addr
        if (|pc[63:40]) begin
            ex_if_addr_fault_int = 1'b1;
        end else begin
            ex_if_addr_fault_int = 1'b0;
        end
    end
    // check mislaigned fetch
    always_comb begin
        if (!pc[1:0]) begin
            ex_misaligned_if_int = 1'b1;
        end else begin
            ex_misaligned_if_int = 1'b0;
        end
    end

    // logic for icache access
    assign req_cpu_icache_o.valid = !ex_misaligned_if_int & !ex_if_addr_fault_int;
    assign req_cpu_icache_o.vaddr = pc[39:0];

    // logic branch predictor

    assign fetch_o.pc_inst = pc;
    assign fetch_o.inst = req_icache_cpu_i.data; // TODO: add logic of getting the block
    assign fetch_o.valid = req_icache_cpu_i.valid;
    assign fetch_o.bpred.decision = PRED_NOT_TAKEN; // TODO: add bpred
    assign fetch_o.bpred.pred_addr = 64'b0; // TODO: add bpred 

    // TODO add the correct fault order
    assign fetch_o.ex.cause = MISALIGNED_FETCH;
    assign fetch_o.ex.origin = pc;
    assign fetch_o.ex.valid = ex_misaligned_if_int;

endmodule