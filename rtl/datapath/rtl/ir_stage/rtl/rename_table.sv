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

//`default_nettype none

module rename_table
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input wire                        clk_i,               // Clock Singal
    input wire                        rstn_i,              // Negated Reset Signal

    input reg_t                       read_src1_i,         // Read source register 1 mapping
    input reg_t                       read_src2_i,         // Read source register 2 mapping
    input reg_t                       old_dst_i,           // Read and write to old destination register
    input logic                       write_dst_i,         // Needs to write to old destination register
    input phreg_t                     new_dst_i,           // Wich register write to old destination register

    input logic                       use_rs1_i,           // Instruction uses source register 1
    input logic                       use_rs2_i,           // Instruction uses source register 2

    input logic   [NUM_SCALAR_WB-1:0] ready_i,             // New register is ready
    input reg_t   [NUM_SCALAR_WB-1:0] vaddr_i,             // New register is ready
    input phreg_t [NUM_SCALAR_WB-1:0] paddr_i,             // New register is ready

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
    output phreg_t                    old_dst_o,           // Read destination register mapping

    output checkpoint_ptr             checkpoint_o,        // Label of checkpoint
    output wire                       out_of_checkpoints_o // No more checkpoints
);

// Point to the actual version of free list
checkpoint_ptr version_head_q, version_head_d;
checkpoint_ptr version_head_nxt;
checkpoint_ptr version_tail_q, version_tail_d;

//Num must be 1 bit bigger than checkpoint pointer
logic [$clog2(NUM_CHECKPOINTS):0] num_checkpoints_q, num_checkpoints_d;

logic write_enable;
logic read_enable;
logic checkpoint_enable;
logic commit_write_enable_0;
logic commit_write_enable_1;
logic [NUM_SCALAR_WB-1:0] ready_enable;
logic [NUM_SCALAR_WB-1:0] rdy1;
logic [NUM_SCALAR_WB-1:0] rdy2;

// User can do checkpoints when there is at least one free copy of the free list
assign checkpoint_enable = do_checkpoint_i & (num_checkpoints_q < (NUM_CHECKPOINTS - 1)) & (~do_recover_i) & (~recover_commit_i);

// User can write to table to add new destination register
assign write_enable = write_dst_i & (~do_recover_i) & (old_dst_i != 5'h0) & (~recover_commit_i);

// User can wirte to commit table to add new destination register
assign commit_write_enable_0 = commit_write_dst_i[0] & (commit_old_dst_i[0] != 5'h0) & (~recover_commit_i);
assign commit_write_enable_1 = commit_write_dst_i[1] & (commit_old_dst_i[1] != 5'h0) & (~recover_commit_i);

// User can read the table if no recover action is being done
assign read_enable = (~do_recover_i) & (~recover_commit_i);

// User can mark registers as ready if no recover action is being done
// Multiple register can be marked as ready
always_comb begin
    for (int i = 0; i<NUM_SCALAR_WB; ++i) begin
        ready_enable[i] = ready_i[i] &  (~recover_commit_i);
    end
end


// Look up table. Not for r0
logic  ready_table_d [NUM_ISA_REGISTERS-1:0][NUM_CHECKPOINTS-1:0];
phreg_t  register_table_d [NUM_ISA_REGISTERS-1:0][NUM_CHECKPOINTS-1:0];
phreg_t  commit_table_d   [NUM_ISA_REGISTERS-1:0];

logic ready_table_q [NUM_ISA_REGISTERS-1:0][NUM_CHECKPOINTS-1:0];
phreg_t register_table_q [NUM_ISA_REGISTERS-1:0][NUM_CHECKPOINTS-1:0];
phreg_t commit_table_q   [NUM_ISA_REGISTERS-1:0];

always_comb begin
    register_table_d  = register_table_q;
    ready_table_d     = ready_table_q;
    commit_table_d    = commit_table_q;
    version_head_d    = version_head_q;       
    num_checkpoints_d = num_checkpoints_q;
    version_head_nxt  = version_head_q + 2'b1;
    if (recover_commit_i) begin // Recover commit table because exception
        for (integer j = 0; j < NUM_ISA_REGISTERS; j++) begin
            register_table_d[j][0] = commit_table_q[j];
            ready_table_d[j][0] = 1'b1;
        end
        version_head_d = 2'b0;       // Current table, 0
        num_checkpoints_d = 3'b00;   // No checkpoints
        version_tail_d = 2'b0;       // Last reserved table 0

    end 
    else begin

        // When checkpoint is freed increment tail
        version_tail_d = version_tail_q + {1'b0, delete_checkpoint_i};

        // On recovery, head points to old checkpoint. Do not rename next instruction.
        if (do_recover_i) begin                    
            version_head_d = recover_checkpoint_i;
            if (recover_checkpoint_i >= version_tail_q)    // Recompute number of checkpoints
                num_checkpoints_d = {1'b0, recover_checkpoint_i} - {1'b0, version_tail_q};
            else 
                num_checkpoints_d = NUM_CHECKPOINTS - {1'b0, version_tail_q} + {1'b0, recover_checkpoint_i};
            end
        else begin

            // Recompute number of checkpoints
            num_checkpoints_d = num_checkpoints_q + {2'b0, checkpoint_enable} - {2'b0, delete_checkpoint_i};

            // On checkpoint first do checkpoint and then rename if needed
            // For checkpoint advance pointers
            if (checkpoint_enable) begin
                for (int i=0; i < NUM_ISA_REGISTERS; i++) begin
                    register_table_d[i][version_head_nxt] = register_table_q[i][version_head_q];
                    ready_table_d[i][version_head_nxt] = ready_table_q[i][version_head_q];
                end
                version_head_d = version_head_q + 2'b01;

                if (write_enable) begin
                    register_table_d[old_dst_i][version_head_nxt] = new_dst_i;
                    ready_table_d[old_dst_i][version_head_nxt] = 1'b0;
                    register_table_d[old_dst_i][version_head_q] = new_dst_i;
                    ready_table_d[old_dst_i][version_head_q] = 1'b0;
                end
            end else begin
                // Third write new destination register
                if (write_enable) begin
                    register_table_d[old_dst_i][version_head_q] = new_dst_i;
                    ready_table_d[old_dst_i][version_head_q] = 1'b0;
                end
            end             
        end

        // Update commit table
        if (commit_write_enable_0 & !commit_write_enable_1) begin
            commit_table_d[commit_old_dst_i[0]] = commit_new_dst_i[0];
        end else if (commit_write_enable_0 & commit_write_enable_1 & (commit_old_dst_i[0] == commit_old_dst_i[1])) begin
            commit_table_d[commit_old_dst_i[1]] = commit_new_dst_i[1];
        end else if (commit_write_enable_0 & commit_write_enable_1 & (commit_old_dst_i[0] != commit_old_dst_i[1])) begin
            commit_table_d[commit_old_dst_i[0]] = commit_new_dst_i[0];
            commit_table_d[commit_old_dst_i[1]] = commit_new_dst_i[1];
        end else if (!commit_write_enable_0 & commit_write_enable_1) begin
            commit_table_d[commit_old_dst_i[1]] = commit_new_dst_i[1];
        end

        // Write new ready register
        for (int i = 0; i < NUM_SCALAR_WB; ++i) begin
            if (ready_enable[i]) begin
                for(int j = 0; j < NUM_CHECKPOINTS; j++) begin
                    if (~checkpoint_enable | (checkpoint_ptr'(j) != (version_head_q + 2'b1))) begin
                        if ((register_table_q[vaddr_i[i]][j] == paddr_i[i]) & ~(write_enable & (vaddr_i[i] == old_dst_i) & (checkpoint_ptr'(j) == version_head_q) )) 
                            ready_table_d[vaddr_i[i]][j] = 1'b1;
                    end else if ((register_table_q[vaddr_i[i]][version_head_q] == paddr_i[i]) & ~(write_enable & (vaddr_i[i] == old_dst_i))) begin
                        ready_table_d[vaddr_i[i]][version_head_nxt] = 1'b1; 
                    end
                end
            end
        end
    end
end

always_ff @(posedge clk_i, negedge rstn_i) 
begin
    if(~rstn_i) begin
        src1_o <= '0;
        src2_o <= '0;
        rdy1_o <= 1'b0;
        rdy2_o <= 1'b0;
        old_dst_o <= '0;  
        checkpoint_o <= '0;
    end else if (recover_commit_i) begin // Recover commit table because exception
        src1_o <= '0;
        src2_o <= '0;
        rdy1_o <= 1'b0;
        rdy2_o <= 1'b0;
        old_dst_o <= '0;  
        checkpoint_o <= '0;
    end else begin
        if (read_enable && !do_recover_i) begin
            src1_o <= register_table_q[read_src1_i][version_head_q];
            rdy1_o <= ready_table_q[read_src1_i][version_head_q] | (|rdy1) | (~use_rs1_i);
            src2_o <= register_table_q[read_src2_i][version_head_q];
            rdy2_o <= ready_table_q[read_src2_i][version_head_q] | (|rdy2) | (~use_rs2_i);
            old_dst_o <= register_table_q[old_dst_i][version_head_q];
        end
        checkpoint_o <= version_head_q;
    end
end

always_ff @(posedge clk_i, negedge rstn_i) 
begin
    if(~rstn_i) begin
        // Table initial state
        for (integer j = 0; j < NUM_ISA_REGISTERS; j++) begin
            for (integer k = 0; k < NUM_CHECKPOINTS; k++) begin
                register_table_q[j][k] <= j;
                ready_table_q[j][k] <= 1'b1;
            end
            commit_table_q[j] <= j;
        end
        // Checkpoint signals
        version_head_q <= 2'b0;       // Current table, 0
        num_checkpoints_q <= 3'b00;   // No checkpoints
        version_tail_q <= 2'b0;       // Last reserved table 0
    end else begin
        register_table_q  <= register_table_d;
        ready_table_q     <= ready_table_d;
        commit_table_q    <= commit_table_d;
        version_head_q    <= version_head_d;       
        num_checkpoints_q <= num_checkpoints_d;
        version_tail_q    <= version_tail_d;
    end
end

always_comb begin
    if (read_enable) begin
        for (int i = 0; i < NUM_SCALAR_WB; ++i) begin
            rdy1[i] = ready_i[i] && (read_src1_i == vaddr_i[i]) && (register_table_q[read_src1_i][version_head_q] == paddr_i[i]);
            rdy2[i] = ready_i[i] && (read_src2_i == vaddr_i[i]) && (register_table_q[read_src2_i][version_head_q] == paddr_i[i]);
        end
    end else begin
        rdy1 = '0;
        rdy2 = '0;
    end 
end

assign out_of_checkpoints_o = (num_checkpoints_q == (NUM_CHECKPOINTS - 1));

`ifdef CHECK_RENAME

(* keep="TRUE" *) (* mark_debug="TRUE" *) logic [NUM_CHECKPOINTS-1:0] error_rename_q;
logic [NUM_CHECKPOINTS-1:0] error_rename_d;
(* keep="TRUE" *) (* mark_debug="TRUE" *) logic  error_actual_coechpoint_q;
logic error_actual_coechpoint_d;
(* keep="TRUE" *) (* mark_debug="TRUE" *) logic error_commit_q;
logic error_commit_d;

always_comb begin
    for(int i=0;i<NUM_CHECKPOINTS;i++) begin
        error_rename_d[i] = 1'b0;
        for (int j=0; j<NUM_ISA_REGISTERS; j++)begin
            for (int k=0; k<NUM_ISA_REGISTERS; k++)begin
                if (register_table_q[j][i] == register_table_q[k][i] && j!=k) begin
                    error_rename_d[i] |= 1'b1; 
                end
            end
        end
    end
    error_commit_d = 1'b0; 
    for (int j=0; j<NUM_ISA_REGISTERS; j++)begin
        for (int k=0; k<NUM_ISA_REGISTERS; k++)begin
            if (commit_table_q[j] == commit_table_q[k] && j!=k) begin
                error_commit_d |= 1'b1; 
            end
        end
    end

end

always_ff @(posedge clk_i, negedge rstn_i) 
begin
    if(~rstn_i) begin
        error_rename_q <= '0;
        error_actual_coechpoint_q <= '0;
        error_commit_q <= '0;
    end else begin
        error_rename_q <= error_rename_d;
        error_actual_coechpoint_q <= error_actual_coechpoint_d;
        error_commit_q <= error_actual_coechpoint_d;
    end
end

`endif

endmodule
