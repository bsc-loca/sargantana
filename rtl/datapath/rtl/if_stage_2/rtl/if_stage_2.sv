/*
 * Copyright 2025 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
//`default_nettype none

module if_stage_2
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic                 clk_i,
    input logic                 rstn_i,
    input logic                 v_mode_i,
    input logic                 en_translation_i,
    input logic                 en_g_translation_i,
    // data comming form the first stage
    input if_1_if_2_stage_t     fetch_i,
    // Response packet coming from Icache
    input resp_icache_cpu_t     resp_icache_cpu_i,
    // stall and flush of fetch_2
    input logic                 stall_i,
    input logic                 flush_i,
    // fetch data output
    output if_id_stage_t        fetch_o,
    output addrPC_t             next_pc_o,
    // stall fetch_1 if there are a miss
    output logic                stall_o,
    output logic                keep_fetch_o
);

logic ex_if_page_fault_int, ex_if_guest_page_fault_int, ex_if_access_fault_int;
resp_icache_cpu_t resp_icache_cpu_d, resp_icache_cpu_q;

logic realigner_valid;

logic instr_valid;
bus32_t instr_data;

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
// check exceptions instr access fault
    always_comb begin
        if (resp_icache_cpu_q.valid && 
                    resp_icache_cpu_q.instr_access_fault) begin
            ex_if_access_fault_int = 1'b1;
        end else if (resp_icache_cpu_i.valid && 
                    resp_icache_cpu_i.instr_access_fault) begin
            ex_if_access_fault_int = 1'b1;
        end else begin
            ex_if_access_fault_int = 1'b0;
        end
    end
// check exceptions instr guest page fault
    always_comb begin
        if (resp_icache_cpu_q.valid && 
                    resp_icache_cpu_q.instr_guest_page_fault) begin
            ex_if_guest_page_fault_int = 1'b1;
        end else if (resp_icache_cpu_i.valid && 
                    resp_icache_cpu_i.instr_guest_page_fault) begin
            ex_if_guest_page_fault_int = 1'b1;
        end else begin
            ex_if_guest_page_fault_int = 1'b0;
        end
    end

// exceptions ordering
    always_comb begin
        if (fetch_i.ex.valid) begin
            fetch_o.ex.cause = fetch_i.ex.cause;
            fetch_o.ex.origin2 = fetch_i.ex.origin2;
            fetch_o.ex.tinst = fetch_i.ex.tinst;
            fetch_o.ex.valid = 1'b1;
        end else if (ex_if_page_fault_int) begin
            fetch_o.ex.cause = INSTR_PAGE_FAULT;
            fetch_o.ex.origin2 = '0;
            fetch_o.ex.tinst = '0;
            fetch_o.ex.valid = 1'b1;
        end else if (ex_if_guest_page_fault_int) begin
            fetch_o.ex.cause = INSTR_GUEST_PAGE_FAULT;
            fetch_o.ex.origin2 = (en_translation_i && v_mode_i) ? 
                                    (resp_icache_cpu_q.valid ? 
                                        (({resp_icache_cpu_q.guest_ppn, fetch_i.pc_inst[11:0]}) >> 2) :
                                        (({resp_icache_cpu_i.guest_ppn, fetch_i.pc_inst[11:0]}) >> 2)) :
                                    (fetch_i.pc_inst >> 2); //GVA = GPA in G-stage only translations
            fetch_o.ex.tinst = fetch_i.ex.tinst;
            fetch_o.ex.valid = 1'b1;
        end else if (ex_if_access_fault_int) begin
            fetch_o.ex.cause = INSTR_ACCESS_FAULT;
            fetch_o.ex.origin2 = '0;
            fetch_o.ex.tinst = '0;
            fetch_o.ex.valid = 1'b1;
        end else begin
            fetch_o.ex.cause = INSTR_ADDR_MISALIGNED;
            fetch_o.ex.origin2 = '0;
            fetch_o.ex.tinst = '0;
            fetch_o.ex.valid = 1'b0;
        end
    end
    assign fetch_o.ex.origin = fetch_i.ex.origin;
    assign fetch_o.ex.gva = fetch_i.ex.gva;

/*

// output instruction and valid bit
    assign fetch_o.inst    = resp_icache_cpu_q.valid ? resp_icache_cpu_q.data : resp_icache_cpu_i.data;
// valid if the response of the cache is valid or xcpt
    assign fetch_o.valid   = fetch_i.valid && (resp_icache_cpu_i.valid || fetch_i.ex.valid || resp_icache_cpu_q.valid);
*/
    assign instr_data = resp_icache_cpu_q.valid ? resp_icache_cpu_q.data : resp_icache_cpu_i.data;
    assign instr_valid = resp_icache_cpu_i.valid || fetch_i.ex.valid || resp_icache_cpu_q.valid;

    logic branch_predicted;
    logic prev_branch_predicted;

    assign branch_predicted = fetch_i.bpred.is_branch & (fetch_i.bpred.decision == PRED_TAKEN);

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (!rstn_i) begin
            prev_branch_predicted <= 1'b0;
        end else begin
            if (realigner_valid) begin
                prev_branch_predicted <= branch_predicted;
            end
        end
    end

    realigner realigner_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_i),
        .stall_i(stall_i),
        .icache_valid_i(instr_valid),
        .data_i(instr_data),
        .f1_valid_i(fetch_i.valid),
        .addr_i(fetch_i.pc_inst),
        .branch_predicted_i(branch_predicted),
        .prev_branch_predicted_i(prev_branch_predicted),
        .valid_o(realigner_valid),
        .data_o(fetch_o.inst),
        .pc_o(fetch_o.pc_inst),
        .next_pc_o(next_pc_o),
        .keep_fetch_o(keep_fetch_o)
    );

// stall the pipeline in case of a cache miss 
    assign stall_o         = fetch_i.valid && !(resp_icache_cpu_i.valid || fetch_i.ex.valid || resp_icache_cpu_q.valid); 
    assign fetch_o.valid   = (realigner_valid && !stall_i) || (fetch_i.valid && fetch_i.ex.valid);

//bypassing wires
    //assign fetch_o.pc_inst = fetch_i.pc_inst;
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
            resp_icache_cpu_d.guest_ppn = '0;
            resp_icache_cpu_d.instr_page_fault = 1'b0;
            resp_icache_cpu_d.instr_access_fault = 1'b0;
            resp_icache_cpu_d.instr_guest_page_fault = 1'b0;
        end else if (resp_icache_cpu_i.valid && stall_i) begin
            resp_icache_cpu_d.valid = 1'b1;
            resp_icache_cpu_d = resp_icache_cpu_i;
            resp_icache_cpu_d.guest_ppn = resp_icache_cpu_i.guest_ppn;
            resp_icache_cpu_d.instr_page_fault = resp_icache_cpu_i.instr_page_fault;
            resp_icache_cpu_d.instr_access_fault = resp_icache_cpu_i.instr_access_fault;
            resp_icache_cpu_d.instr_guest_page_fault = resp_icache_cpu_i.instr_guest_page_fault;
        end else if (resp_icache_cpu_q.valid && !stall_i) begin
            resp_icache_cpu_d.valid = 1'b0;
            resp_icache_cpu_d.data = 32'b0;
            resp_icache_cpu_d.guest_ppn = '0;
            resp_icache_cpu_d.instr_page_fault = 1'b0;
            resp_icache_cpu_d.instr_access_fault = 1'b0;
            resp_icache_cpu_d.instr_guest_page_fault = 1'b0;
        end else begin
            resp_icache_cpu_d = resp_icache_cpu_q;
        end
    end

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            resp_icache_cpu_q.valid <= 1'b0;
            resp_icache_cpu_q.data <= 32'b0;
            resp_icache_cpu_q.guest_ppn <= '0;
            resp_icache_cpu_q.instr_page_fault <= 1'b0;
            resp_icache_cpu_q.instr_access_fault <= 1'b0;
            resp_icache_cpu_q.instr_guest_page_fault <= 1'b0;
        end else begin 
            resp_icache_cpu_q <= resp_icache_cpu_d;
        end
    end




endmodule
`default_nettype wire
