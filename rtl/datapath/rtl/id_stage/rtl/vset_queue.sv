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

module vset_queue
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic                     clk_i,              // Clock Singal
    input logic                     rstn_i,             // Negated Reset Signal
    
    input logic                     commited_vset_i,        // Read tail of the ciruclar buffer
    input logic                     new_vset_i,            // Read tail of the ciruclar buffer
    input logic                     recover_last_committed_i,
    input logic                     recover_last_misspredict_i,
    input logic [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] vset_index_misspredict_i,
    input logic [VMAXELEM_LOG:0]    vl_i,               // VL value  
    input logic [VTYPE_LENGTH:0]    vtype_i,              // Sew value
    input logic                     vnarrow_wide_en_i,  // Vector Narrowing Wide enable
    input logic [VMAXELEM_LOG:0]            vlmax_i,

    output logic [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] vset_index_o,
    output sew_t                    sew_o,             // Sew value
    output bus64_t                  vl_o,              // VL value  
    output logic                    vnarrow_wide_en_o, // Vector Narrowing Wide enable
    output logic                    vill_o,            // illegal vector configuration
    output logic                    vta_o,            // illegal vector configuration
    output logic                    vma_o,            // illegal vector configuration
    output logic [2:0]              vlmul_o,          // Vector register group multiplier (LMUL) setting
    output logic [VMAXELEM_LOG:0]           vlmax_o,
    output logic [VTYPE_LENGTH:0]   prev_vtype_o,     // First uncommitted vtype

    output logic                    full_o             // IQ is full
);

typedef struct packed {                     
    logic [VMAXELEM_LOG:0] vl;
    logic [VTYPE_LENGTH:0] vtype;   
    logic vnarrow_wide_en;
    logic [VMAXELEM_LOG:0] vlmax;
} vset_entry_t;


function [$clog2(VSET_QUEUE_NUM_ENTRIES):0] trunc_iq_num_sum(input [$clog2(VSET_QUEUE_NUM_ENTRIES)+1:0] val_in);
  trunc_iq_num_sum = val_in[$clog2(VSET_QUEUE_NUM_ENTRIES):0];
endfunction

function [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] trunc_iq_ptr_sum(input [$clog2(VSET_QUEUE_NUM_ENTRIES):0] val_in);
  trunc_iq_ptr_sum = val_in[$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0];
endfunction

typedef logic [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] instruction_queue_entry;
typedef reg [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] reg_instruction_queue_entry;

reg_instruction_queue_entry last_committed_vset_index;
reg_instruction_queue_entry index_last_vset;
reg_instruction_queue_entry tail;
reg_instruction_queue_entry first_not_committed_index;

//Num must be 1 bit bigger than head an tail
logic [$clog2(VSET_QUEUE_NUM_ENTRIES):0] num;


logic write_new_vset_enable;
logic next_committed_enable;


// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_new_vset_enable = new_vset_i & (num < VSET_QUEUE_NUM_ENTRIES);

// User can read the tail of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign next_committed_enable = commited_vset_i & (num > 1) ;


vset_entry_t vset_buffer[VSET_QUEUE_NUM_ENTRIES-1:0];
logic [$clog2(VSET_QUEUE_NUM_ENTRIES):0] num_in_misspred;
logic [$clog2(VSET_QUEUE_NUM_ENTRIES):0] num_in_misspred_prev;

//Todo:Check to modify for Tail - Head + 1 removing the significant bit
assign num_in_misspred_prev = (last_committed_vset_index > vset_index_misspredict_i) ? (VSET_QUEUE_NUM_ENTRIES - last_committed_vset_index) : (-last_committed_vset_index);
assign num_in_misspred = trunc_iq_num_sum(num_in_misspred_prev + trunc_iq_num_sum(({2'b00, vset_index_misspredict_i} + 1'b1)));

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if (~rstn_i) begin
        for (int i = 0; i < VSET_QUEUE_NUM_ENTRIES; ++i) begin
            vset_buffer[i].vl <= 1'b0;
            vset_buffer[i].vtype <= {1'b1, 7'b0};
            vset_buffer[i].vnarrow_wide_en <= 1'b0;
            vset_buffer[i].vlmax <= 1'b0;
        end
    end else begin
        if (write_new_vset_enable) begin
            vset_buffer[tail].vl <= vl_i;
            vset_buffer[tail].vtype <= vtype_i;
            vset_buffer[tail].vnarrow_wide_en <= vnarrow_wide_en_i;
            vset_buffer[tail].vlmax <= vlmax_i;              
        end
    end
end

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        last_committed_vset_index <= 3'h0;
        index_last_vset <= 3'h0;
        tail <= 3'b001;
        num  <= 4'b0001;
    end else if(recover_last_misspredict_i && next_committed_enable) begin
        last_committed_vset_index <= trunc_iq_ptr_sum(last_committed_vset_index + {2'b0, next_committed_enable});
        index_last_vset <= vset_index_misspredict_i;
        tail <= trunc_iq_ptr_sum(vset_index_misspredict_i + 1'b1);
        num  <= trunc_iq_num_sum(num_in_misspred - {3'b0, next_committed_enable});   
    end else if(recover_last_misspredict_i) begin
        index_last_vset <= vset_index_misspredict_i;
        tail <= trunc_iq_ptr_sum(vset_index_misspredict_i + 1'b1);
        num  <= num_in_misspred;        
    end else if(recover_last_committed_i) begin
        index_last_vset <= last_committed_vset_index;
        tail <= trunc_iq_ptr_sum(last_committed_vset_index + 1'b1);
        num  <= 4'b0001;                  
    end else begin
        last_committed_vset_index <= trunc_iq_ptr_sum(last_committed_vset_index + {2'b0, next_committed_enable});
        index_last_vset <= trunc_iq_ptr_sum(index_last_vset + {2'b0, write_new_vset_enable});
        tail <= trunc_iq_ptr_sum(tail + {2'b0, write_new_vset_enable});
        num  <= trunc_iq_num_sum(num  + {3'b0, write_new_vset_enable} - {3'b0, next_committed_enable});
    end
end

assign first_not_committed_index = trunc_iq_ptr_sum(last_committed_vset_index + 1'b1);
assign vset_index_o = index_last_vset;

assign vl_o = vset_buffer[index_last_vset].vl;
assign vlmax_o = vset_buffer[index_last_vset].vlmax;

assign vnarrow_wide_en_o = vset_buffer[index_last_vset].vnarrow_wide_en;
assign vill_o = vset_buffer[index_last_vset].vtype[8];
assign sew_o = sew_t'(vset_buffer[index_last_vset].vtype[4:3]);
assign vta_o = vset_buffer[index_last_vset].vtype[6];
assign vma_o = vset_buffer[index_last_vset].vtype[7];
assign vlmul_o = vset_buffer[index_last_vset].vtype[2:0];
assign prev_vtype_o = vset_buffer[first_not_committed_index].vtype;


assign full_o  = ((num == VSET_QUEUE_NUM_ENTRIES) | ~rstn_i);

endmodule

