/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : simd_rename_table.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Gerard Candón Arenas
 * Email(s)       : gcandon@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Gerard.CA   |  
 * -----------------------------------------------
 */

//`default_nettype none
import drac_pkg::*;
import riscv_pkg::*;

module simd_rename_table(
    input wire                        clk_i,               // Clock Singal
    input wire                        rstn_i,              // Negated Reset Signal

    input reg_t                       read_src1_i,         // Read source register 1 mapping
    input reg_t                       read_src2_i,         // Read source register 2 mapping
    input reg_t                       old_dst_i,           // Read and write to old destination register
    input logic                       write_dst_i,         // Needs to write to old destination register
    input phreg_t                     new_dst_i,           // Wich register write to old destination register

    input logic                       use_vs1_i,           // Instruction uses source vregister 1
    input logic                       use_vs2_i,           // Instruction uses source vregister 2
    input logic                       use_mask_i,          // Instruction uses source mask
    input logic                       use_old_vd_i,        // Instruction uses source old vd for masking

    input logic   [NUM_SIMD_WB-1:0]   ready_i,             // New register is ready
    input reg_t   [NUM_SIMD_WB-1:0]   vaddr_i,             // New register is ready
    input phreg_t [NUM_SIMD_WB-1:0]   paddr_i,             // New register is ready

    input logic                       recover_commit_i,    // Copy commit table on register table
    input reg_t [1:0]                 commit_old_dst_i,    // Read and write to old destination register at commit table
    input logic [1:0]                 commit_write_dst_i,  // Needs to write to old destination register at commit table
    input phreg_t [1:0]               commit_new_dst_i,    // Wich register write to old destination register at commit table

    input wire                        do_checkpoint_i,     // After renaming do a checkpoint
    input wire                        do_recover_i,        // Recover a checkpoint
    input wire                        delete_checkpoint_i, // Delete tail checkpoint
    input checkpoint_ptr              recover_checkpoint_i,// Label of the checkpoint to recover  

    output phreg_t                    src1_o,              // Read source register 1 mapping
    output logic                      rdy1_o,              // Ready source register 1
    output phreg_t                    src2_o,              // Read source register 2 mapping
    output logic                      rdy2_o,              // Ready source register 2
    output phreg_t                    srcm_o,              // Read source register mask mapping
    output logic                      rdym_o,              // Ready source register mask
    output phreg_t                    old_dst_o,           // Read destination register mapping
    output logic                      rdy_old_dst_o,       // Ready old dst

    output checkpoint_ptr             checkpoint_o,        // Label of checkpoint
    output wire                       out_of_checkpoints_o // No more checkpoints
);

// Point to the actual version of free list
checkpoint_ptr version_head;
checkpoint_ptr version_tail;

//Num must be 1 bit bigger than checkpoint pointer
logic [$clog2(NUM_CHECKPOINTS):0] num_checkpoints;

logic write_enable;
logic read_enable;
logic checkpoint_enable;
logic commit_write_enable_0;
logic commit_write_enable_1;
logic [NUM_SIMD_WB-1:0] ready_enable;
logic [NUM_SIMD_WB-1:0] rdy1;
logic [NUM_SIMD_WB-1:0] rdy2;
logic [NUM_SIMD_WB-1:0] rdym;
logic [NUM_SIMD_WB-1:0] rdy_old_dst;

// User can do checkpoints when there is at least one free copy of the free list
assign checkpoint_enable = do_checkpoint_i & (num_checkpoints < (NUM_CHECKPOINTS - 1)) & (~do_recover_i) & (~recover_commit_i);

// User can write to table to add new destination register
//assign write_enable = write_dst_i & (~do_recover_i) & (old_dst_i != 5'h0) & (~recover_commit_i);
assign write_enable = write_dst_i & (~do_recover_i) & (~recover_commit_i);

// User can wirte to commit table to add new destination register
//assign commit_write_enable = commit_write_dst_i & (commit_old_dst_i != 5'h0) & (~recover_commit_i);
assign commit_write_enable_0 = commit_write_dst_i[0] & (~recover_commit_i);
assign commit_write_enable_1 = commit_write_dst_i[1] & (~recover_commit_i);

// User can read the table if no recover action is being done
assign read_enable = (~do_recover_i) & (~recover_commit_i);

// User can mark registers as ready if no recover action is being done
// Multiple registers can be marked as ready
always_comb begin
    for (int i = 0; i<NUM_SIMD_WB; ++i) begin
        ready_enable[i] = ready_i[i] &  (~recover_commit_i);
    end
end

    // Look up table
    logic ready_table [0:NUM_ISA_VREGISTERS-1][0:NUM_CHECKPOINTS-1];
    phreg_t register_table [0:NUM_ISA_VREGISTERS-1][0:NUM_CHECKPOINTS-1];
    phreg_t commit_table   [0:NUM_ISA_VREGISTERS-1];

    always_ff @(posedge clk_i, negedge rstn_i) 
    begin
        if(~rstn_i) begin

            // Table initial state
            for (integer j = 0; j < NUM_ISA_VREGISTERS; j++) begin
                register_table[j][0] <= j[5:0];
                ready_table[j][0] <= 1'b1;
                commit_table[j] <= j[5:0];
            end
            // Checkpoint signals
            version_head <= 2'b0;       // Current table, 0
            num_checkpoints <= 3'b00;   // No checkpoints
            version_tail <= 2'b0;       // Last reserved table 0

            // Output signals
            src1_o <= 0;
            src2_o <= 0;
            srcm_o <= 0;
            old_dst_o <= 0;                     
        end 
        else if (recover_commit_i) begin // Recover commit table because exception
            for (integer j = 0; j < NUM_ISA_VREGISTERS; j++) begin
                register_table[j][0] <= commit_table[j];
                ready_table[j][0] <= 1'b1;
            end
            version_head <= 2'b0;       // Current table, 0
            num_checkpoints <= 3'b00;   // No checkpoints
            version_tail <= 2'b0;       // Last reserved table 0

            // Output signals
            src1_o <= 0;
            src2_o <= 0;
            srcm_o <= 0;
            old_dst_o <= 0;  
            checkpoint_o <= 0;
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

                // Recompute number of checkpoints
                num_checkpoints <= num_checkpoints + {2'b0, checkpoint_enable} - {2'b0, delete_checkpoint_i};

                // On checkpoint first do checkpoint and then rename if needed
                // For checkpoint advance pointers
                if (checkpoint_enable) begin
                    for (int i=0; i<NUM_ISA_VREGISTERS; i++) begin
                        register_table[i][version_head + 2'b1] <= register_table[i][version_head];
                        ready_table[i][version_head + 2'b1] <= ready_table[i][version_head];
                    end
                    version_head <= version_head + 2'b01;

                    if (write_enable) begin
                        register_table[old_dst_i][version_head + 2'b1] <= new_dst_i;
                        ready_table[old_dst_i][version_head + 2'b1] <= 1'b0;
                    end
                end

                // Second register renaming
                if (read_enable) begin
                    for (int i = 0; i<NUM_SIMD_WB; ++i) begin
                        rdy1[i] = ready_i[i] & (read_src1_i == vaddr_i[i]) & (register_table[read_src1_i][version_head] == paddr_i[i]);
                        rdy2[i] = ready_i[i] & (read_src2_i == vaddr_i[i]) & (register_table[read_src2_i][version_head] == paddr_i[i]);
                        rdym[i] = ready_i[i] & (0 == vaddr_i[i]) & (register_table[0][version_head] == paddr_i[i]);
                        rdy_old_dst[i] = ready_i[i] & (old_dst_i == vaddr_i[i]) & (register_table[old_dst_i][version_head] == paddr_i[i]);
                    end

                    src1_o <= register_table[read_src1_i][version_head];
                    rdy1_o <= ready_table[read_src1_i][version_head] | (|rdy1) | (~use_vs1_i);
                    src2_o <= register_table[read_src2_i][version_head];
                    rdy2_o <= ready_table[read_src2_i][version_head] | (|rdy2) | (~use_vs2_i);
                    srcm_o <= register_table[0][version_head];
                    rdym_o <= ready_table[0][version_head] | (|rdym) | (~use_mask_i);
                    old_dst_o <= register_table[old_dst_i][version_head];
                    rdy_old_dst_o <= ready_table[old_dst_i][version_head] | (|rdy_old_dst) | (~use_old_vd_i);
                end

                // Third write new destination register
                if (write_enable) begin
                    register_table[old_dst_i][version_head] <= new_dst_i;
                    ready_table[old_dst_i][version_head] <= 1'b0;
                end
            end

            // Update commit table
            if (commit_write_enable_0 & !commit_write_enable_1) begin
                commit_table[commit_old_dst_i[0]] <= commit_new_dst_i[0];
            end else if (commit_write_enable_0 & commit_write_enable_1 & commit_old_dst_i[0] == commit_old_dst_i[1]) begin
                commit_table[commit_old_dst_i[1]] <= commit_new_dst_i[1];
            end else if (commit_write_enable_0 & commit_write_enable_1 & commit_old_dst_i[0] != commit_old_dst_i[1]) begin
                commit_table[commit_old_dst_i[0]] <= commit_new_dst_i[0];
                commit_table[commit_old_dst_i[1]] <= commit_new_dst_i[1];
            end else if (!commit_write_enable_0 & commit_write_enable_1) begin
                commit_table[commit_old_dst_i[1]] <= commit_new_dst_i[1];
            end

            // Write new ready register
            for (int i = 0; i<NUM_SIMD_WB; ++i) begin
                if (ready_enable[i]) begin
                    for(int j = 0; j<NUM_CHECKPOINTS; j++) begin
                        if (~checkpoint_enable | (checkpoint_ptr'(j) != (version_head + 2'b1))) begin
                            if ((register_table[vaddr_i[i]][j] == paddr_i[i]) & ~(write_enable & (vaddr_i[i] == old_dst_i) & (checkpoint_ptr'(j) == version_head) )) 
                                ready_table[vaddr_i[i]][j] <= 1'b1;
                        end else if((checkpoint_enable & register_table[vaddr_i[i]][version_head] == paddr_i[i]) & ~(write_enable & (vaddr_i[i] == old_dst_i))) begin
                            ready_table[vaddr_i[i]][version_head + 2'b1] <= 1'b1;
                        end
                    end
                end
            end
            checkpoint_o <= version_head;
        end
    end

assign out_of_checkpoints_o = (num_checkpoints == (NUM_CHECKPOINTS - 1));

endmodule
