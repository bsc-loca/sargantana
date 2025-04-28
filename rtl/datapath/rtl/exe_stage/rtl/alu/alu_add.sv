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

module alu_add
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    input bus64_t data_rs2_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

function [63:0] trunc_65_64(input [64:0] val_in);
  trunc_65_64 = val_in[63:0];
endfunction

bus64_t data_rs2_op;
logic carry_in;

// Negation and carry in for subtracting
always_comb begin
    case (instr_type_i)
        SUB, SUBW: begin
            data_rs2_op = ~data_rs2_i;
            carry_in = 1'b1;
        end
        default: begin
            data_rs2_op = data_rs2_i;
            carry_in = 1'b0;
        end
    endcase
end

// Operation
assign result_o = trunc_65_64(data_rs1_i + data_rs2_op + carry_in);

endmodule