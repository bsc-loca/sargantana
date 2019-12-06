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

localparam NUM_ENTRIES_FREE_LIST = NUM_PHISICAL_REGISTERS - NUM_ISA_REGISTERS - 1; // Number of entries in circular buffer

// Free list Pointer
typedef reg [$clog2(NUM_ENTRIES_FREE_LIST)-1:0] reg_free_list_entry;

module free_list(
    input wire             clk_i,               // Clock Singal
    input wire             rstn_i,              // Negated Reset Signal
    input wire             read_head_i,         // Read tail of the ciruclar buffer
    input wire             add_free_register_i, // Add new free register
    input phreg_t          free_register_i,     // Register to be freed

    input wire             do_checkpoint_i,     // After renaming do a checkpoint
    input wire             do_recover_i,        // Recover a checkpoint
    input wire             delete_checkpoint_i, // Delete tail checkpoint
    input checkpoint_ptr   recover_checkpoint_i,// Label of the checkpoint to recover   

    output phreg_t         new_register_o,      // First free register
    output checkpoint_ptr  checkpoint_o,        // Label of the checkpoint done. Use in case of recovery.
    output logic           out_of_checkpoints_o,// Indicates if user is able to do more checkpoints.
    output logic           empty_o              // Free list is empty
);

// Point to the head and tail of the fifo. One pointer for each checkpoint
reg_free_list_entry head [0:NUM_CHECKPOINTS-1];
reg_free_list_entry tail [0:NUM_CHECKPOINTS-1];

// Point to the actual version of free list
checkpoint_ptr version_head;
checkpoint_ptr version_tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(NUM_ENTRIES_FREE_LIST+1):0] num [0:NUM_CHECKPOINTS-1];

//Num must be 1 bit bigger than checkpoint pointer
logic [$clog2(NUM_CHECKPOINTS):0] num_checkpoints;

// Determines if is gonna be read or writen
logic write_enable;
logic read_enable;
logic checkpoint_enable;

// User can do checkpoints when there is at least one free copy of the free list
assign checkpoint_enable = do_checkpoint_i & (num_checkpoints < (NUM_CHECKPOINTS - 1)) & (~do_recover_i);

// User can write to the tail of the buffer to add new register
assign write_enable = add_free_register_i & (num[version_head] < NUM_ENTRIES_FREE_LIST[5:0]) & (~do_recover_i);

// User can read the head of the buffer if there is any free register or 
// in this cycle a new register is written
assign read_enable = read_head_i & ((num[version_head] > 0) | add_free_register_i) & (~do_recover_i);

`ifndef SRAM_MEMORIES

    // FIFO Memory structure

    phreg_t first_free_register[0:NUM_CHECKPOINTS-1];       // Register used to read asyncronously
    phreg_t register_table [0:NUM_ENTRIES_FREE_LIST-1][0:NUM_CHECKPOINTS-1];    // SRAM used to store the restant free register. Read syncronous.

    always_ff @(posedge clk_i, negedge rstn_i)
    begin
        integer i,j;
        if (~rstn_i) begin              // On reset clean first table
            version_head <= 2'b0;       // Current table, 0
            num_checkpoints <= 3'b00;   // No checkpoints
            version_tail <= 2'b0;       // Last reserved table 0
            head[0] <= 5'b0;            // Current head in position 0
            tail[0] <= 5'b0;            // Current tail in position 0 
            num[0]  <= 6'b100000;       // Number of free registers 32

            checkpoint_o <= 2'b0;       // Label 00 not XX

            first_free_register[0] <= 6'b100000;

            for(i = 0; i < NUM_ENTRIES_FREE_LIST ; i = i + 1) begin
               register_table[i][0] = i[5:0] + 6'b100001;
            end
        end
        else begin
            // When checkpoint is freed increment tail
            version_tail <= version_tail + {1'b0, delete_checkpoint_i};

            // On recovery, head points to old checkpoint. Do not rename next instruction.
            if (do_recover_i) begin                    
                version_head <= recover_checkpoint_i;
                if (recover_checkpoint_i >= version_tail)    // Recompute number of checkpoints
                    num_checkpoints <= {1'b0, recover_checkpoint_i} - {1'b0, version_tail};
                else 
                    num_checkpoints <= NUM_CHECKPOINTS - {1'b0, version_tail} + {1'b0, recover_checkpoint_i};
            end
            else begin

                // On checkpoint first do checkpoint and then rename if needed
                // For checkpoint copy old free list in new. And copy pointers      //TODO: Do checkpoint, read and write. All at same time
                if (checkpoint_enable) begin
                    for (int i=0; i<NUM_ENTRIES_FREE_LIST; i++)
                        register_table[i][version_head + 2'b01] <= register_table[i][version_head];
                    first_free_register[version_head + 2'b01] <= first_free_register[version_head];

                    head[version_head + 2'b01] <= head[version_head];
                    tail[version_head + 2'b01] <= tail[version_head];
                    num [version_head + 2'b01] <= num [version_head];
                    checkpoint_o <= version_head;
                    version_head <= version_head + 2'b01;
                end

                // Control State
                // Recompute number of checkpoints
                num_checkpoints <= num_checkpoints + {2'b0, checkpoint_enable} - {2'b0, delete_checkpoint_i};
                // When a free register is selected increment head
                head[version_head] <= head[version_head] + {4'b00, read_enable};
                // When a register is freed increment tail
                tail[version_head] <= tail[version_head] + {4'b00, write_enable};
                // Recompute number of free registers available.
                num[version_head]  <= num[version_head]  + {5'b0, write_enable} - {5'b0, read_enable};


                // Write to first free register
                if (read_enable & (num[version_head] >= 1)) begin
                    first_free_register[version_head] <= register_table[head[version_head]][version_head];
                end

                if (write_enable & (num[version_head] == 0) & (~read_enable)) begin
                    first_free_register[version_head] <= free_register_i; 
                end
        
                // Write new freed register
                if (write_enable & (num[version_head] >= 1) & ~(read_enable & num[version_head] == 0)) begin
                    register_table[tail[version_head]][version_head] <= free_register_i;
                end
            end
        end
    end

`else

`endif

assign new_register_o = (~read_enable)? 6'h0 : ((num[version_head] == 0) & (add_free_register_i))? free_register_i : first_free_register[version_head];

assign empty_o = (num[version_head] == 0);
assign out_of_checkpoints_o = (num_checkpoints == (NUM_CHECKPOINTS - 1));

endmodule
