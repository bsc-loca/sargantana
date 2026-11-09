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

module vwaddsub 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input bus32_t               data_vs1_i,     // 32-bit source operand 1
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);

// The narrow operands are sign- or zero-extended explicitly, and every sum is
// computed at the result width. The previous form, e.g.
//   data_vd_o[63:0] = $signed(data_vs2_i[31:0]) + $signed(data_vs1_i[31:0]);
// relies on a signed expression being sign-extended to the width of its
// target; simulators do that, but Vivado 2024.2 synthesised these sums
// zero-extended (vwadd e32 of -1 + -1 gave 0x00000000fffffffe on the FPGA).
function automatic logic [15:0] ext8(input logic [7:0] x, input logic sgn);
    ext8 = {{8{sgn & x[7]}}, x};
endfunction

function automatic logic [31:0] ext16(input logic [15:0] x, input logic sgn);
    ext16 = {{16{sgn & x[15]}}, x};
endfunction

function automatic logic [63:0] ext32(input logic [31:0] x, input logic sgn);
    ext32 = {{32{sgn & x[31]}}, x};
endfunction

always_comb begin
    case (sew_i)
        SEW_8: 
            for (int i = 0; i < 4; i++) begin
                case(instr_type_i)
                    VWADD:   data_vd_o[16*i +: 16] = ext8(data_vs2_i[8*i +: 8], 1'b1) + ext8(data_vs1_i[8*i +: 8], 1'b1);
                    VWADDU:  data_vd_o[16*i +: 16] = ext8(data_vs2_i[8*i +: 8], 1'b0) + ext8(data_vs1_i[8*i +: 8], 1'b0);
                    VWSUB:   data_vd_o[16*i +: 16] = ext8(data_vs2_i[8*i +: 8], 1'b1) - ext8(data_vs1_i[8*i +: 8], 1'b1);
                    VWSUBU:  data_vd_o[16*i +: 16] = ext8(data_vs2_i[8*i +: 8], 1'b0) - ext8(data_vs1_i[8*i +: 8], 1'b0);
                    VWADDW:  data_vd_o[16*i +: 16] = data_vs2_i[16*i +: 16] + ext8(data_vs1_i[8*i +: 8], 1'b1);
                    VWADDUW: data_vd_o[16*i +: 16] = data_vs2_i[16*i +: 16] + ext8(data_vs1_i[8*i +: 8], 1'b0);
                    VWSUBW:  data_vd_o[16*i +: 16] = data_vs2_i[16*i +: 16] - ext8(data_vs1_i[8*i +: 8], 1'b1);
                    VWSUBUW: data_vd_o[16*i +: 16] = data_vs2_i[16*i +: 16] - ext8(data_vs1_i[8*i +: 8], 1'b0);
                    default: data_vd_o[16*i +: 16] = 16'b0;
                endcase
            end
        SEW_16: 
            for (int i = 0; i < 2; i++) begin
                case(instr_type_i)
                    VWADD:   data_vd_o[32*i +: 32] = ext16(data_vs2_i[16*i +: 16], 1'b1) + ext16(data_vs1_i[16*i +: 16], 1'b1);
                    VWADDU:  data_vd_o[32*i +: 32] = ext16(data_vs2_i[16*i +: 16], 1'b0) + ext16(data_vs1_i[16*i +: 16], 1'b0);
                    VWSUB:   data_vd_o[32*i +: 32] = ext16(data_vs2_i[16*i +: 16], 1'b1) - ext16(data_vs1_i[16*i +: 16], 1'b1);
                    VWSUBU:  data_vd_o[32*i +: 32] = ext16(data_vs2_i[16*i +: 16], 1'b0) - ext16(data_vs1_i[16*i +: 16], 1'b0);
                    VWADDW:  data_vd_o[32*i +: 32] = data_vs2_i[32*i +: 32] + ext16(data_vs1_i[16*i +: 16], 1'b1);
                    VWADDUW: data_vd_o[32*i +: 32] = data_vs2_i[32*i +: 32] + ext16(data_vs1_i[16*i +: 16], 1'b0);
                    VWSUBW:  data_vd_o[32*i +: 32] = data_vs2_i[32*i +: 32] - ext16(data_vs1_i[16*i +: 16], 1'b1);
                    VWSUBUW: data_vd_o[32*i +: 32] = data_vs2_i[32*i +: 32] - ext16(data_vs1_i[16*i +: 16], 1'b0);
                    default: data_vd_o[32*i +: 32] = 32'b0;
                endcase
            end
        default: // SEW_32, and SEW_64 as before
            case(instr_type_i)
                VWADD:   data_vd_o[63:0] = ext32(data_vs2_i[31:0], 1'b1) + ext32(data_vs1_i[31:0], 1'b1);
                VWADDU:  data_vd_o[63:0] = ext32(data_vs2_i[31:0], 1'b0) + ext32(data_vs1_i[31:0], 1'b0);
                VWSUB:   data_vd_o[63:0] = ext32(data_vs2_i[31:0], 1'b1) - ext32(data_vs1_i[31:0], 1'b1);
                VWSUBU:  data_vd_o[63:0] = ext32(data_vs2_i[31:0], 1'b0) - ext32(data_vs1_i[31:0], 1'b0);
                VWADDW:  data_vd_o[63:0] = data_vs2_i[63:0] + ext32(data_vs1_i[31:0], 1'b1);
                VWADDUW: data_vd_o[63:0] = data_vs2_i[63:0] + ext32(data_vs1_i[31:0], 1'b0);
                VWSUBW:  data_vd_o[63:0] = data_vs2_i[63:0] - ext32(data_vs1_i[31:0], 1'b1);
                VWSUBUW: data_vd_o[63:0] = data_vs2_i[63:0] - ext32(data_vs1_i[31:0], 1'b0);
                default: data_vd_o[63:0] = 64'b0;
            endcase
    endcase
end

endmodule
