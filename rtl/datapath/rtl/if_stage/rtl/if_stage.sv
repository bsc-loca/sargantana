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
import riscv_pkg::*;

module if_stage(
    input logic                 clk_i,
    input logic                 rstn_i,
    
    input logic                 stall_i,
    // which pc to select
    input next_pc_sel_t         next_pc_sel_i,
    // PC comming from commit/decode/ecall
    input addrPC_t              pc_jump_i,
    // Request packet coming from Icache
    input req_icache_cpu_t      req_icache_cpu_i,
    // Request packet going from Icache
    output req_cpu_icache_t     req_cpu_icache_o,
    // fetch data output
    output if_id_stage_t        fetch_o
);
    // next pc logic
    addrPC_t next_pc;
    regPC_t pc;

    // exceptions
    logic ex_addr_misaligned_int;
    logic ex_if_addr_fault_int;
    logic ex_if_page_fault_int;

    always_comb begin
        priority case (next_pc_sel_i)
            NEXT_PC_SEL_PC:
                next_pc = pc;
            NEXT_PC_SEL_PC_4:
                next_pc = pc + 64'h04;
            NEXT_PC_SEL_JUMP:
                next_pc = pc_jump_i;
            default: begin
                $error("next pc not defined error in if stage");
                next_pc = pc + 64'h04;
            end
        endcase
    end

    // PC output is the next_pc after a latch
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (!rstn_i) begin
            pc <= 'h00000200;
        end else begin
            pc <= next_pc;
        end
    end

    // check addr fault fetch
    always_comb begin
        // or of the high part of the addr
        if (|pc[63:40]) begin
            ex_if_addr_fault_int = 1'b1;
        end else if (req_icache_cpu_i.valid && 
            req_icache_cpu_i.instr_access_fault) begin
            ex_if_addr_fault_int = 1'b1;
        end else begin
            ex_if_addr_fault_int = 1'b0;
        end
    end
    // check misaligned fetch
    always_comb begin
        if (|pc[1:0]) begin
            ex_addr_misaligned_int = 1'b1;
        // check also from icache
        end /*else  
        if (req_icache_cpu_i.valid && 
            req_icache_cpu_i.instr_addr_misaligned) begin
            ex_addr_misaligned_int = 1'b1;
        end */
        else begin
            ex_addr_misaligned_int = 1'b0;
        end
    end
    // check exceptions instr page fault
    always_comb begin
        if (req_icache_cpu_i.valid && 
            req_icache_cpu_i.instr_page_fault) begin
            ex_if_page_fault_int = 1'b1;
        end else begin
            ex_if_page_fault_int = 1'b0;
        end
    end

    // logic for icache access
    assign req_cpu_icache_o.valid = !ex_addr_misaligned_int; //& 
                                    //!ex_if_addr_fault_int & 
                                    //!ex_if_page_fault_int;

    assign req_cpu_icache_o.vaddr = pc[39:0];

    
    // logic branch predictor
    assign fetch_o.pc_inst = pc;
    assign fetch_o.inst = req_icache_cpu_i.data;
    assign fetch_o.valid = req_icache_cpu_i.valid;
    assign fetch_o.bpred.decision = PRED_NOT_TAKEN; // TODO: add bpred
    assign fetch_o.bpred.pred_addr = 64'b0; // TODO: add bpred 

    // exceptions ordering
    always_comb begin
        if (ex_addr_misaligned_int) begin
            fetch_o.ex.cause = INSTR_ADDR_MISALIGNED;
            fetch_o.ex.valid = 1'b1;
        end else 
        if (ex_if_addr_fault_int) begin
            fetch_o.ex.cause = INSTR_ACCESS_FAULT;
            fetch_o.ex.valid = 1'b1;
        end else if (ex_if_page_fault_int) begin
            fetch_o.ex.cause = INSTR_PAGE_FAULT;
            fetch_o.ex.valid = 1'b1;
        end else begin
            fetch_o.ex.cause = INSTR_ADDR_MISALIGNED;
            fetch_o.ex.valid = 1'b0;
        end
    end
    assign fetch_o.ex.origin = pc;
   

endmodule
