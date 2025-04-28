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

module viota
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input bus_simd_t            data_vs2_i,     // bus_simd_t source operand 2
    input bus_simd_t            data_old_vd,     // bus_simd_t old value
    input bus_mask_t            data_vm_i,        // 64-bit mask
    input logic                 use_mask_i,        //
    output bus_simd_t           data_vd_o       // bus_simd_t result
);
function [63:0] trunc_64bits(input [64:0] val_in);
    trunc_64bits = val_in[63:0];
endfunction

logic [63:0] count;
bus_simd_t data_vd_i;

always_comb begin
    count = '0;
    data_vd_i = '0;
    if(instr_type_i == VIOTA) begin 
        unique case (sew_i)
            SEW_8 : begin
                for (int i = 0; i < (VLEN/8); i++) begin
                    if (use_mask_i & !data_vm_i[i]) begin
                        data_vd_i[(i*8)+:8] = data_old_vd[(i*8)+:8];
                    end else begin
                        data_vd_i[(i*8)+:8] = count[7:0];
                        count = trunc_64bits(count + data_vs2_i[i]);
                    end                       
                end                
            end
            SEW_16 : begin
                for (int i = 0; i < (VLEN/16); i++) begin
                    if (use_mask_i & !data_vm_i[i]) begin
                        data_vd_i[(i*16)+:16] = data_old_vd[(i*16)+:16];
                    end else begin
                        data_vd_i[(i*16)+:16] = count[15:0];
                        count = trunc_64bits(count + data_vs2_i[i]);
                    end      
                end
            end
            SEW_32 : begin
                for (int i = 0; i < (VLEN/32); i++) begin
                    if (use_mask_i & !data_vm_i[i]) begin
                        data_vd_i[(i*32)+:32] = data_old_vd[(i*32)+:32];
                    end else begin
                        data_vd_i[(i*32)+:32] = count[31:0];
                        count = trunc_64bits(count + data_vs2_i[i]);
                    end       
                end
            end

            SEW_64 : begin
                for (int i = 0; i < (VLEN/64); i++) begin
                    if (use_mask_i & !data_vm_i[i]) begin
                        data_vd_i[(i*64)+:64] = data_old_vd[(i*64)+:64];
                    end else begin
                        data_vd_i[(i*64)+:64] = count[63:0];
                        count = trunc_64bits(count + data_vs2_i[i]);
                    end  
                end
            end
            default : begin
                count = '0;
            end
        endcase
    end else begin
        data_vd_i = '0;
    end
end

assign data_vd_o = data_vd_i;

endmodule
