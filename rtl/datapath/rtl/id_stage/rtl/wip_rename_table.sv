/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : rename.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Victor.SP   |  
 * -----------------------------------------------
 */

localparam NUM_ISA_REGISTERS = 32;

//`default_nettype none
import drac_pkg::*;

// TODO: Define proper types in drac package. Define a phisical register and isa_register
// TODO: Edit register file width to 64 registers
typedef logic [REGFILE_WIDTH:0] phreg_t;
typedef reg [REGFILE_WIDTH-1:0] reg_free_list_entry;

// TODO: Define these constants and types in drac package
localparam NUM_CHECKPOINTS = 4;
typedef logic [$clog2(NUM_CHECKPOINTS)-1:0] checkpoint_ptr;

module rename_table(
    input wire             clk_i,               // Clock Singal
    input wire             rstn_i,              // Negated Reset Signal

    input reg_t            read_src1_i,         // Read source register 1 mapping
    input reg_t            read_src2_i,         // Read source register 2 mapping
    input reg_t            old_dst_i,           // Read and write to old destination register
    input logic            write_dst_i,         // Needs to write to old destination register
    input phreg_t          new_dst_i,           // Wich register write to old destination register

    input wire             do_checkpoint_i,     // After renaming do a checkpoint
    input wire             do_recover_i,        // Recover a checkpoint
    input wire             delete_checkpoint_i, // Delete tail checkpoint
    input checkpoint_ptr   recover_checkpoint_i,// Label of the checkpoint to recover  

    output phreg_t         src1_o,              // Read source register 1 mapping
    output phreg_t         src2_o,              // Read source register 2 mapping
    output phreg_t         old_dst_o,           // Read destination register mapping

    output checkpoint_ptr  checkpoint_o,        // Label of checkpoint
    output wire            out_of_checkpoints_o // No more checkpoints
);

// Point to the actual version of free list
checkpoint_ptr version_head;
checkpoint_ptr version_tail;

//Num must be 1 bit bigger than checkpoint pointer
logic [$clog2(NUM_CHECKPOINTS):0] num_checkpoints;

logic write_enable;
logic read_enable;
logic checkpoint_enable;

// User can do checkpoints when there is at least one free copy of the free list
assign checkpoint_enable = do_checkpoint_i & (num_checkpoints < (NUM_CHECKPOINTS - 1)) & (~do_recover_i);

// User can write to table to add new destination register
assign write_enable = write_dst_i & (~do_recover_i);

// User can read the table if no recover action is being done
assign read_enable = (~do_recover_i);

`ifndef SRAM_MEMORIES

    // Look up table

    phreg_t register_table [0:NUM_ISA_REGISTERS-1][0:NUM_CHECKPOINTS-1];

    always_ff @(posedge clk_i, negedge rstn_i) 
    begin
        if(~rstn_i) begin

            // Table initial state
            for (integer j = 0; j < NUM_ISA_REGISTERS; j++) begin
                register_table[j][0] = j[5:0];
            end
            // Checkpoint signals
            version_head <= 2'b0;       // Current table, 0
            num_checkpoints <= 3'b00;   // No checkpoints
            version_tail <= 2'b0;       // Last reserved table 0
            checkpoint_o <= 2'b0;       // Label 00 not XX

            // Output signals
            src1_o <= 0;
            src2_o <= 0;
            old_dst_o <= 0;                              // TODO: CUIDADO PUEDE LIBERAR EL REG 0
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
                // For checkpoint advance pointers
                if (checkpoint_enable) begin
                    for (int i=0; i<NUM_ISA_REGISTERS; i++)
                        register_table[i][version_head] <= register_table[i][version_head -  2'b01];
                    checkpoint_o <= version_head;
                    version_head <= version_head + 2'b01;
                end

                // Second register renaming
                if (read_enable) begin
                    src1_o <= register_table[read_src1_i][version_head];
                    src2_o <= register_table[read_src2_i][version_head];
                    old_dst_o <= register_table[old_dst_i][version_head];
                end

                // Third write new destination register
                if (read_enable) begin
                    register_table[old_dst_i][version_head] <= new_dst_i;
                end
            end
        end
    end

`endif

assign out_of_checkpoints_o = (num_checkpoints == (NUM_CHECKPOINTS - 1));

endmodule
