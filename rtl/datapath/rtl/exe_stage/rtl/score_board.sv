/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : score_board.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Victor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */
//`default_nettype none
import drac_pkg::*;
import riscv_pkg::*;

module score_board (
    input logic             clk_i,
    input logic             rstn_i,
    input logic             kill_i,

    input wire              set_mul_64_i,               // Insert new Mul instruction of 2 cycles
    input wire              set_div_32_i,               // Insert new Div instruction of 6 cycles
    input wire              set_div_64_i,               // Insert new Div instruction of 11 cycles

    // OUTPUTS
    output logic            ready_1cycle_o,             // Instruction of 1 cycle duration can be issued
    output logic            ready_mul_64_o,             // Instruction of 2 cycles duration can be issued
    output logic            ready_div_32_o,             // Instruction of 6 cycles duration can be issued
    output logic            ready_div_64_o              // Instrcution of 11 cycles duration can be issued
);


    logic div[9:0];
    logic mul;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(~rstn_i) begin
            mul <= 0;
            for(int i = 9; i >= 0; i--) begin
                div[i] <= 0;
            end 
        end 
        else if (kill_i) begin
            mul <= 0;
            for(int i = 9; i >= 0; i--) begin
                div[i] <= 0;
            end  
        end 
        else begin
            for (int i = 8; i >= 0; i--) begin
                div[i] <= div[i + 1];
            end
    
            mul <= set_mul_64_i;
            div[9] <= set_div_64_i;
            div[4] <= set_div_32_i;
        
        end
    end

    assign ready_1cycle_o = (~mul) & (~div[0]);
    assign ready_mul_64_o = (~div[1]);
    assign ready_div_32_o = (~div[4]);
    assign ready_div_64_o = (~div[9]);

endmodule

