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

module alu_cmp
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    input bus64_t data_rs2_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

logic slt;
logic sltu;

assign slt = $signed(data_rs1_i) < $signed(data_rs2_i);
assign sltu = data_rs1_i < data_rs2_i;

always_comb begin
    case (instr_type_i)
        SLT: begin
            result_o = {63'b0, slt};
        end
        SLTU: begin
            result_o = {63'b0, sltu};
        end
        MIN: begin
            result_o = slt ? data_rs1_i : data_rs2_i;
        end
        MINU: begin
            result_o = sltu ? data_rs1_i : data_rs2_i;
        end
        MAX: begin
            result_o = slt ? data_rs2_i : data_rs1_i;
        end
        MAXU: begin
            result_o = sltu ? data_rs2_i : data_rs1_i;
        end
        default: begin
            result_o = 64'b0;
        end
    endcase
end

endmodule