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

module fp_free_list
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic            clk_i,               // Clock Singal
    input logic            rstn_i,              // Negated Reset Signal
    input logic            read_head_i,         // Read head of the circular buffer
    input logic  [1:0]     add_free_register_i, // Add new free register
    input phfreg_t [1:0]   free_register_i,     // Register to be freed

    input logic            do_checkpoint_i,     // After renaming do a checkpoint
    input logic            do_recover_i,        // Recover a checkpoint
    input logic            delete_checkpoint_i, // Delete tail checkpoint
    input checkpoint_ptr   recover_checkpoint_i,// Label of the checkpoint to recover or the checkpoint of the freed register
    input logic            commit_roll_back_i,  // Free on fly register because of exception

    output phfreg_t        new_register_o,      // First free register
    output checkpoint_ptr  checkpoint_o,        // Label of the checkpoint done. Use in case of recovery.
    output logic           out_of_checkpoints_o,// Indicates if user is able to do more checkpoints.
    output logic           empty_o              // Free list is empty
);

localparam NUM_ENTRIES_FREE_LIST = NUM_PHYSICAL_FREGISTERS - NUM_ISA_REGISTERS; // Number of entries in circular buffer

function [$clog2(NUM_CHECKPOINTS)-1:0] trunc_checkpoint_ptr_sum(input [$clog2(NUM_CHECKPOINTS):0] val_in);
  trunc_checkpoint_ptr_sum = val_in[$clog2(NUM_CHECKPOINTS)-1:0];
endfunction

function [$clog2(NUM_CHECKPOINTS):0] trunc_checkpoint_num_sum(input [$clog2(NUM_CHECKPOINTS)+1:0] val_in);
  trunc_checkpoint_num_sum = val_in[$clog2(NUM_CHECKPOINTS):0];
endfunction

function [$clog2(NUM_ENTRIES_FREE_LIST):0] trunc_free_list_num_sum(input [$clog2(NUM_ENTRIES_FREE_LIST)+1:0] val_in);
  trunc_free_list_num_sum = val_in[$clog2(NUM_ENTRIES_FREE_LIST):0];
endfunction

function [$clog2(NUM_ENTRIES_FREE_LIST)-1:0] trunc_free_list_ptr_sum(input [$clog2(NUM_ENTRIES_FREE_LIST):0] val_in);
  trunc_free_list_ptr_sum = val_in[$clog2(NUM_ENTRIES_FREE_LIST)-1:0];
endfunction

// Free list Pointer
typedef reg [$clog2(NUM_ENTRIES_FREE_LIST)-1:0] freg_free_list_entry;

// Point to the head and tail of the fifo. One pointer for each checkpoint
freg_free_list_entry head [NUM_CHECKPOINTS-1:0];
freg_free_list_entry tail;
freg_free_list_entry tail_plus_one;

// Point to the actual version of free list
checkpoint_ptr version_head;
checkpoint_ptr version_tail;
checkpoint_ptr version_head_plus_one;

//Num must be 1 bit bigger than head an tail
logic [$clog2(NUM_ENTRIES_FREE_LIST):0] num_registers [NUM_CHECKPOINTS-1:0];

//Num must be 1 bit bigger than checkpoint pointer
logic [$clog2(NUM_CHECKPOINTS):0] num_checkpoints;

// Determines if is gonna be read or writen
logic write_enable_0;
logic write_enable_1;
logic read_enable;
logic checkpoint_enable;

// Internal signal to do checkpoints 
// User can do checkpoints when there is at least one free copy of the free list
// And there is not an ongoing recover
assign checkpoint_enable = do_checkpoint_i & (num_checkpoints < (NUM_CHECKPOINTS - 1)) & (~do_recover_i) & (~commit_roll_back_i);

// User can write to the free list a new free register
// Freed register should be written to all checkpoints
// It cannot overflow the buffer. It cannot be done when recovering an old checkpoint.
assign write_enable_0 = (add_free_register_i[0]) & (~commit_roll_back_i);
assign write_enable_1 = (add_free_register_i[1]) & (~commit_roll_back_i);

// User can read the head of the buffer if there is any free register or 
// in this cycle a new register is written
assign read_enable = read_head_i & ((num_registers[version_head] > 0) | write_enable_0 | write_enable_1) & (~do_recover_i) & (~commit_roll_back_i);

assign tail_plus_one = trunc_free_list_ptr_sum(tail + 5'b00001);
assign version_head_plus_one = trunc_checkpoint_ptr_sum(version_head + 1'b1);

// FIFO Memory structure
phfreg_t register_table [NUM_ENTRIES_FREE_LIST-1:0];    // SRAM used to store the free registers. Read syncronous.

always_ff @(posedge clk_i, negedge rstn_i)
begin
    integer i;
    if (~rstn_i) begin                  // On reset clean first table
        version_head <= 'b0;            // Current head pointer
        num_checkpoints <= 'b0;         // No checkpoints
        version_tail <= 'b0;            // Last reserved pointer
        tail    <= 'b0;                 // Current tail in position
        checkpoint_o <= 'b0;            // Current checkpoint   
        for (integer j = 0; j < NUM_CHECKPOINTS ; j = j + 1) begin
            head[j] <= 'b0;                 // Current head in position
            num_registers[j]  <= 6'b100000; // Number of free registers 32
        end 
        for(i = 0; i < NUM_ENTRIES_FREE_LIST ; i = i + 1) begin
            register_table[i] <= i + 6'b100000;
        end
    end
    else if (commit_roll_back_i) begin
        version_head <= 'b0;            // Current head pointer
        num_checkpoints <= 'b0;         // No checkpoints
        version_tail <= 'b0;            // Last reserved pointer
        head[0] <= tail;                // Current head in position
        num_registers[0]  <= 6'b100000; // Number of free registers 32
        checkpoint_o <= 'b0;            // Current checkpoint 
    end
    else begin
        // When checkpoint is freed increment tail
        version_tail <= trunc_checkpoint_ptr_sum(version_tail + delete_checkpoint_i);

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //////// WRITES FREED REGISTER                                                                        /////////
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////


        if (write_enable_0) begin
            register_table[tail] <= free_register_i[0];
            if (write_enable_1) begin
                register_table[tail_plus_one] <= free_register_i[1];
            end
        end else begin
            if (write_enable_1) begin
                register_table[tail] <= free_register_i[1];
            end
        end

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //////// UPDATE CONTROL SIGNALS                                                                       /////////
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

        // When a register is freed increment tail
        tail <= trunc_free_list_ptr_sum(tail + write_enable_0 + write_enable_1);
        
        // Recompute number of free registers available.
        for(i = 0; i < NUM_CHECKPOINTS; i++) begin
            num_registers[i]  <= trunc_free_list_num_sum(num_registers[i]  + write_enable_0 + write_enable_1);
        end
        
        checkpoint_o <= version_head;

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //////// RECOVER OLD CHECKPOINT                                                                       /////////
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
        if (do_recover_i) begin                  

            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            //////// UPDATE CONTROL SIGNALS                                                                       /////////
            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////  

            version_head <= recover_checkpoint_i;
            if (recover_checkpoint_i >= version_tail) begin    // Recompute number of checkpoints
                num_checkpoints <= recover_checkpoint_i -  version_tail;
            end else begin 
                num_checkpoints <= NUM_CHECKPOINTS - version_tail + recover_checkpoint_i;
            end
        end
        else begin

            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            //////// UPDATE CONTROL SIGNALS                                                                       /////////
            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

            // Recompute number of checkpoints
            num_checkpoints <= trunc_checkpoint_num_sum(num_checkpoints + checkpoint_enable - delete_checkpoint_i);
            // When a free register is selected increment head
            head[version_head] <= trunc_free_list_ptr_sum(head[version_head] + read_enable);
            // Recompute number of free registers available. Note that the register we are reading only counts for the 
            // checkpoint in which we are right now 
            num_registers[version_head]  <= trunc_free_list_num_sum(num_registers[version_head]  + write_enable_0 + write_enable_1 - read_enable);

            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            //////// DO CHECKPOINT                                                                                /////////
            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

            // For checkpoint copy old free list in new. And copy pointers
            if (checkpoint_enable) begin
                version_head <= trunc_checkpoint_ptr_sum(version_head + checkpoint_enable);
                // Copy head position
                head[version_head_plus_one] <= trunc_free_list_ptr_sum(head[version_head] + read_enable);
                // Copy number of free registers.
                num_registers[version_head_plus_one]  <= trunc_free_list_num_sum(num_registers[version_head] + write_enable_0 + write_enable_1 - read_enable);
            end
        end
    end
end


assign new_register_o = (~read_enable)? 'h0 : ((num_registers[version_head] == 0) & (write_enable_0)) ? free_register_i[0] : ((num_registers[version_head] == 0) & (write_enable_1)) ? free_register_i[1] : register_table[head[version_head]];
assign empty_o = (num_registers[version_head] == 0) & ~write_enable_0 & ~write_enable_1;
assign out_of_checkpoints_o = (num_checkpoints == (NUM_CHECKPOINTS - 1));

endmodule
