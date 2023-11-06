/*
 * Copyright 2023 BSC*
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

module instruction_queue
    import drac_pkg::*;
(
    input logic            clk_i,            // Clock Singal
    input logic            rstn_i,           // Negated Reset Signal

    input id_ir_stage_t    instruction_i,    // All instruction input signals   
    input logic            flush_i,          // Flush all entries to 0
    input logic            read_head_i,      // Read tail of the ciruclar buffer

    output id_ir_stage_t   instruction_o,    // All intruction output signals
    output logic           full_o,           // IQ is full
    output logic           empty_o           // IQ is empty TODO: check if empty signal is necessary
);

typedef logic [$clog2(INSTRUCTION_QUEUE_NUM_ENTRIES)-1:0] instruction_queue_entry;
typedef reg [$clog2(INSTRUCTION_QUEUE_NUM_ENTRIES)-1:0] reg_instruction_queue_entry;

reg_instruction_queue_entry head;
reg_instruction_queue_entry tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(INSTRUCTION_QUEUE_NUM_ENTRIES):0] num;

logic write_enable;
logic read_enable;


// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num < INSTRUCTION_QUEUE_NUM_ENTRIES);

// User can read the tail of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = read_head_i & (num > 0) ;


id_ir_stage_t instruction_buffer[0:INSTRUCTION_QUEUE_NUM_ENTRIES-1];

always_ff @(posedge clk_i)
begin
    if (write_enable) begin
        instruction_buffer[tail] <= instruction_i;
    end
end

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
    end
    else if (flush_i) begin
        head <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
    end
    else begin
        head <= head + {2'b00, read_enable};
        tail <= tail + {2'b00, write_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, read_enable};
    end
end


//assign instruction_o = (~read_enable)? 'h0 : instruction_buffer[head];
assign instruction_o = empty_o ? 'h0 : instruction_buffer[head];
assign empty_o = (num == 0);
assign full_o  = ((num == INSTRUCTION_QUEUE_NUM_ENTRIES) | ~rstn_i);

endmodule

