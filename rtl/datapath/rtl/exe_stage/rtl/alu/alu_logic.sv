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

module alu_logic
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    input bus64_t data_rs2_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

// Operation
always_comb begin
    case (instr_type_i)
        AND_INST, ANDN, BCLR, BEXT: begin
            result_o = data_rs1_i & data_rs2_i;
        end
        OR_INST, ORN, BSET: begin
            result_o = data_rs1_i | data_rs2_i;
        end
        XOR_INST, XNOR_INST, BINV: begin
            result_o = data_rs1_i ^ data_rs2_i;
        end
        ORCB: begin
            for (int i = 0; i < (XLEN/8); ++i) begin
                result_o[8*i +: 8] = (data_rs1_i[8*i +: 8] == 8'b0) ? 8'b0 : 8'hFF;
            end
        end
        default: begin
            result_o = 64'b0;
        end
    endcase
end

endmodule