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

module vset_module
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic                     clk_i,            // Clock Singal
    input logic                     rstn_i,           // Negated Reset Signal

    input logic [11:0]              vtype_i,          // Vtype value input
    input bus64_t                   avl_value_i,      // AVL new input
    input logic                     is_vset_i,        // 1 -> If the instruction is a VSET instr    
    input logic [3:0]               rw_cmd_i,         // input for AVL respect to MAX
    input logic                     write_vset_i,
    input logic                     vset_commited_i,
    input logic                     recover_commit_exception_i,
    input logic                     recover_last_misspredict_i,
    input logic [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] vset_index_misspredict_i,    

    output logic [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] vset_index_o,
    output logic                    vnarrow_wide_o,
    output logic [VMAXELEM_LOG:0]   vl_o,
    output logic [VMAXELEM_LOG:0]   vl_short_o,
    output sew_t                    sew_o,
    output logic                    vill_o,
    output logic                    vma_o,
    output logic                    vta_o,
    output logic [2:0]              vlmul_o,
    output logic [VMAXELEM_LOG:0]   vlmax_o,
    output logic [VTYPE_LENGTH:0]   prev_vtype_o,     // First uncommitted vtype
    output logic                    full_vset_queue_o
    
);

logic vnarrow_wide_en_d;

bus64_t vlmax;
bus64_t vl_d, vtype_d;    
bus64_t vl_q;


always_comb begin : vsetvl_ctrl
    // new vlmax depending on the vtype config
    vtype_d = {1'b1,63'b0};
    vnarrow_wide_en_d = 1'b1;
    
    case(vtype_i[2:0])
        3'b101:  vlmax = ((riscv_pkg::VLEN >> 3) >> vtype_i[5:3]) >> 3;
        3'b110:  vlmax = ((riscv_pkg::VLEN >> 3) >> vtype_i[5:3]) >> 2;
        3'b111:  vlmax = ((riscv_pkg::VLEN >> 3) >> vtype_i[5:3]) >> 1;
        default: vlmax = ((riscv_pkg::VLEN >> 3) >> vtype_i[5:3]);
    endcase

    if (is_vset_i) begin
        // vl assignation depending on the AVL respect VLMAX
        if (rw_cmd_i[2:0] == 3'b111) begin //vsetvl with x0
            if (avl_value_i == 64'b1) begin  
                vl_d =  vl_q; 
            end else begin
                vl_d = vlmax;
            end
        end else if (vlmax >= avl_value_i) begin
            vl_d = avl_value_i;
        end else if ((vlmax<<1) >= avl_value_i) begin
            vl_d = (avl_value_i>>1) + avl_value_i[0];
        end else begin
            vl_d = vlmax;
        end

        // vtype assignation
        if ((vtype_i[10:8] != 3'b0) || (vtype_i[5] == 1'b1) || 
            ((vtype_i[2:0] > 3'b0) && ((vtype_i[2:0] < 3'b101) || (vtype_i[1:0] <= vtype_i[4:3])))) begin // unsupported tail, or SEW/LMUL configuration (rvv1.0 page 11)
            vtype_d = {1'b1,63'b0};
            vl_d = 'h0;
        end else begin
            vtype_d = {'0, vtype_i};
        end

                
        if (vtype_i[2] || (vl_d <= (vlmax >> 1))) begin
            vnarrow_wide_en_d = 1'b1;
        end else begin
            vnarrow_wide_en_d = 1'b0;
        end            
    end else begin
        // default, keeps the old value
        vl_d = vl_q;
    end
end


vset_queue vset_queue_inst(
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .new_vset_i(write_vset_i),
    .commited_vset_i(vset_commited_i),

    .recover_last_committed_i(recover_commit_exception_i),
    .recover_last_misspredict_i(recover_last_misspredict_i),
    .vset_index_misspredict_i(vset_index_misspredict_i),

    .vl_i(vl_d[0 +: (VMAXELEM_LOG+1)]),
    .vtype_i({vtype_d[63], vtype_d[7:0]}),
    .vnarrow_wide_en_i(vnarrow_wide_en_d),
    .vlmax_i(vlmax[VMAXELEM_LOG:0]),

    .sew_o(sew_o),
    .vl_o(vl_q),
    .vnarrow_wide_en_o(vnarrow_wide_o),
    .vill_o(vill_o),
    .vma_o(vma_o),
    .vta_o(vta_o),
    .vlmul_o(vlmul_o),
    .vlmax_o(vlmax_o),
    .prev_vtype_o(prev_vtype_o),
    .full_o(full_vset_queue_o),
    .vset_index_o(vset_index_o)

);

assign vl_o = vl_q[0 +: (VMAXELEM_LOG+1)];
assign vl_short_o = vl_d[0 +: (VMAXELEM_LOG+1)];

endmodule

