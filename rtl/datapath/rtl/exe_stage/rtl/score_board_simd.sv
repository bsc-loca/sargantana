/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : score_board_simd.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Xavier Carril 
 * Email(s)       : xavier.carril@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */
import drac_pkg::*;
import riscv_pkg::*;

module score_board_simd (
    input logic             clk_i,
    input logic             rstn_i,
    input logic             flush_i,

    // INPUTS
    input wire              set_vmul_3cycle_i,                 // Insert new vmul instruction of 3  cycles
    input wire              set_vmul_2cycle_i,                 // Insert new vmul instruction of 2  cycles

    // OUTPUTS
    output logic            ready_vec_1cycle_o,                // Vector Instruction of 1 cycle duration can be issued
    output logic            ready_vec_2cycle_o                 // Vector Instruction of 2 cycle duration can be issued
);

    logic vmul[1:0];
    
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(~rstn_i) begin
            for(int i = 1; i >= 0; i--) begin
                vmul[i] <= 0;
            end 
        end 
        else if (flush_i) begin
            for(int i = 1; i >= 0; i--) begin
                vmul[i] <= 0;
            end 
        end 
        else begin
            vmul[1] <= 1'b0;
            for(int i = 0; i >= 0; i--) begin
                vmul[i] <= vmul[i + 1];
            end
            if (set_vmul_2cycle_i) begin
                vmul[0] <= 1'b1;
            end
            if (set_vmul_3cycle_i) begin
                vmul[1]  <= 1'b1;
            end
        end
    end

    assign ready_vec_1cycle_o = (~vmul[0]);
    assign ready_vec_2cycle_o = (~vmul[1]);

endmodule

