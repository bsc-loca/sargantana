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

module score_board_scalar
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic             clk_i,
    input logic             rstn_i,
    input logic             flush_i,

    input logic             set_mul_32_i,               // Insert new Mul instruction of 2  cycles
    input logic             set_mul_64_i,               // Insert new Mul instruction of 3  cycles
    input logic             set_div_32_i,               // Insert new Div instruction of 17 cycles
    input logic             set_div_64_i,               // Insert new Div instruction of 32 cycles

    // OUTPUTS
    output logic            ready_1cycle_o,             // Instruction of 1 cycle duration can be issued
    output logic            ready_mul_32_o,             // Instruction of 2 cycles duration can be issued
    output logic            ready_mul_64_o,             // Instruction of 3 cycles duration can be issued
    output logic            ready_div_32_o,             // Instruction of 8 cycles duration can be issued
    output logic            div_unit_sel_o,             // Select Div unit for the Div instruction
    output logic            ready_div_unit_o            // At least one of the Div units is free
);

    logic [32:0] inst_d, inst_q;
    logic [1:0][32:0] ocup_div_unit_d;
    logic [1:0][32:0] ocup_div_unit_q;
    logic free_div_unit[1:0];

    // check if both div units are empty
    assign free_div_unit[0] = ~(|ocup_div_unit_q[0]);
    assign free_div_unit[1] = ~(|ocup_div_unit_q[1]);
    
    always_comb begin
        // shift all the busy slots for the next cycle
        for (int i = 31; i >= 0; i--) begin
            inst_d = inst_q >> 1;
        end
        for(int i = 1; i >= 0; i--) begin
            ocup_div_unit_d[i] = ocup_div_unit_q[i] >> 1;
        end

        // set the next cycle busy if there are a 32-bit mult
        if (set_mul_32_i) begin
            inst_d[0]  = 1'b1;
        end

        // set the next-next cycle busy if there are a 64-bit mult
        if (set_mul_64_i) begin
            inst_d[1]  = 1'b1;
        end

        // set the 16th cycle busy if there are a 32-bit div
        if (set_div_32_i) begin
            inst_d[16] = 1'b1;
            if (free_div_unit[0]) begin // if (~div_unit_sel_o)
                ocup_div_unit_d[0] = 33'h000010000;
            end else begin 
                ocup_div_unit_d[1] = 33'h000010000;
            end
        end

        // set the last (32) cycle busy if there are a 64-bit div
        if (set_div_64_i) begin
            inst_d[32] = 1'b1;
            if (free_div_unit[0]) begin // if (~div_unit_sel_o)
                ocup_div_unit_d[0] = 33'h100000000;
            end else begin 
                ocup_div_unit_d[1] = 33'h100000000;
            end
        end else begin
            inst_d[32] = 1'b0;   
        end
    end

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(~rstn_i) begin
            ocup_div_unit_q <= '0;
            inst_q <= '0;
        end 
        else if (flush_i) begin
            ocup_div_unit_q <= '0;
            inst_q <= '0;
        end 
        else begin
            ocup_div_unit_q <= ocup_div_unit_d;
            inst_q <= inst_d;
        end
    end

    assign ready_1cycle_o = (~inst_q[0]);
    assign ready_mul_32_o = (~inst_q[1]);
    assign ready_mul_64_o = (~inst_q[2]);
    assign ready_div_32_o = (~inst_q[17]);
    assign div_unit_sel_o = ~free_div_unit[0];
    assign ready_div_unit_o = free_div_unit[0] | free_div_unit[1];


endmodule

