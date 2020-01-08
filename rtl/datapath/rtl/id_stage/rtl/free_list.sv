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

//`default_nettype none
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

    input wire             commit_read_head_i,  // Read head of the circular buffer in commit stage
    input wire             commit_roll_back_i,  // Free on fly register because of exception

    output phreg_t         new_register_o,      // First free register
    output checkpoint_ptr  checkpoint_o,        // Label of the checkpoint done. Use in case of recovery.
    output logic           out_of_checkpoints_o,// Indicates if user is able to do more checkpoints.
    output logic           empty_o              // Free list is empty
);

// Iteration variable


// Point to the head and tail of the fifo. One pointer for each checkpoint
reg_free_list_entry head [0:NUM_CHECKPOINTS-1];
reg_free_list_entry tail;

// Point to the head of the fifo. Non-speculative. Used to recover free list state at exception
reg_free_list_entry commit_head;

// Point to the actual version of free list
checkpoint_ptr version_head;
checkpoint_ptr version_tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(NUM_ENTRIES_FREE_LIST):0] num [0:NUM_CHECKPOINTS-1];

//Num must be 1 bit bigger than checkpoint pointer
logic [$clog2(NUM_CHECKPOINTS):0] num_checkpoints;

// Determines if is gonna be read or writen
logic write_enable;
logic read_enable;
logic checkpoint_enable;
logic commit_read_enable;

// User can do checkpoints when there is at least one free copy of the free list
assign checkpoint_enable = do_checkpoint_i & (num_checkpoints < (NUM_CHECKPOINTS - 1)) & (~do_recover_i) & (~commit_roll_back_i);

// User can write to the free list a new free register
// Freed register should be written to all checkpoints
// It cannot overflow the buffer. It cannot be done when recovering an old checkpoint.
// It cannot free register 0
assign write_enable = (add_free_register_i) & (free_register_i != 6'h0) & (~commit_roll_back_i);

// User can read the head of the buffer if there is any free register or 
// in this cycle a new register is written
assign read_enable = read_head_i & ((num[version_head] > 0) | write_enable) & (~do_recover_i) & (~commit_roll_back_i);

// Advance read head at commit stage
assign commit_read_enable = commit_read_head_i & (~commit_roll_back_i);

`ifndef SRAM_MEMORIES

    // FIFO Memory structure

    phreg_t first_free_register[0:NUM_CHECKPOINTS-1];       // Register used to read asyncronously
    phreg_t register_table [0:NUM_ENTRIES_FREE_LIST-1];    // SRAM used to store the restant free register. Read syncronous.

    always_ff @(posedge clk_i, negedge rstn_i)
    begin
        integer i;
        if (~rstn_i) begin              // On reset clean first table
            version_head <= 2'b0;       // Current table, 0
            num_checkpoints <= 3'b00;   // No checkpoints
            version_tail <= 2'b0;       // Last reserved table 0
            head[0] <= 5'b1;            // Current head in position 1
            tail    <= 5'b0;            // Current tail in position 0 
            num[0]  <= 6'b100000;       // Number of free registers 32
            commit_head <= 5'b0;        // Current commit position 0

            first_free_register[0] <= 6'b100000;

            for(i = 0; i < NUM_ENTRIES_FREE_LIST ; i = i + 1) begin
               register_table[i] = i[5:0] + 6'b100000;
            end
        end
        else if (commit_roll_back_i) begin
            version_head <= 2'b0;          // Current table, 0
            num_checkpoints <= 3'b00;      // No checkpoints
            version_tail <= 2'b0;          // Last reserved table 0
            head[0] <= commit_head + 5'b1; // Current head in position 1
            num[0]  <= 6'b100000;          // Number of free registers 32

            first_free_register[0] <= register_table[commit_head];
            checkpoint_o <= 0;
        end
        else begin
            // When checkpoint is freed increment tail
            version_tail <= version_tail + {1'b0, delete_checkpoint_i};


            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            //////// WRITES FREED REGISTER                                                                        /////////
            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

            // Write new freed register to old checkpoints
            for(i = 0; i < NUM_CHECKPOINTS; i++) begin
               // Case write to first free register
               if (write_enable & (num[i] == 0)) begin
                   first_free_register[i] <= free_register_i; 
               end
            end

            // Case write to free list queue 
            if (write_enable) begin
                register_table[tail] <= free_register_i;
            end


            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            //////// UPDATE CONTROL SIGNALS                                                                       /////////
            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

            // When a register is freed increment tail
            tail <= tail + {4'b00, write_enable};
            // Recompute number of free registers available.
            for(i = 0; i < NUM_CHECKPOINTS; i++) begin
                num[i]  <= num[i]  + {5'b0, write_enable};
            end
            checkpoint_o <= version_head;

            // Update commit head 
            commit_head <= commit_head + {4'b0, commit_read_enable};

            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            //////// RECOVER OLD CHECKPOINT                                                                       /////////
            ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            if (do_recover_i) begin                  

                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                //////// UPDATE CONTROL SIGNALS                                                                       /////////
                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////  

                version_head <= recover_checkpoint_i;
                if (recover_checkpoint_i >= version_tail)    // Recompute number of checkpoints
                    num_checkpoints <= {1'b0, recover_checkpoint_i} - {1'b0, version_tail};
                else 
                    num_checkpoints <= NUM_CHECKPOINTS - {1'b0, version_tail} + {1'b0, recover_checkpoint_i};

            end
            else begin


                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                //////// WRITES FREED REGISTER                                                                        /////////
                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

                // Write new freed register to head checkpoint to first_free_register
                if (write_enable & ((num[version_head] == 0) | ((num[version_head] == 1) & read_enable))) begin
                    first_free_register[version_head] <= free_register_i; 
                end

                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                //////// READS FIRST FREE REGISTER                                                                    /////////
                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

                // In case of read free register. Write to first free register the head of the free list
                if (read_enable & (num[version_head] > 1)) begin
                    first_free_register[version_head] <= register_table[head[version_head]];
                end

                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                //////// UPDATE CONTROL SIGNALS                                                                       /////////
                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

                // Recompute number of checkpoints
                num_checkpoints <= num_checkpoints + {2'b0, checkpoint_enable} - {2'b0, delete_checkpoint_i};
                // When a free register is selected increment head
                head[version_head] <= head[version_head] + {4'b00, read_enable};
                // Recompute number of free registers available.
                num[version_head]  <= num[version_head]  + {5'b0, write_enable} - {5'b0, read_enable};

                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                //////// DO CHECKPOINT                                                                                /////////
                ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

                // For checkpoint copy old free list in new. And copy pointers
                if (checkpoint_enable) begin
                    first_free_register[version_head + 2'b01] <= first_free_register[version_head];
                    version_head <= version_head + 2'b01;

                    // Copy Write to first free register
                    if (read_enable & (num[version_head] >= 1)) begin
                        first_free_register[version_head + 2'b01] <= register_table[head[version_head]];
                    end

                    // Copy Write new freed register to new checkpoints
                    if (write_enable & (num[version_head] == 0)) begin
                        first_free_register[version_head + 2'b01] <= free_register_i; 
                    end

                    // Control State.
                    // Copy head
                    head[version_head + 2'b01] <= head[version_head] + {4'b00, read_enable};
                    // Copy number of free registers.
                    num[version_head + 2'b01]  <= num[version_head]  + {5'b0, write_enable} - {5'b0, read_enable};
                end
            end
        end
    end

`else

`endif

assign new_register_o = (~read_enable)? 6'h0 : ((num[version_head] == 0) & (write_enable))? free_register_i : first_free_register[version_head];
assign empty_o = (num[version_head] == 0) & (~write_enable);
assign out_of_checkpoints_o = (num_checkpoints == (NUM_CHECKPOINTS - 1));

endmodule
