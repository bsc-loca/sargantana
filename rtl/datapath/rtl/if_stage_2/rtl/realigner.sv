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

module realigner
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic clk_i,
    input logic rstn_i,
    input logic flush_i,
    input logic stall_i,

    // From I$
    input logic icache_valid_i,
    input bus32_t data_i,

    // From F1
    input logic f1_valid_i,
    input addrPC_t addr_i,

    // From F2
    input logic branch_predicted_i,
    input logic prev_branch_predicted_i,

    // To D
    output logic valid_o,
    output addrPC_t pc_o,
    output addrPC_t next_pc_o,
    output bus32_t data_o,

    // To CU
    output logic keep_fetch_o
);

/*
    logic is_compressed[1:0]; // 1 -> bits 31..16; 0 -> bits 15..0

    always_comb begin
        for (int i = 0; i < 2; ++i) begin
            is_compressed[i] = !(&data_i[16*i +: 2]);
        end
    end
    */

    function automatic logic is_compressed(logic [15:0] instruction);
        is_compressed = !(&instruction[1:0]);
    endfunction

    /*
     * --------------------------------------------------------------------------------------------
     * Storage logic for unaligned 32-bit instructions
     * --------------------------------------------------------------------------------------------
     */

    logic unaligned_d, unaligned_q;
    logic [15:0] unaligned_data_d, unaligned_data_q;
    addrPC_t unaligned_addr_d, unaligned_addr_q;

    logic valid_instruction;

    addrPC_t current_pc;

    // If we have unaligned data stored it means that we have data prom the
    // previous fetch waiting to complete the instruction
    assign current_pc = (unaligned_q) ? unaligned_addr_q : addr_i;

    always_comb begin
        valid_instruction = ((f1_valid_i & icache_valid_i) & (
                            // aligned
                            !(|current_pc[1:0]) | // if it is aligned and we have all inputs valid we will always have a valid instruction
                            // unaligned
                            is_compressed(data_i[31:16]) | // if it is not aligned but we have a compressed it will always be valid
                            unaligned_q) // if it is not aligned and is not a compressed we need to check if we have a previous data stored
                        || (unaligned_q && !(&unaligned_data_q[1:0]))
        );
    end 

    logic is_compressed_31_16;
    logic is_compressed_15_0;

    assign is_compressed_31_16 = is_compressed(data_i[31:16]);
    assign is_compressed_15_0 = is_compressed(data_i[15:0]);

    logic computed_unaligned;

    always_comb begin
        if (f1_valid_i && icache_valid_i) begin
            if (current_pc[1] == 1'b1) begin
                if (unaligned_q) begin
                    computed_unaligned = &unaligned_data_q[1:0];
                end else begin
                    computed_unaligned = !is_compressed_31_16;
                end
            end else begin
                computed_unaligned = is_compressed_15_0;
            end
        end else begin
            computed_unaligned = (unaligned_q & !valid_instruction);
        end

        unaligned_d = computed_unaligned & !(branch_predicted_i && !(prev_branch_predicted_i && !valid_instruction));

        unaligned_addr_d = {addr_i[riscv_pkg::XLEN-1: 2], 2'b10};

        unaligned_data_d = data_i[31:16];
    end

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (!rstn_i) begin
            unaligned_q <= 1'b0;
            unaligned_addr_q <= '0;
            unaligned_data_q <= '0;
        end else begin
            if (flush_i) begin
                unaligned_q <= 1'b0;
            end else if (((f1_valid_i & icache_valid_i) || (unaligned_q && valid_o)) && !stall_i) begin
                unaligned_q <= unaligned_d;
                unaligned_addr_q <= unaligned_addr_d;
                unaligned_data_q <= unaligned_data_d;
            end
        end
    end

    /*
     * --------------------------------------------------------------------------------------------
     * Output logic
     * --------------------------------------------------------------------------------------------
     */

    always_comb begin
        valid_o = valid_instruction;

        data_o = !(|current_pc[1:0]) ? 
                        ((is_compressed(data_i[15:0])) ? {16'b0, data_i[15:0]} :
                                              data_i) :
                        ((unaligned_q) ? ((&unaligned_data_q[1:0]) ? {data_i[15:0], unaligned_data_q} :
                                                                     {16'b0, unaligned_data_q}) :
                                         {16'b0, data_i[31:16]});

        pc_o = current_pc;

        keep_fetch_o = (f1_valid_i & icache_valid_i) & 
                            ((!(|current_pc[1:0]) & is_compressed(data_i[15:0]) & is_compressed(data_i[31:16])) ||
                            (unaligned_d & !(&unaligned_data_d[1:0])));


        if (unaligned_q) begin
            if (&unaligned_data_q[1:0]) begin
                next_pc_o = current_pc + 64'h04;
            end else begin
                next_pc_o = current_pc + 64'h02;
            end
        end else begin
            //if (is_compressed[current_pc[1]]) begin
            if (is_compressed(data_i[16*current_pc[1] +: 16])) begin
                next_pc_o = current_pc + 64'h02;
            end else begin
                next_pc_o = current_pc + 64'h04;
            end
        end


    end

endmodule
