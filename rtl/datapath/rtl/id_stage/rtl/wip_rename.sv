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

// TODO: Add checkpointing to recover state fast.

localparam NUM_ISA_REGISTERS = 32;

//`default_nettype none
import drac_pkg::*;

module load_store_queue(
    input wire             clk_i,               // Clock Singal
    input wire             rstn_i,              // Negated Reset Signal

    input reg_t            read_src1_i,         // Read source register 1 mapping
    input reg_t            read_src2_i,         // Read source register 2 mapping
    input reg_t            old_dst_i,           // Read and write to old destination register
    input reg_t            new_dst_i,           // Write to old destination register

    output reg_t           src1_o,              // Read source register 1 mapping
    output reg_t           src2_o,              // Read source register 1 mapping
    output reg_t           old_dst_o,           // Read source register 1 mapping
);

`ifndef SRAM_MEMORIES

    // Look up table

    reg_t register_table [0:NUM_ISA_REGISTERS-1];

    `ifndef SYNTHESIS
        // Initialize all the entries of lsq with the initial state
        integer i;
        initial 
        begin for(i = 0; i < NUM_ISA_REGISTERS ; i = i + 1) begin
                register_table[i] = i;
              end
        end
    `endif

    always_ff @(posedge clk_i, negedge rstn_i) 
    begin
        if(~rstn_i) begin
            src1_o = 0;
            src2_o = 0;
            old_dst_o = 0;                              // TODO: CUIDADO PUEDE LIBERAR EL REG 0
        end else begin
            src1_o <= register_table[read_src1_i];
            src2_o <= register_table[read_src2_i];
            old_dst_o <= register_table[old_dst_i];
        end
    end
 
    always_ff @(negedge clk_i, negedge rstn_i) 
    begin
        if (~rstn_i) begin
            for (integer j = 0; j < NUM_ISA_REGISTERS; j++) begin
                register_table[j] = j;
            end
        end else if(is_branch_EX_i) begin
            register_table[old_dst_i] <= new_dst_i;
        end
    end

`endif




endmodule
