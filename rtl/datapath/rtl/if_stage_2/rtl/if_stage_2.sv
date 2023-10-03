/* -----------------------------------------------
* Project Name   : DRAC
* File           : if_stage_2.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Max Doblas / Guillem Lopez Paradis (old implementation)
* Email(s)       : max.doblas@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Max Doblas | First implementation of 2 IF stages
* -----------------------------------------------
*/
//`default_nettype none

module if_stage_2
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic                 clk_i,
    input logic                 rstn_i,
    // data comming form the first stage
    input if_1_if_2_stage_t     fetch_i,
    // Response packet coming from Icache
    input resp_icache_cpu_t     resp_icache_cpu_i,
    // stall and flush of fetch_2
    input logic                 stall_i,
    input logic                 flush_i,
    // fetch data output
    output if_id_stage_t        fetch_o,
    // stall fetch_1 if there are a miss
    output logic                stall_o
);

logic ex_if_page_fault_int;
resp_icache_cpu_t resp_icache_cpu_d, resp_icache_cpu_q;


// check exceptions instr page fault
    always_comb begin
        if (resp_icache_cpu_q.valid && 
                    resp_icache_cpu_q.instr_page_fault) begin
            ex_if_page_fault_int = 1'b1;
        end else if (resp_icache_cpu_i.valid && 
                    resp_icache_cpu_i.instr_page_fault) begin
            ex_if_page_fault_int = 1'b1;
        end else begin
            ex_if_page_fault_int = 1'b0;
        end
    end

// exceptions ordering
    always_comb begin
        if (fetch_i.ex.valid) begin
            fetch_o.ex.cause = fetch_i.ex.cause;
            fetch_o.ex.valid = 1'b1;
        end else if (ex_if_page_fault_int) begin
            fetch_o.ex.cause = INSTR_PAGE_FAULT;
            fetch_o.ex.valid = 1'b1;
        end else begin
            fetch_o.ex.cause = INSTR_ADDR_MISALIGNED;
            fetch_o.ex.valid = 1'b0;
        end
    end
    assign fetch_o.ex.origin = fetch_i.ex.origin;

// output instruction and valid bit
    assign fetch_o.inst    = resp_icache_cpu_q.valid ? resp_icache_cpu_q.data : resp_icache_cpu_i.data;
// valid if the response of the cache is valid or xcpt
    assign fetch_o.valid   = fetch_i.valid && (resp_icache_cpu_i.valid || fetch_i.ex.valid || resp_icache_cpu_q.valid);
// stall the pipeline in case of a cache miss 
    assign stall_o         = fetch_i.valid && !(resp_icache_cpu_i.valid || fetch_i.ex.valid || resp_icache_cpu_q.valid); 

//bypassing wires
    assign fetch_o.pc_inst = fetch_i.pc_inst;
    assign fetch_o.bpred.is_branch = fetch_i.bpred.is_branch;
    assign fetch_o.bpred.decision  = fetch_i.bpred.decision;
    assign fetch_o.bpred.pred_addr = fetch_i.bpred.pred_addr;
    `ifdef SIM_KONATA_DUMP
    assign fetch_o.id = fetch_i.id;
    `endif


// Save the resp of the icache in case of an stall.
    always_comb begin
        if (flush_i) begin
            resp_icache_cpu_d.valid = 1'b0;
            resp_icache_cpu_d.data = 32'b0;
            resp_icache_cpu_d.instr_page_fault = 1'b0;
        end else if (resp_icache_cpu_i.valid && stall_i) begin
            resp_icache_cpu_d = resp_icache_cpu_i;
        end else if (resp_icache_cpu_q.valid && !stall_i) begin
            resp_icache_cpu_d.valid = 1'b0;
            resp_icache_cpu_d.data = 32'b0;
            resp_icache_cpu_d.instr_page_fault = 1'b0;
        end else begin
            resp_icache_cpu_d = resp_icache_cpu_q;
        end
    end

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            resp_icache_cpu_q.valid <= 1'b0;
            resp_icache_cpu_q.data <= 32'b0;
            resp_icache_cpu_q.instr_page_fault <= 1'b0;
        end else begin 
            resp_icache_cpu_q <= resp_icache_cpu_d;
        end
    end




endmodule
`default_nettype wire
