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

// TODO: Add checkpointing to recover state fast.

//`default_nettype none
import drac_pkg::*;

// TODO: Define proper types in drac package. Define a phisical register and isa_register
// TODO: Edit register file width to 64 registers
typedef logic [REGFILE_WIDTH:0] phreg_t;
typedef reg [REGFILE_WIDTH-1:0] reg_free_list_entry;


// TODO: Define these constants and types in drac package
localparam NUM_CHECKPOINTS = 4;
typedef logic [$clog2(NUM_CHECKPOINTS)-1:0] checkpoint_ptr;

localparam NUM_ENTRIES = 32; // Number of entries in circular buffer

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

// Point to the head and tail of the fifo
reg_free_list_entry head;
reg_free_list_entry tail;

// Point to the actual version of free list
checkpoint_ptr version_head;
checkpoint_ptr version_tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(NUM_ENTRIES):0] num;

//Num must be 1 bit bigger than checkpoint pointer
logic [$clog2(NUM_CHECKPOINTS):0] num_checkpoints;


// Determines if is gonna be read or writen
logic write_enable;
logic read_enable;
logic checkpoint_enable;
logic recover_enable;

// User can do checkpoints when there is at least one free copy of the free list
assign checkpoint_enable = do_checkpoint_i & (num_checkpoints < (NUM_CHECKPOINTS - 1)) & (~do_recover_i);

// User can write to the tail of the buffer to add new register
assign write_enable = add_free_register_i & (num < NUM_ENTRIES) & (~do_recover_i);

// User can read the head of the buffer if there is any free register or 
// in this cycle a new register is written
assign read_enable = read_head_i & ((num > 0) | add_free_register_i) & (~do_recover_i);

`ifndef SRAM_MEMORIES

    // FIFO Memory structure

    phreg_t register_table [0:NUM_ENTRIES-1][0:NUM_CHECKPOINTS-1];

    always @(posedge clk_i, negedge rstn_i)
    begin
        integer i,j;
        if (~rstn_i) begin                                  // On reset clean first table
            version_head <= 2'b0;       // Control State
            num_checkpoints <= 3'b00;   // No checkpoints

            for(i = 0; i < NUM_ENTRIES ; i = i + 1) begin
               register_table[i][0] = i[5:0] + 6'b100000;
            end
        end
        else begin

            // On recovery, head points to old checkpoint. Do not rename next instruction.
            if (recover_enable) begin                    
                version_head <= recover_checkpoint_i;
                if (version_head > version_tail)    // Recompute number of checkpoints
                    num_checkpoints <= {1'b0, version_head} - {1'b0, version_tail};
                else 
                    num_checkpoints <= NUM_CHECKPOINTS - {1'b0,version_tail} + {1'b0,version_head};
                register_table[head][version_head] = register_table[head][version_head-1'b1];
            end
            else begin
                // Control State
                // Recompute number of checkpoints
                num_checkpoints <= num_checkpoints + {2'b0, checkpoint_enable} - {2'b0, delete_checkpoint_i};

                // On checkpoint first do checkpoint and then rename if needed
                if (checkpoint_enable) begin
                    version_head <= version_head + 2'b01;
                    register_table[head][version_head] = register_table[head][version_head-1'b1];
                end

                // Read first free register
                if (read_enable) begin
                    // Special case bypass from tail to head
                    if ((num == 0) & (add_free_register_i)) begin
                        new_register_o <= free_register_i; 
                    end else begin // Normal case lookup renaming table
                        new_register_o <= register_table[head][version_head];
                    end
                end else begin // When not reading an entry
                    new_register_o <= 6'h0;
                end
        
                // Write new freed register
                if (write_enable & ~(read_enable & num == 0)) begin
                    register_table[tail][version_head] <= free_register_i;
                end
            end
        end
    end

`else

`endif

// Control State
always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin       // On reset all entries are full and first copy is used
        head <= 5'b0;
        tail <= 5'b0;
        num  <= 6'b100000;
        version_tail <= 2'b0;
    end 
    else begin
        // When checkpoint is freed increment tail
        version_tail <= version_tail + {1'b0, delete_checkpoint_i};

        // When a free register is selected increment head
        head <= head + {4'b00, read_enable};
        // When a register is freed increment tail
        tail <= tail + {4'b00, write_enable};
        // Recompute number of free registers available.
        num  <= num  + {5'b0, write_enable} - {5'b0, read_enable};

    end
end

assign empty_o = (num == 0);
assign out_of_checkpoints_o = (num_checkpoints == (NUM_ENTRIES - 1));

endmodule
