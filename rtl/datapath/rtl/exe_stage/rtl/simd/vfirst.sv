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



module vfirst 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t              instr_type_i,   // Instruction type
    input sew_t                     sew_i,          // Element width
    input bus_simd_t                data_vs2_i,     // 64-bit source operand 2
    input bus_mask_t                data_vm,        // 16-bit mask
    input logic                     use_mask,        //
    input logic[VMAXELEM_LOG:0]     vl_i,            // Current vector lenght in elements    
    output bus64_t                  data_rd_o       // 64-bit result
);

// This module computes the first (active) element of the vector mask source 2 set 1, and returns its index.
// This is implemented using an inverse priority encoder

bus_mask_t data_a_masked; 
bus64_t result;

assign data_a_masked = use_mask ? (data_vs2_i[((VLEN/8)-1):0] & data_vm) : data_vs2_i[((VLEN/8)-1):0];

always_comb begin
    result = {64{1'b1}};
    if(instr_type_i == VFIRST) begin 
        case (sew_i)
            SEW_8: begin
                for (int i = 0; (i < (VLEN/8)); ++i) begin
                    if(i < vl_i) begin
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
            SEW_16: begin
                for (int i = 0; (i < (VLEN/16)); ++i) begin
                    if(i < vl_i) begin                    
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
            SEW_32: begin
                for (int i = 0; (i < (VLEN/32)); ++i) begin
                    if(i < vl_i) begin
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
            SEW_64: begin
                for (int i = 0; (i < (VLEN/64)); ++i) begin
                    if(i < vl_i) begin
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
            default: begin
                for (int i = 0; (i < (VLEN/8)); ++i) begin
                    if(i < vl_i) begin
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
        endcase
    end
end

assign data_rd_o = result;

endmodule
