/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : free_list.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Victor.SP   |  
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

localparam NUM_ENTRIES_FREE_LIST = NUM_PHISICAL_REGISTERS - NUM_ISA_REGISTERS; // Number of entries in circular buffer

// Free list Pointer
typedef reg [$clog2(NUM_ENTRIES_FREE_LIST)-1:0] reg_free_list_entry;

module free_list(
    input wire             clk_i,               // Clock Singal
    input wire             rstn_i,              // Negated Reset Signal
    input wire             read_head_i,         // Read head of the circular buffer
    input wire             add_free_register_i, // Add new free register
    input phreg_t          free_register_i,     // Register to be freed

    input wire             do_checkpoint_i,     // After renaming do a checkpoint
    input wire             do_recover_i,        // Recover a checkpoint
    input wire             delete_checkpoint_i, // Delete tail checkpoint
    input checkpoint_ptr   recover_checkpoint_i,// Label of the checkpoint to recover or the checkpoint of the freed register
    input wire             commit_roll_back_i,  // Free on fly register because of exception

    output phreg_t         new_register_o,      // First free register
    output checkpoint_ptr  checkpoint_o,        // Label of the checkpoint done. Use in case of recovery.
    output logic           out_of_checkpoints_o,// Indicates if user is able to do more checkpoints.
    output logic           empty_o              // Free list is empty
);

// Point to the head and tail of the fifo. One pointer for each checkpoint
reg_free_list_entry head [0:NUM_CHECKPOINTS-1];
reg_free_list_entry tail;

// Point to the actual version of free list
checkpoint_ptr version_head;
checkpoint_ptr version_tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(NUM_ENTRIES_FREE_LIST):0] num_registers [0:NUM_CHECKPOINTS-1];

//Num must be 1 bit bigger than checkpoint pointer
logic [$clog2(NUM_CHECKPOINTS):0] num_checkpoints;

// Determines if is gonna be read or writen
logic write_enable;
logic read_enable;
logic checkpoint_enable;

// Internal signal to do checkpoints 
// User can do checkpoints when there is at least one free copy of the free list
// And there is not an ongoing recover
assign checkpoint_enable = do_checkpoint_i & (num_checkpoints < (NUM_CHECKPOINTS - 1)) & (~do_recover_i) & (~commit_roll_back_i);

// User can write to the free list a new free register
// Freed register should be written to all checkpoints
// It cannot overflow the buffer. It cannot be done when recovering an old checkpoint.
// It cannot free register 0
assign write_enable = (add_free_register_i) & (free_register_i != 6'h0) & (~commit_roll_back_i);

// User can read the head of the buffer if there is any free register or 
// in this cycle a new register is written
assign read_enable = read_head_i & ((num_registers[version_head] > 0) | write_enable) & (~do_recover_i) & (~commit_roll_back_i);


// FIFO Memory structure
phreg_t register_table [0:NUM_ENTRIES_FREE_LIST-1];    // SRAM used to store the free registers. Read syncronous.

always_ff @(posedge clk_i, negedge rstn_i)
begin
    integer i;
    if (~rstn_i) begin                  // On reset clean first table
        version_head <= 'b0;            // Current head pointer
        num_checkpoints <= 'b0;         // No checkpoints
        version_tail <= 'b0;            // Last reserved pointer
        head[0] <= 'b0;                 // Current head in position 
        tail    <= 'b0;                 // Current tail in position  
        num_registers[0]  <= 6'b100000; // Number of free registers 32

        for(i = 0; i < NUM_ENTRIES_FREE_LIST ; i = i + 1) begin
            register_table[i] = i[5:0] + 6'b100000;
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
        version_tail <= version_tail + delete_checkpoint_i;

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //////// WRITES FREED REGISTER                                                                        /////////
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////


        if (write_enable) begin
            register_table[tail] <= free_register_i;
        end

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //////// UPDATE CONTROL SIGNALS                                                                       /////////
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

        // When a register is freed increment tail
        tail <= tail + write_enable;
        
        // Recompute number of free registers available.
        for(i = 0; i < NUM_CHECKPOINTS; i++) begin
            num_registers[i]  <= num_registers[i]  + write_enable;
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
            num_checkpoints <= num_checkpoints + checkpoint_enable - delete_checkpoint_i;
            // When a free register is selected increment head
            head[version_head] <= head[version_head] + read_enable;
            // Recompute number of free registers available. Note that the register we are reading only counts for the 
            // checkpoint in which we are right now 
            num_registers[version_head]  <= num_registers[version_head]  + write_enable - read_enable;

            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            //////// DO CHECKPOINT                                                                                /////////
            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

            // For checkpoint copy old free list in new. And copy pointers
            if (checkpoint_enable) begin
                version_head <= version_head + checkpoint_enable;
                // Copy head position
                head[version_head + 'b1] <= head[version_head] + read_enable;
                // Copy number of free registers.
                num_registers[version_head + 1'b1]  <= num_registers[version_head]  + write_enable - read_enable;
            end
        end
    end
end


assign new_register_o = (~read_enable)? 'h0 : ((num_registers[version_head] == 0) & (write_enable))? free_register_i : register_table[head[version_head]];
assign empty_o = (num_registers[version_head] == 0) & (~write_enable);
assign out_of_checkpoints_o = (num_checkpoints == (NUM_CHECKPOINTS - 1));

endmodule
