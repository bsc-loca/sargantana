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
import drac_pkg::*;
import riscv_pkg::*;

module score_board_scalar (
    input logic             clk_i,
    input logic             rstn_i,
    input logic             flush_i,

    input wire              set_mul_32_i,               // Insert new Mul instruction of 2  cycles
    input wire              set_mul_64_i,               // Insert new Mul instruction of 3  cycles
    input wire              set_div_32_i,               // Insert new Div instruction of 16 cycles
    input wire              set_div_64_i,               // Insert new Div instruction of 32 cycles

    // OUTPUTS
    output logic            ready_1cycle_o,             // Instruction of 1 cycle duration can be issued
    output logic            ready_mul_32_o,             // Instruction of 2 cycles duration can be issued
    output logic            ready_mul_64_o,             // Instruction of 3 cycles duration can be issued
    output logic            ready_div_32_o,             // Instruction of 8 cycles duration can be issued
    output logic            div_unit_sel_o,             // Select Div unit for the Div instruction
    output logic            ready_div_unit_o            // At least one of the Div units is free
);

    logic div[32:0];
    logic mul[1:0];
    logic [32:0] ocup_div_unit[1:0];
    logic free_div_unit[1:0];
    
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(~rstn_i) begin
            for(int i = 1; i >= 0; i--) begin
                mul[i] <= 0;
                ocup_div_unit[i] <= 33'd0;
            end 
            for(int i = 32; i >= 0; i--) begin
                div[i] <= 0;
            end 
        end 
        else if (flush_i) begin
            for(int i = 1; i >= 0; i--) begin
                mul[i] <= 0;
                ocup_div_unit[i] <= 33'd0;
            end 
            for(int i = 32; i >= 0; i--) begin
                div[i] <= 0;
            end  
        end 
        else begin
            mul[1] <= 1'b0;
            for(int i = 0; i >= 0; i--) begin
                mul[i] <= mul[i + 1];
            end
            div[32] <= 1'b0;   
            for (int i = 31; i >= 0; i--) begin
                div[i] <= div[i + 1];
            end
            for(int i = 1; i >= 0; i--) begin
                ocup_div_unit[i] <= ocup_div_unit[i] >> 1;
            end
            if (set_mul_32_i) begin
                mul[0]  <= 1'b1;
            end
            if (set_mul_64_i) begin
                mul[1]  <= 1'b1;
            end
            if (set_div_64_i) begin
                div[32] <= 1'b1;
                if (free_div_unit[0]) begin // if (~div_unit_sel_o)
                    ocup_div_unit[0] <= 33'h100000000;
                end else begin 
                    ocup_div_unit[1] <= 33'h100000000;
                end
            end
            if (set_div_32_i) begin
                div[16] <= 1'b1;
                if (free_div_unit[0]) begin // if (~div_unit_sel_o)
                    ocup_div_unit[0] <= 33'h000010000;
                end else begin 
                    ocup_div_unit[1] <= 33'h000010000;
                end
            end
            
        end
    end

    assign ready_1cycle_o = (~mul[0]) & (~div[0]);
    assign ready_mul_32_o = (~mul[1]) & (~div[1]);
    assign ready_mul_64_o = (~div[2]);
    assign ready_div_32_o = (~div[17]);
    assign div_unit_sel_o = ~free_div_unit[0];
    assign ready_div_unit_o = free_div_unit[0] | free_div_unit[1];
    assign free_div_unit[0] = ~(|ocup_div_unit[0]);
    assign free_div_unit[1] = ~(|ocup_div_unit[1]);

endmodule

