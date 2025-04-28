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



module vmsb_i_o_f 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input bus_simd_t            data_vs2_i,     // 64-bit source operand 2
    input bus_mask_t            data_vm,        // 16-bit mask
    input logic                 use_mask,        //
    output bus64_t              data_vd_o       // 64-bit result
);

// This module outputs a mask register that has all elements set until before the first active element set in source vs2

bus64_t result;
always_comb begin
    result = '0;
    if ((instr_type_i == VMSBF) || (instr_type_i == VMSIF) || (instr_type_i == VMSOF)) begin //to control power
        for (int i=0; (i<(VLEN/8)); ++i) begin
            if((instr_type_i == VMSOF)) begin
                if ((data_vm[i] & use_mask & data_vs2_i[i]) | (~use_mask & data_vs2_i[i])) begin
                    result[i] = 1;
                    break;    
                end
            end else begin    
                if ((data_vm[i] & use_mask & data_vs2_i[i]) | (data_vs2_i[i] & ~use_mask)) begin
                    if(instr_type_i == VMSIF) begin
                        result[i] = 1;
                    end
                    break;
                end else begin
                    result[i] = 1;
                end
            end
        end
    end else begin
        result = '0;
    end
end

assign data_vd_o = result;

endmodule
